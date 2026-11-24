import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../services/try_on/body_pose.dart';
import '../services/try_on/garment_cutout.dart';

/// Живая примерка «фото вещи»: вырезанное фото товара накладывается
/// на тело — с настоящим цветом, принтом, номером и надписями.
///
/// Вещь подгоняется по плечам (верх) или по бёдрам (низ), поворачивается
/// вместе с корпусом и масштабируется по выбранному размеру: размер
/// больше рекомендуемого — вещь шире и длиннее, меньше — уже и короче.
class PhotoGarmentPainter {
  PhotoGarmentPainter._();

  /// Во сколько раз плечи вещи шире расстояния между суставами плеч
  /// (суставы лежат внутри тела, а плечо футболки — снаружи).
  static const double shoulderFit = 1.5;

  /// Во сколько раз пояс шорт и штанов шире расстояния между суставами
  /// бёдер.
  static const double waistFit = 1.85;

  /// Рисует вещь на [canvas] размера кадра [size].
  /// Возвращает false, если нужных точек тела не видно.
  static bool paint(
    Canvas canvas,
    Size size,
    BodyPose pose,
    GarmentCutout cutout, {
    required bool isBottom,
    double sizeScale = 1,
    ui.Image? shading,
  }) {
    final (BodyJoint, BodyJoint) joints = isBottom
        ? (BodyJoint.leftHip, BodyJoint.rightHip)
        : (BodyJoint.leftShoulder, BodyJoint.rightShoulder);
    final BodyPoint? p1 = pose[joints.$1];
    final BodyPoint? p2 = pose[joints.$2];
    if (p1 == null || p2 == null) return false;
    Offset at(BodyPoint p) => Offset(p.x * size.width, p.y * size.height);
    // Слева направо по экрану — фронтальная камера зеркалит кадр,
    // а вещь должна оставаться «лицом» и не переворачиваться.
    Offset a = at(p1), b = at(p2);
    if (a.dx > b.dx) (a, b) = (b, a);
    final Offset across = b - a;
    final double distance = across.distance;
    if (distance < 8) return false;
    final double angle = math.atan2(across.dy, across.dx);

    final double fit = isBottom ? waistFit : shoulderFit;
    final double scale = distance * fit * sizeScale / cutout.topSpan;
    // Ворот — чуть выше линии плеч; пояс — выше суставов бёдер.
    final double lift = distance * (isBottom ? 0.3 : 0.12) * sizeScale;
    final Offset middle = (a + b) / 2;
    final Offset anchor = middle +
        Offset(math.sin(angle) * lift, -math.cos(angle) * lift);

    canvas.save();
    canvas.translate(anchor.dx, anchor.dy);
    canvas.rotate(angle);
    canvas.scale(scale);
    canvas.translate(-cutout.centerX, -cutout.topSpanY);
    final Rect garment = Offset.zero &
        Size(cutout.width.toDouble(), cutout.height.toDouble());
    final Paint image = Paint()..filterQuality = FilterQuality.medium;
    if (shading == null) {
      canvas.drawImage(cutout.image, Offset.zero, image);
      canvas.restore();
      return true;
    }
    canvas.restore();

    // Свет и складки из кадра поверх вещи (как в 3D-режиме): слой
    // с вещью, сверху — яркость кадра в режиме hardLight только там,
    // где есть вещь.
    final Rect frame = Offset.zero & size;
    final Rect source = Rect.fromLTWH(
      0, 0, shading.width.toDouble(), shading.height.toDouble(),
    );
    void drawGarment() {
      canvas.save();
      canvas.translate(anchor.dx, anchor.dy);
      canvas.rotate(angle);
      canvas.scale(scale);
      canvas.translate(-cutout.centerX, -cutout.topSpanY);
      canvas.drawImageRect(cutout.image, garment, garment, image);
      canvas.restore();
    }

    canvas.saveLayer(frame, Paint());
    drawGarment();
    canvas.saveLayer(frame, Paint()..blendMode = BlendMode.srcATop);
    drawGarment();
    canvas.drawImageRect(
      shading,
      source,
      frame,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..blendMode = BlendMode.hardLight,
    );
    canvas.restore();
    canvas.restore();
    return true;
  }
}

/// Размер вещи относительно рекомендуемого: как вещь будет сидеть.
class SizeFit {
  const SizeFit._();

  /// На сколько каждый размер шире и длиннее соседнего.
  static const double step = 0.08;

  /// Масштаб вещи для [selected] при рекомендуемом [recommended].
  static double scale(List<String> sizes, String? selected, String? recommended) {
    final int s = sizes.indexOf(selected ?? '');
    final int r = sizes.indexOf(recommended ?? '');
    if (s < 0 || r < 0) return 1;
    return 1 + (s - r) * step;
  }

  /// Как сидит [selected] при рекомендуемом [recommended] — для подписи.
  static String describe(List<String> sizes, String? selected, String? recommended) {
    final int s = sizes.indexOf(selected ?? '');
    final int r = sizes.indexOf(recommended ?? '');
    if (s < 0 || r < 0) return '';
    final int diff = s - r;
    if (diff == 0) return 'по размеру';
    if (diff == 1) return 'свободно';
    if (diff >= 2) return 'велико';
    if (diff == -1) return 'в обтяжку';
    return 'мало';
  }
}
