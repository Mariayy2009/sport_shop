import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show decodeImageFromList;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Положение фигуры на фото в полный рост — куда ставить одежду.
/// Все величины в долях высоты фото, от его центра
/// (см. FittingPhotos.fitScale и соседние поля).
class BodyFit {
  const BodyFit({
    required this.scale,
    required this.width,
    required this.dx,
    required this.dy,
  });

  final double scale;
  final double width;
  final double dx;
  final double dy;

  /// Уровни плеч и щиколоток на манекене (доля высоты фигуры) —
  /// те же, что в AvatarPainter.
  static const double _shoulderLevel = 0.155;
  static const double _ankleLevel = 0.93;

  /// Полуширина плеч стандартной фигуры (доля высоты).
  static const double _shoulderHalfWidth = 0.112;

  /// Суставы плеч лежат внутри силуэта: контур шире расстояния между ними.
  static const double _jointToOutline = 1.25;

  /// Подгонка по ключевым точкам тела (координаты в пикселях фото).
  /// null — точки не образуют стоящую фигуру.
  static BodyFit? fromLandmarks({
    required double imageWidth,
    required double imageHeight,
    required ui.Offset leftShoulder,
    required ui.Offset rightShoulder,
    required ui.Offset leftHip,
    required ui.Offset rightHip,
    required ui.Offset leftAnkle,
    required ui.Offset rightAnkle,
  }) {
    final double shoulderY = (leftShoulder.dy + rightShoulder.dy) / 2;
    final double ankleY = (leftAnkle.dy + rightAnkle.dy) / 2;
    final double figureHeight =
        (ankleY - shoulderY) / (_ankleLevel - _shoulderLevel);
    // Человек должен стоять и занимать заметную часть кадра.
    if (figureHeight < imageHeight * 0.25) return null;

    final double top = shoulderY - _shoulderLevel * figureHeight;
    final double centerY = top + figureHeight / 2;
    final double centerX =
        (leftShoulder.dx + rightShoulder.dx + leftHip.dx + rightHip.dx) / 4;
    final double shoulderSpan = (leftShoulder.dx - rightShoulder.dx).abs();

    return BodyFit(
      scale: figureHeight / (imageHeight * 0.9),
      width: shoulderSpan /
          figureHeight /
          (2 * _shoulderHalfWidth) *
          _jointToOutline,
      dx: (centerX - imageWidth / 2) / imageHeight,
      dy: (centerY - imageHeight / 2) / imageHeight,
    );
  }
}

/// Находит фигуру человека на фото, чтобы одежда встала на место сама.
abstract class PoseFitter {
  /// Доступно ли определение позы на этом устройстве.
  bool get isSupported;

  /// null — человек на фото не найден или функция недоступна.
  Future<BodyFit?> detect(String imagePath);
}

/// Определение позы на устройстве (Google ML Kit). Работает на Android
/// и iOS, без интернета: фото никуда не отправляется.
class MlKitPoseFitter implements PoseFitter {
  /// Точка считается найденной, если модель в ней достаточно уверена.
  static const double _minLikelihood = 0.5;

  @override
  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<BodyFit?> detect(String imagePath) async {
    if (!isSupported) return null;
    final PoseDetector detector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.single,
        model: PoseDetectionModel.accurate,
      ),
    );
    try {
      final List<Pose> poses =
          await detector.processImage(InputImage.fromFilePath(imagePath));
      if (poses.isEmpty) return null;
      final Map<PoseLandmarkType, PoseLandmark> points = poses.first.landmarks;

      ui.Offset? point(PoseLandmarkType type) {
        final PoseLandmark? landmark = points[type];
        if (landmark == null || landmark.likelihood < _minLikelihood) return null;
        return ui.Offset(landmark.x, landmark.y);
      }

      final List<ui.Offset?> needed = [
        point(PoseLandmarkType.leftShoulder),
        point(PoseLandmarkType.rightShoulder),
        point(PoseLandmarkType.leftHip),
        point(PoseLandmarkType.rightHip),
        point(PoseLandmarkType.leftAnkle),
        point(PoseLandmarkType.rightAnkle),
      ];
      // Без плеч, бёдер или стоп подгонка будет неверной — лучше вручную.
      if (needed.contains(null)) return null;

      final ui.Image image =
          await decodeImageFromList(await File(imagePath).readAsBytes());
      final BodyFit? fit = BodyFit.fromLandmarks(
        imageWidth: image.width.toDouble(),
        imageHeight: image.height.toDouble(),
        leftShoulder: needed[0]!,
        rightShoulder: needed[1]!,
        leftHip: needed[2]!,
        rightHip: needed[3]!,
        leftAnkle: needed[4]!,
        rightAnkle: needed[5]!,
      );
      image.dispose();
      return fit;
    } on Exception catch (error) {
      debugPrint('Не удалось определить позу: $error');
      return null;
    } finally {
      await detector.close();
    }
  }
}
