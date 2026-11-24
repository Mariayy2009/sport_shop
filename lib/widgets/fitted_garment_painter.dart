import 'dart:math' as math;
import 'dart:typed_data';
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
  static const int rows = 16;

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
    final ImageShader texture = ImageShader(
      cutout.image,
      TileMode.decal,
      TileMode.decal,
      Matrix4.identity().storage,
    );
    final List<ui.Vertices> parts = [
      bottom ? _bottom(body, cutout, sizeScale) : _top(body, cutout, sizeScale),
    ];

    // 1. Своя одежда, которой у новой вещи нет, — закрашиваем кожей.
    if (skin != null && shading != null) {
      final Path cover = bottom
          ? (shape == GarmentShape.shorts ? body.legs() : Path())
          : (shape == GarmentShape.longSleeve ? Path() : body.arms());
      _paintSkin(canvas, frame, cover, skin, shading);
    }

    // 2. Вещь; поверх — свет и складки кадра (только на вещи).
    final Paint garment = Paint()
      ..shader = texture
      ..filterQuality = FilterQuality.medium;
    void drawGarment() {
      for (final ui.Vertices part in parts) {
        canvas.drawVertices(part, BlendMode.dst, garment);
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
  static ui.Vertices _top(_Body body, GarmentCutout cutout, double sizeScale) {
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

  static ui.Vertices _bottom(_Body body, GarmentCutout cutout, double sizeScale) {
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

  /// Сетка треугольников по прямоугольнику фото [area]: каждая точка
  /// переносится на тело функцией [map], текстура — само фото.
  static ui.Vertices _grid(Rect area, Offset Function(double, double) map) {
    const int c = columns, r = rows;
    final Float32List positions = Float32List((c + 1) * (r + 1) * 2);
    final Float32List texture = Float32List((c + 1) * (r + 1) * 2);
    for (int j = 0; j <= r; j++) {
      for (int i = 0; i <= c; i++) {
        final double px = area.left + area.width * i / c;
        final double py = area.top + area.height * j / r;
        final Offset p = map(px, py);
        final int k = (j * (c + 1) + i) * 2;
        positions[k] = p.dx;
        positions[k + 1] = p.dy;
        texture[k] = px;
        texture[k + 1] = py;
      }
    }
    final Uint16List indices = Uint16List(c * r * 6);
    int n = 0;
    for (int j = 0; j < r; j++) {
      for (int i = 0; i < c; i++) {
        final int a = j * (c + 1) + i, b = a + 1, d = a + c + 1, e = d + 1;
        indices.setAll(n, [a, b, d, b, e, d]);
        n += 6;
      }
    }
    return ui.Vertices.raw(
      ui.VertexMode.triangles,
      positions,
      textureCoordinates: texture,
      indices: indices,
    );
  }

  static Offset _unit(Offset v) {
    final double d = v.distance;
    return d == 0 ? const Offset(1, 0) : v / d;
  }
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
