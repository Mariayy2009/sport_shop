import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/try_on.dart';
import '../services/try_on/body_pose.dart';
import '../services/try_on/garment_cutout.dart';

/// Живая примерка «по фигуре»: фото товара (с надписями, номером,
/// поясом) режется на части и натягивается на тело:
///
/// * корпус — между плечами и бёдрами: сужается в талии и расширяется
///   в плечах вместе с человеком, поворачивается с корпусом;
/// * рукава — вдоль рук (короткие — до локтя, длинные — до запястья);
/// * шорты и штаны — от пояса вдоль ног.
///
/// Под вещью своя одежда закрывается цветом кожи (взятым с лица): у майки
/// и футболки — руки, у шорт — ноги. Это не стирание нейросетью, а
/// заливка по силуэту, но лонгслив под майкой больше не торчит.
class FittedGarmentPainter {
  FittedGarmentPainter._();

  /// Плечо вещи выступает за сустав плеча на эту долю ширины плеч.
  static const double shoulderOverhang = 0.2;

  /// Ширина бёдер по телу — во столько раз шире суставов бёдер.
  static const double hipOutline = 1.7;

  /// Сетка корпуса: чем гуще, тем плавнее изгиб.
  static const int columns = 8;
  static const int rows = 28;

  static bool paint(
    Canvas canvas,
    Size size,
    BodyPose pose,
    GarmentCutout cutout, {
    required GarmentShape shape,
    double sizeScale = 1,
    ui.Image? shading,
    Color? skin,
  }) {
    final _Body? body = _Body.of(pose, size);
    if (body == null) return false;
    final bool bottom =
        shape == GarmentShape.shorts || shape == GarmentShape.pants;
    if (bottom && body.hipsLeft == null) return false;

    final Rect frame = Offset.zero & size;
    final List<_Strip> strips =
        bottom ? _bottom(body, cutout, sizeScale) : _top(body, cutout, sizeScale);

    // 1. Своя одежда, которой у новой вещи нет, — закрашиваем кожей.
    if (skin != null && shading != null) {
      final Path cover = bottom
          ? (shape == GarmentShape.shorts ? body.legs() : Path())
          : (shape == GarmentShape.longSleeve ? Path() : body.arms());
      _paintSkin(canvas, frame, cover, skin, shading);
    }

    // 2. Вещь; поверх — свет и складки кадра (только на вещи).
    // Вещь рисуется полосами: каждая полоса фото — со своим поворотом
    // и шириной. Это обычное рисование картинки, оно надёжно работает
    // на любом телефоне (текстурированные треугольники на части Android
    // с Impeller приводили к вылету).
    final Paint garment = Paint()..filterQuality = FilterQuality.medium;
    void drawGarment() {
      for (final _Strip strip in strips) {
        canvas.save();
        canvas.translate(strip.center.dx, strip.center.dy);
        canvas.rotate(strip.angle);
        canvas.drawImageRect(
          cutout.image,
          strip.source,
          Rect.fromCenter(center: Offset.zero, width: strip.width, height: strip.height),
          garment,
        );
        canvas.restore();
      }
    }

    if (shading == null) {
      drawGarment();
      return true;
    }
    final Rect source =
        Rect.fromLTWH(0, 0, shading.width.toDouble(), shading.height.toDouble());
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
    // По фигуре: вещь обрезается по силуэту человека. Силуэт для этого
    // чуть растянут от центра корпуса — у свободных размеров вещь
    // отходит от тела, у маленьких сидит в обтяжку.
    final double loose = math.max(sizeScale, 1) + 0.08;
    final Offset center = bottom ? body.hipMid : (body.shoulderMid + body.hipMid) / 2;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(loose, 1 + (loose - 1) * 0.5);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawImageRect(
      shading,
      source,
      frame,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..blendMode = BlendMode.dstIn,
    );
    canvas.restore();
    canvas.restore();
    return true;
  }

  /// Кожа по [cover], только там, где человек (маска в альфа-канале
  /// [shading]), с тенями кадра.
  static void _paintSkin(
    Canvas canvas,
    Rect frame,
    Path cover,
    Color skin,
    ui.Image shading,
  ) {
    final Rect source = Rect.fromLTWH(
      0, 0, shading.width.toDouble(), shading.height.toDouble(),
    );
    final Paint color = Paint()..color = skin;
    canvas.saveLayer(frame, Paint());
    canvas.drawPath(cover, color);
    // Тени и складки кадра — только на закрашенном месте.
    canvas.saveLayer(frame, Paint()..blendMode = BlendMode.srcATop);
    canvas.drawPath(cover, color);
    canvas.drawImageRect(
      shading, source, frame,
      Paint()..blendMode = BlendMode.hardLight,
    );
    canvas.restore();
    // Только в пределах силуэта человека (маска — альфа-канал).
    canvas.drawImageRect(
      shading, source, frame,
      Paint()..blendMode = BlendMode.dstIn,
    );
    canvas.restore();
  }

