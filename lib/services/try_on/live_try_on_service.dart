import 'dart:async';
import 'dart:isolate';
import 'dart:io' show Platform;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';

import '../../core/errors/app_exception.dart';
import 'body_pose.dart';
import 'body_shading.dart';
import 'garment_scan.dart';

/// Живая примерка: видеопоток камеры и определение позы в каждом кадре.
///
/// Поза считается на устройстве (Google ML Kit Pose Detection),
/// кадры никуда не отправляются. Работает на Android и iOS.
class LiveTryOnService {
  /// [withShading] — считать свет и силуэт для реалистичной одежды.
  /// Игре с мячом это не нужно: без модели силуэта поза приходит чаще.
  LiveTryOnService({this.withShading = true});

  final bool withShading;

  /// Кадр камеры с позой и маской человека — для сканирования вещи
  /// продавцом. null — не нужен (обычная примерка, игра).
  void Function(ScanFrame frame, BodyPose pose)? onScanFrame;
  CameraController? _camera;
  PoseDetector? _detector;
  SelfieSegmenter? _segmenter;
  SegmentationMask? _mask;
  int _frame = 0;
  List<CameraDescription> _cameras = const [];
  CameraDescription? _current;
  final StreamController<BodyPose?> _poses =
      StreamController<BodyPose?>.broadcast();
  final StreamController<BodyShading> _shading =
      StreamController<BodyShading>.broadcast();
  bool _busy = false;
  bool _shadingBusy = false;
  ui.Color? _skin;
  int _skinFrame = 0;
  bool _running = false;
  BodyPose? _previous;

  /// Сглаживание позы между кадрами: доля нового кадра.
  static const double _smoothing = 0.55;

  static const Map<PoseLandmarkType, BodyJoint> _joints = {
    PoseLandmarkType.nose: BodyJoint.nose,
    PoseLandmarkType.leftShoulder: BodyJoint.leftShoulder,
    PoseLandmarkType.rightShoulder: BodyJoint.rightShoulder,
    PoseLandmarkType.leftElbow: BodyJoint.leftElbow,
    PoseLandmarkType.rightElbow: BodyJoint.rightElbow,
    PoseLandmarkType.leftWrist: BodyJoint.leftWrist,
    PoseLandmarkType.rightWrist: BodyJoint.rightWrist,
    PoseLandmarkType.leftHip: BodyJoint.leftHip,
    PoseLandmarkType.rightHip: BodyJoint.rightHip,
    PoseLandmarkType.leftKnee: BodyJoint.leftKnee,
    PoseLandmarkType.rightKnee: BodyJoint.rightKnee,
    PoseLandmarkType.leftAnkle: BodyJoint.leftAnkle,
    PoseLandmarkType.rightAnkle: BodyJoint.rightAnkle,
  };

  /// Камера и определение позы есть только на телефоне.
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  CameraController? get camera => _camera;

  bool get isFrontCamera =>
      _current?.lensDirection == CameraLensDirection.front;

  bool get canSwitchCamera => _cameras.length > 1;

  /// Поза в каждом обработанном кадре; null — человек не найден.
  Stream<BodyPose?> get poses => _poses.stream;

  /// Свет и силуэт человека в каждом обработанном кадре
  /// (реалистичный режим живой примерки).
  Stream<BodyShading> get shading => _shading.stream;

  /// Силуэт тела обновляется через кадр: маска меняется медленнее позы,
  /// а так обе модели укладываются в частоту камеры.
  static const int _maskEvery = 3;

  /// Размер кадра в вертикальной ориентации экрана.
  Size? get previewSize {
    final Size? size = _camera?.value.previewSize;
    if (size == null) return null;
    return size.width > size.height ? Size(size.height, size.width) : size;
  }

  /// Запускает камеру (по умолчанию фронтальную) и поток поз.
  Future<void> start({bool front = true}) async {
    if (!isSupported) {
      throw const AppException('Живая примерка работает на телефоне с Android или iOS');
    }
    try {
      _cameras = await availableCameras();
    } on CameraException catch (error) {
      throw AppException('Камера недоступна: ${error.description ?? error.code}');
    }
    if (_cameras.isEmpty) throw const AppException('На устройстве нет камеры');
    final CameraLensDirection wanted =
        front ? CameraLensDirection.front : CameraLensDirection.back;
    await _open(_cameras.firstWhere(
      (camera) => camera.lensDirection == wanted,
      orElse: () => _cameras.first,
    ));
  }

