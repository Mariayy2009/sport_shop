import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'body_pose.dart';
import 'body_shading.dart';

/// Сторона, с которой камера видит человека при сканировании.
enum ScanView {
  front('Спереди'),
  sideA('Бок'),
  back('Спина'),
  sideB('Другой бок');

  const ScanView(this.label);

  final String label;
}

/// Снятый кадр вещи: RGBA с прозрачным фоном и где на нём плечи
/// и бёдра (по ним вещь потом садится на покупателя).
class ScanShot {
  const ScanShot({
    required this.rgba,
    required this.width,
    required this.height,
    required this.anchors,
    required this.score,
  });

  final Uint8List rgba;
  final int width;
  final int height;
  final ScanAnchors anchors;

  /// Насколько кадр хорош: человек прямо и целиком.
  final double score;
}

/// Опорные линии вещи на снимке (в пикселях снимка).
class ScanAnchors {
  const ScanAnchors({
    required this.shoulderY,
    required this.hipY,
    required this.centerX,
    required this.span,
    required this.hipSpan,
  });

  final double shoulderY;
  final double hipY;
  final double centerX;

  /// Ширина вещи на линии плеч и бёдер — в том же масштабе, что
  /// у вырезанных фото товара (см. FittedGarmentPainter).
  final double span;
  final double hipSpan;

  Map<String, Object?> toJson() => {
        'shoulderY': shoulderY,
        'hipY': hipY,
        'centerX': centerX,
        'span': span,
        'hipSpan': hipSpan,
      };

  static ScanAnchors fromJson(Map<String, Object?> json) => ScanAnchors(
        shoulderY: (json['shoulderY']! as num).toDouble(),
        hipY: (json['hipY']! as num).toDouble(),
        centerX: (json['centerX']! as num).toDouble(),
        span: (json['span']! as num).toDouble(),
        hipSpan: (json['hipSpan']! as num).toDouble(),
      );
}

/// Сохранённая примерка товара: файлы снимков и опорные линии.
class ScanRecord {
  const ScanRecord({
    required this.frontPath,
    required this.front,
    this.backPath,
    this.back,
  });

  final String frontPath;
  final ScanAnchors front;
  final String? backPath;
  final ScanAnchors? back;

  String encodeMeta() => jsonEncode({
        'front': front.toJson(),
        if (back != null) 'back': back!.toJson(),
        if (backPath != null) 'backPath': backPath,
      });

  static ScanRecord? decode(String? frontPath, String? meta) {
    if (frontPath == null || meta == null) return null;
    try {
      final Map<String, Object?> json = jsonDecode(meta) as Map<String, Object?>;
      return ScanRecord(
        frontPath: frontPath,
        front: ScanAnchors.fromJson(json['front']! as Map<String, Object?>),
        backPath: json['backPath'] as String?,
        back: json['back'] == null
            ? null
            : ScanAnchors.fromJson(json['back']! as Map<String, Object?>),
      );
    } on Object {
      return null;
    }
  }
}

/// Кадр камеры для сканирования (то, что нужно из CameraImage).
class ScanFrame {
  const ScanFrame({
    required this.planes,
    required this.bytesPerRow,
    required this.bytesPerPixel,
    required this.width,
    required this.height,
    required this.rotation,
    required this.mirror,
    required this.bgra,
    this.mask,
    this.maskWidth = 0,
    this.maskHeight = 0,
  });

  final List<Uint8List> planes;
  final List<int> bytesPerRow;
  final List<int?> bytesPerPixel;
  final int width;
  final int height;
  final int rotation;
  final bool mirror;
  final bool bgra;

  /// Маска человека (ML Kit Selfie Segmentation) в вертикальном кадре.
  final List<double>? mask;
  final int maskWidth;
  final int maskHeight;
}

/// Сканирование вещи продавцом: человек в вещи медленно поворачивается
/// на 360°. По позе в каждом кадре понятно, какой стороной он к камере:
/// плечи широкие и лицо видно — спереди, лица не видно — спина, плечи
/// узкие — бок. Лучшие кадры спереди и сзади вырезаются по силуэту.
class GarmentScan {
  GarmentScan({required this.isBottom});

  /// Шорты или штаны — снимаем от пояса до щиколоток, иначе корпус.
  final bool isBottom;