  // ---------------------------------------------------------------------------
  // Верх: вещь целиком, по линии плеч и бёдер

  /// Каждая строка фото ложится на своё место между плечами и бёдрами:
  /// строка плеч — на плечи, строка бёдер — на бёдра. Ширина строки
  /// растёт или уменьшается вместе с телом (плечи шире, талия уже),
  /// вещь поворачивается с корпусом.
  static List<_Strip> _top(_Body body, GarmentCutout cutout, double sizeScale) {
    final double shoulderRow = cutout.topSpanY;
    final double hipRow = math.max(cutout.hipRow, shoulderRow + 1);
    // Размер меньше — вещь чуть уже и заметно короче; больше — шире
    // и длиннее.
    final double wide = 1 + (sizeScale - 1) * (sizeScale > 1 ? 1 : 0.4);
    final double length = 1 + (sizeScale - 1) * 0.8;
    // Пиксели фото → пиксели тела на линии плеч и на линии бёдер.
    final double atShoulders =
        body.shoulderDistance * (1 + 2 * shoulderOverhang) * wide / cutout.topSpan;
    final double atHips = math.max(
          body.hipDistance * hipOutline,
          body.shoulderDistance * 1.15,
        ) *
        wide /
        cutout.hipSpan;

    Offset map(double px, double py) {
      final double t = (py - shoulderRow) / (hipRow - shoulderRow) * length;
      final double k = ui.lerpDouble(atShoulders, atHips, t.clamp(0.0, 1.0))!;
      final Offset center = Offset.lerp(body.shoulderMid, body.hipMid, t)!;
      final Offset across = _unit(
        Offset.lerp(body.shoulderAcross, body.hipAcross, t.clamp(0.0, 1.0))!,
      );
      return center + across * ((px - cutout.centerX) * k);
    }

    return _grid(cutout.bounds, map);
  }

  // ---------------------------------------------------------------------------
  // Шорты и штаны

  static List<_Strip> _bottom(_Body body, GarmentCutout cutout, double sizeScale) {
    final double waist = body.hipDistance * hipOutline * sizeScale;
    final double scale = waist / cutout.topSpan;
    final double length = 1 + (sizeScale - 1) * 0.8;
    final Offset across = _unit(body.hipAcross);
    final Offset down = Offset(-across.dy, across.dx).dy < 0
        ? -Offset(-across.dy, across.dx)
        : Offset(-across.dy, across.dx);
    // Пояс — выше суставов бёдер.
    final Offset waistCenter = body.hipMid - down * (body.hipDistance * 0.35);
    Offset map(double px, double py) =>
        waistCenter +
        across * ((px - cutout.centerX) * scale) +
        down * ((py - cutout.topSpanY) * scale * length);
    return _grid(cutout.bounds, map);
  }

  // ---------------------------------------------------------------------------
  // Геометрия

  /// Фото [area] режется на горизонтальные полосы; для каждой полосы
  /// функция [map] (точка фото → точка тела) даёт центр, ширину, высоту
  /// и наклон на теле.
  static List<_Strip> _grid(Rect area, Offset Function(double, double) map) {
    const int r = rows;
    final List<_Strip> strips = [];
    for (int j = 0; j < r; j++) {
      final double y0 = area.top + area.height * j / r;
      final double y1 = area.top + area.height * (j + 1) / r;
      final double ym = (y0 + y1) / 2;
      final Offset left = map(area.left, ym);
      final Offset right = map(area.right, ym);
      final Offset across = right - left;
      final double height = (map(area.center.dx, y1) - map(area.center.dx, y0)).distance;
      if (across.distance < 1 || height <= 0) continue;
      strips.add(_Strip(
        source: Rect.fromLTRB(area.left, y0, area.right, y1),
        center: (left + right) / 2,
        angle: math.atan2(across.dy, across.dx),
        width: across.distance,
        // Полосы чуть внахлёст — без щелей между ними.
        height: height + 1,
      ));
    }
    return strips;
  }

  static Offset _unit(Offset v) {
    final double d = v.distance;
    return d == 0 ? const Offset(1, 0) : v / d;
  }
}

/// Полоса фото вещи и где она на теле.
class _Strip {
  const _Strip({
    required this.source,
    required this.center,
    required this.angle,
    required this.width,
    required this.height,
  });

  final Rect source;
  final Offset center;
  final double angle;
  final double width;
  final double height;
}