  Future<void> switchCamera() async {
    if (!canSwitchCamera) return;
    final bool front = !isFrontCamera;
    await _closeCamera();
    await start(front: front);
  }

  Future<void> _open(CameraDescription description) async {
    final CameraController controller = CameraController(
      description,
      // Среднего разрешения хватает для позы, а кадры обрабатываются быстрее.
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );
    try {
      await controller.initialize();
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
    } on CameraException catch (error) {
      await controller.dispose();
      throw AppException(
        error.code == 'CameraAccessDenied'
            ? 'Нет доступа к камере. Разрешите его в настройках телефона'
            : 'Не удалось запустить камеру: ${error.description ?? error.code}',
      );
    }
    _camera = controller;
    _current = description;
    _detector ??= PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
        model: PoseDetectionModel.base,
      ),
    );
    // Модель силуэта ставится вместе с приложением (около 4 МБ)
    // и работает на телефоне.
    if (withShading) _segmenter ??= SelfieSegmenter(enableRawSizeMask: true);
    _previous = null;
    _mask = null;
    _running = true;
    await controller.startImageStream(_onFrame);
  }

  Future<void> _onFrame(CameraImage image) async {
    // Пока модель занята предыдущим кадром, новые пропускаем:
    // так поток не копится и картинка не отстаёт.
    if (_busy || !_running) return;
    _busy = true;
    try {
      final InputImage? input = _toInputImage(image);
      if (input == null) return;
      final List<Pose> found = await _detector!.processImage(input);
      if (!_running || _poses.isClosed) return;
      if (found.isEmpty) {
        _previous = null;
        _poses.add(null);
        return;
      }
      final BodyPose pose = _toBodyPose(found.first, input.metadata!)
          .smoothedFrom(_previous, _smoothing);
      _previous = pose;
      _poses.add(pose);
      // Свет и силуэт считаются отдельно и не задерживают позу:
      // одежда следует за телом без рывков.
      if (withShading && !_shadingBusy) {
        _shadingBusy = true;
        unawaited(
          _updateShading(_FrameCopy.of(image), input, pose)
              .whenComplete(() => _shadingBusy = false),
        );
      }
      final void Function(ScanFrame, BodyPose)? scan = onScanFrame;
      if (scan != null) {
        final SegmentationMask? mask = _mask;
        scan(
          ScanFrame(
            planes: [for (final Plane plane in image.planes) plane.bytes],
            bytesPerRow: [for (final Plane plane in image.planes) plane.bytesPerRow],
            bytesPerPixel: [for (final Plane plane in image.planes) plane.bytesPerPixel],
            width: image.width,
            height: image.height,
            rotation: _current?.sensorOrientation ?? 0,
            mirror: isFrontCamera,
            bgra: image.format.group == ImageFormatGroup.bgra8888,
            mask: mask?.confidences,
            maskWidth: mask?.width ?? 0,
            maskHeight: mask?.height ?? 0,
          ),
          pose,
        );
      }
    } on Exception catch (error) {
      debugPrint('Ошибка определения позы: $error');
    } finally {
      _busy = false;
    }
  }

  /// Свет и силуэт для реалистичного режима. Ошибка модели силуэта
  /// не мешает примерке: одежда просто рисуется без обрезки по контуру.
  Future<void> _updateShading(
    _FrameCopy frame,
    InputImage input,
    BodyPose pose,
  ) async {
    final SelfieSegmenter? segmenter = _segmenter;
    if (segmenter != null && (_mask == null || _frame++ % _maskEvery == 0)) {
      try {
        _mask = await segmenter.processImage(input) ?? _mask;
      } on Exception catch (error) {
        debugPrint('Ошибка определения силуэта: $error');
      }
    }
    if (!_running || _shading.isClosed) return;
    final SegmentationMask? mask = _mask;
    final int rotation = _current?.sensorOrientation ?? 0;
    final bool mirror = isFrontCamera;
    // Цвет кожи почти не меняется — достаточно уточнять раз в секунду.
    final BodyPoint? nose = pose[BodyJoint.nose];
    if (nose != null && (_skin == null || _skinFrame++ % 10 == 0)) {
      _skin = BodyShading.skinColor(
            planes: frame.planes,
            bytesPerRow: frame.bytesPerRow,
            bytesPerPixel: frame.bytesPerPixel,
            frameWidth: frame.width,
            frameHeight: frame.height,
            rotation: rotation,
            mirror: mirror,
            bgra: frame.bgra,
            noseX: nose.x,
            noseY: nose.y,
          ) ??
          _skin;
    }
    final Uint8List luma = frame.planes.first;
    final int width = frame.width, height = frame.height;
    final int row = frame.bytesPerRow.first;
    final bool bgra = frame.bgra;
    final Float32List? confidences =
        mask == null ? null : Float32List.fromList(mask.confidences);
    final int maskWidth = mask?.width ?? 0, maskHeight = mask?.height ?? 0;
    // Тяжёлый счёт — в отдельном потоке, экран не подтормаживает.
    final BodyShading shading = await Isolate.run(
      () => BodyShading.fromFrame(
        luma: luma,
        frameWidth: width,
        frameHeight: height,
        bytesPerRow: row,
        rotation: rotation,
        mirror: mirror,
        bgra: bgra,
        mask: confidences,
        maskWidth: maskWidth,
        maskHeight: maskHeight,
      ),
    );
    if (!_running || _shading.isClosed) return;
    _shading.add(shading.withSkin(_skin));
  }

  /// Кадр камеры → формат ML Kit с учётом поворота датчика.
  InputImage? _toInputImage(CameraImage image) {
    final CameraDescription? camera = _current;
    if (camera == null) return null;
    final InputImageRotation? rotation =
        InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    final InputImageFormat? format =
        InputImageFormatValue.fromRawValue(image.format.raw as int);
    if (rotation == null || format == null) return null;

    // NV21 на Android и BGRA на iOS приходят одной плоскостью;
    // если плоскостей несколько, склеиваем их подряд.
    final Uint8List bytes;
    if (image.planes.length == 1) {
      bytes = image.planes.first.bytes;
    } else {
      final BytesBuilder builder = BytesBuilder(copy: false);
      for (final Plane plane in image.planes) {
        builder.add(plane.bytes);
      }
      bytes = builder.toBytes();
    }
    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  /// Точки ML Kit (пиксели повёрнутого кадра) → доли кадра.
  BodyPose _toBodyPose(Pose pose, InputImageMetadata metadata) {
    final bool sideways = metadata.rotation == InputImageRotation.rotation90deg ||
        metadata.rotation == InputImageRotation.rotation270deg;
    final double width = sideways ? metadata.size.height : metadata.size.width;
    final double height = sideways ? metadata.size.width : metadata.size.height;
    final bool mirror = isFrontCamera;
    final Map<BodyJoint, BodyPoint> joints = {};
    for (final MapEntry<PoseLandmarkType, BodyJoint> entry in _joints.entries) {
      final PoseLandmark? mark = pose.landmarks[entry.key];
      if (mark == null) continue;
      final double x = mark.x / width;
      joints[entry.value] = BodyPoint(
        // Фронтальная камера показывает зеркальное изображение.
        mirror ? 1 - x : x,
        mark.y / height,
        mark.z / width,
        mark.likelihood,
      );
    }
    return BodyPose(joints);
  }

  Future<void> _closeCamera() async {
    _running = false;
    final CameraController? controller = _camera;
    _camera = null;
    if (controller == null) return;
    try {
      if (controller.value.isStreamingImages) await controller.stopImageStream();
    } on CameraException catch (error) {
      debugPrint('Остановка потока камеры: ${error.code}');
    }
    await controller.dispose();
  }

  /// Останавливает камеру и освобождает модель. Обязательно вызывать
  /// при закрытии экрана и при сворачивании приложения.
  Future<void> stop() async {
    await _closeCamera();
    await _detector?.close();
    _detector = null;
    await _segmenter?.close();
    _segmenter = null;
    _mask = null;
    _previous = null;
  }

  Future<void> dispose() async {
    await stop();
    await _poses.close();
    await _shading.close();
  }
}

/// Копия кадра камеры: буфер камеры переиспользуется сразу после
/// обработчика, а свет считается позже, в отдельном потоке.
class _FrameCopy {
  _FrameCopy({
    required this.planes,
    required this.bytesPerRow,
    required this.bytesPerPixel,
    required this.width,
    required this.height,
    required this.bgra,
  });

  factory _FrameCopy.of(CameraImage image) => _FrameCopy(
        planes: [for (final Plane p in image.planes) Uint8List.fromList(p.bytes)],
        bytesPerRow: [for (final Plane p in image.planes) p.bytesPerRow],
        bytesPerPixel: [for (final Plane p in image.planes) p.bytesPerPixel],
        width: image.width,
        height: image.height,
        bgra: image.format.group == ImageFormatGroup.bgra8888,
      );

  final List<Uint8List> planes;
  final List<int> bytesPerRow;
  final List<int?> bytesPerPixel;
  final int width;
  final int height;
  final bool bgra;
}