  final Set<ScanView> seen = {};
  ScanShot? front;
  ScanShot? back;

  /// Самая широкая линия плеч — по ней видно, что человек повернулся боком.
  double _widest = 0;
  bool _sawSideAfterFront = false;

  double get progress => seen.length / ScanView.values.length;
  bool get isComplete => seen.length == ScanView.values.length && front != null;

  /// Ширина плеч относительно высоты корпуса (не зависит от того,
  /// насколько человек далеко от камеры).
  static double? shoulderRatio(BodyPose pose) {
    final BodyPoint? ls = pose[BodyJoint.leftShoulder];
    final BodyPoint? rs = pose[BodyJoint.rightShoulder];
    final BodyPoint? lh = pose[BodyJoint.leftHip];
    final BodyPoint? rh = pose[BodyJoint.rightHip];
    if (ls == null || rs == null || lh == null || rh == null) return null;
    final double width = math.sqrt(math.pow(ls.x - rs.x, 2) + math.pow((ls.y - rs.y) * 1.8, 2));
    final double torso = ((lh.y + rh.y) - (ls.y + rs.y)) / 2;
    return torso <= 0 ? null : width / torso;
  }

  /// Какой стороной человек к камере. null — не понять (нет корпуса).
  ScanView? viewOf(BodyPose pose) {
    final double? ratio = shoulderRatio(pose);
    if (ratio == null) return null;
    _widest = math.max(_widest, ratio);
    final bool faceVisible = (pose.joints[BodyJoint.nose]?.confidence ?? 0) > 0.6;
    if (ratio < _widest * 0.55 || ratio < 0.35) {
      return _sawSideAfterFront && seen.contains(ScanView.back)
          ? ScanView.sideB
          : ScanView.sideA;
    }
    // Спереди и сзади плечи не уже ~0,6 высоты корпуса — иначе это
    // поворот, а не «лицом к камере».
    if (ratio > _widest * 0.8 && ratio >= 0.6) {
      return faceVisible ? ScanView.front : ScanView.back;
    }
    return null;
  }

  /// Новый кадр. [takeShot] — вызвать, если кадр лучше прежнего
  /// с этой стороны (вырезание — дорогая операция).
  ScanView? addPose(BodyPose pose) {
    final ScanView? view = viewOf(pose);
    if (view == null) return null;
    if (view == ScanView.sideA && seen.contains(ScanView.front)) {
      _sawSideAfterFront = true;
    }
    // Бок засчитываем только после переда: так видно, что человек
    // действительно поворачивается, а не просто стоит.
    if (view == ScanView.front || seen.contains(ScanView.front)) seen.add(view);
    return view;
  }

  /// Оценка кадра спереди/сзади: шире плечи — человек ровнее к камере.
  double scoreOf(BodyPose pose) => shoulderRatio(pose) ?? 0;

  bool wantsShot(ScanView view, BodyPose pose) {
    if (view != ScanView.front && view != ScanView.back) return false;
    final ScanShot? current = view == ScanView.front ? front : back;
    return current == null || scoreOf(pose) > current.score * 1.03;
  }

  void keep(ScanView view, ScanShot shot) {
    if (view == ScanView.front) front = shot;
    if (view == ScanView.back) back = shot;
  }