/// Тело в кадре: суставы слева и справа по экрану (с зеркалом фронтальной
/// камеры левое плечо человека оказывается справа).
class _Body {
  _Body({
    required this.shoulderLeft,
    required this.shoulderRight,
    this.hipsLeft,
    this.hipsRight,
    required this.joints,
    required this.leftIsLeft,
  });

  final Offset shoulderLeft, shoulderRight;
  final Offset? hipsLeft, hipsRight;
  final Map<BodyJoint, Offset> joints;

  /// Левый по экрану — это левый сустав человека (не зеркало).
  final bool leftIsLeft;

  static _Body? of(BodyPose pose, Size size) {
    final Map<BodyJoint, Offset> joints = {
      for (final BodyJoint joint in BodyJoint.values)
        if (pose[joint] case final BodyPoint p)
          joint: Offset(p.x * size.width, p.y * size.height),
    };
    final Offset? ls = joints[BodyJoint.leftShoulder];
    final Offset? rs = joints[BodyJoint.rightShoulder];
    if (ls == null || rs == null || (ls - rs).distance < 8) return null;
    final bool leftIsLeft = ls.dx <= rs.dx;
    final Offset? lh = joints[BodyJoint.leftHip];
    final Offset? rh = joints[BodyJoint.rightHip];
    return _Body(
      shoulderLeft: leftIsLeft ? ls : rs,
      shoulderRight: leftIsLeft ? rs : ls,
      hipsLeft: lh == null || rh == null ? null : (leftIsLeft ? lh : rh),
      hipsRight: lh == null || rh == null ? null : (leftIsLeft ? rh : lh),
      joints: joints,
      leftIsLeft: leftIsLeft,
    );
  }

  double get shoulderDistance => (shoulderRight - shoulderLeft).distance;
  Offset get shoulderMid => (shoulderLeft + shoulderRight) / 2;
  Offset get shoulderAcross => shoulderRight - shoulderLeft;

  Offset get _down {
    final Offset a = FittedGarmentPainter._unit(shoulderAcross);
    final Offset n = Offset(-a.dy, a.dx);
    return n.dy < 0 ? -n : n;
  }

  /// Без видимых бёдер — оцениваем их ниже плеч.
  Offset get hipMid => hipsLeft != null && hipsRight != null
      ? (hipsLeft! + hipsRight!) / 2
      : shoulderMid + _down * (shoulderDistance * 1.5);
  Offset get hipAcross => hipsLeft != null && hipsRight != null
      ? hipsRight! - hipsLeft!
      : shoulderAcross * 0.75;
  double get hipDistance => hipAcross.distance;

  BodyJoint _side(BodyJoint left, BodyJoint right, bool screenLeft) =>
      screenLeft == leftIsLeft ? left : right;

  /// Рука по экрану слева или справа: плечо → локоть → запястье.
  List<Offset>? arm(bool screenLeft) {
    final Offset shoulder = screenLeft ? shoulderLeft : shoulderRight;
    final Offset? elbow = joints[_side(BodyJoint.leftElbow, BodyJoint.rightElbow, screenLeft)];
    if (elbow == null) return null;
    final Offset? wrist = joints[_side(BodyJoint.leftWrist, BodyJoint.rightWrist, screenLeft)];
    return [shoulder, elbow, if (wrist != null) wrist];
  }

  List<Offset>? leg(bool screenLeft) {
    final Offset? hip = screenLeft ? hipsLeft : hipsRight;
    final Offset? knee = joints[_side(BodyJoint.leftKnee, BodyJoint.rightKnee, screenLeft)];
    if (hip == null || knee == null) return null;
    final Offset? ankle = joints[_side(BodyJoint.leftAnkle, BodyJoint.rightAnkle, screenLeft)];
    return [hip, knee, if (ankle != null) ankle];
  }

  /// Обе руки — «колбасками» по суставам: здесь своя одежда
  /// закрывается кожей.
  Path arms() => _capsules([arm(true), arm(false)], shoulderDistance * 0.2);

  Path legs() => _capsules([leg(true), leg(false)], hipDistance * 0.4);

  static Path _capsules(List<List<Offset>?> chains, double radius) {
    final Path path = Path();
    for (final List<Offset>? chain in chains) {
      if (chain == null) continue;
      for (int i = 1; i < chain.length; i++) {
        final Offset a = chain[i - 1], b = chain[i];
        final Offset d = FittedGarmentPainter._unit(b - a);
        final Offset n = Offset(-d.dy, d.dx) * radius;
        path.addPolygon([a + n, b + n, b - n, a - n], true);
        path.addOval(Rect.fromCircle(center: b, radius: radius));
      }
      path.addOval(Rect.fromCircle(center: chain.first, radius: radius));
    }
    return path;
  }
}