  /// Вырезает вещь из кадра: прямоугольник от плеч до бёдер (у низа —
  /// от пояса до щиколоток), фон и всё, что не человек, — прозрачное.
  /// Снимок не зеркальный: надписи читаются, как в жизни.
  ScanShot? cut(ScanFrame frame, BodyPose pose, {int outWidth = 320}) {
    final bool sideways = frame.rotation == 90 || frame.rotation == 270;
    final int uw = sideways ? frame.height : frame.width;
    final int uh = sideways ? frame.width : frame.height;
    // Поза — в координатах экрана (с зеркалом), снимок — без зеркала.
    (double, double)? at(BodyJoint joint) {
      final BodyPoint? p = pose[joint];
      if (p == null) return null;
      return ((frame.mirror ? 1 - p.x : p.x) * uw, p.y * uh);
    }

    final (double, double)? ls = at(BodyJoint.leftShoulder);
    final (double, double)? rs = at(BodyJoint.rightShoulder);
    final (double, double)? lh = at(BodyJoint.leftHip);
    final (double, double)? rh = at(BodyJoint.rightHip);
    if (ls == null || rs == null || lh == null || rh == null) return null;
    final double shoulderDist = (ls.$1 - rs.$1).abs();
    final double hipDist = (lh.$1 - rh.$1).abs();
    final double shoulderY = (ls.$2 + rs.$2) / 2;
    final double hipY = (lh.$2 + rh.$2) / 2;
    final double centerX = (ls.$1 + rs.$1 + lh.$1 + rh.$1) / 4;
    if (shoulderDist < 8 || hipY <= shoulderY) return null;
    final double torso = hipY - shoulderY;

    double top, bottom;
    if (isBottom) {
      final List<double> ankles = [
        for (final BodyJoint j in [BodyJoint.leftAnkle, BodyJoint.rightAnkle])
          if (at(j) case final (double, double) p) p.$2,
      ];
      top = hipY - torso * 0.25;
      bottom = ankles.isEmpty ? hipY + torso * 1.6 : ankles.reduce(math.max);
    } else {
      top = shoulderY - torso * 0.18;
      bottom = hipY + torso * 0.3;
    }
    final double halfWidth = math.max(shoulderDist, hipDist) * 0.95;
    final double left = centerX - halfWidth, right = centerX + halfWidth;
    final double scale = outWidth / (right - left);
    final int outHeight = ((bottom - top) * scale).round();
    if (outHeight < 16) return null;

    final Uint8List rgba = Uint8List(outWidth * outHeight * 4);
    final bool hasMask = frame.mask != null && frame.maskWidth > 0;
    for (int y = 0; y < outHeight; y++) {
      for (int x = 0; x < outWidth; x++) {
        final double ux = left + (x + 0.5) / scale;
        final double uy = top + (y + 0.5) / scale;
        if (ux < 0 || uy < 0 || ux >= uw || uy >= uh) continue;
        double person = 1;
        if (hasMask) {
          // Маска ML Kit — в вертикальном кадре без зеркала.
          final int mx = (ux / uw * frame.maskWidth).floor().clamp(0, frame.maskWidth - 1);
          final int my = (uy / uh * frame.maskHeight).floor().clamp(0, frame.maskHeight - 1);
          person = frame.mask![my * frame.maskWidth + mx];
        }
        final int alpha = ((person - 0.4) / 0.2 * 255).round().clamp(0, 255);
        if (alpha == 0) continue;
        final (int sx, int sy) = BodyShading.sensorPoint(
          ux, uy, frame.rotation, frame.width, frame.height,
        );
        final List<int>? rgb = BodyShading.rgbAt(
          frame.planes, frame.bytesPerRow, frame.bytesPerPixel,
          frame.width, frame.height, sx, sy, frame.bgra,
        );
        if (rgb == null) continue;
        final int i = (y * outWidth + x) * 4;
        // Цвет умножен на прозрачность — так Flutter рисует пиксели.
        rgba[i] = rgb[0] * alpha ~/ 255;
        rgba[i + 1] = rgb[1] * alpha ~/ 255;
        rgba[i + 2] = rgb[2] * alpha ~/ 255;
        rgba[i + 3] = alpha;
      }
    }

    // Опорные линии в пикселях снимка. Ширины — с теми же коэффициентами,
    // что у фото товара в FittedGarmentPainter (плечо +20% с каждой
    // стороны, бёдра ×1,7), — тогда вещь садится на покупателя 1:1.
    return ScanShot(
      rgba: rgba,
      width: outWidth,
      height: outHeight,
      score: scoreOf(pose),
      anchors: isBottom
          // Низ садится по поясу: чуть выше суставов бёдер, ширина ×1,7.
          ? ScanAnchors(
              shoulderY: (hipY - hipDist * 0.35 - top) * scale,
              hipY: (hipY - top) * scale,
              centerX: (centerX - left) * scale,
              span: hipDist * 1.7 * scale,
              hipSpan: hipDist * 1.7 * scale,
            )
          : ScanAnchors(
              shoulderY: (shoulderY - top) * scale,
              hipY: (hipY - top) * scale,
              centerX: (centerX - left) * scale,
              span: shoulderDist * 1.4 * scale,
              hipSpan: math.max(hipDist * 1.7, shoulderDist * 1.15) * scale,
            ),
    );
  }
}
