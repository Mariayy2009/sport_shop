import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/outfit.dart';

/// Манекен для виртуальной примерки.
///
/// Пропорции строятся по росту и весу пользователя, вещи рисуются слоями
/// поверх фигуры в выбранных цветах. Поворот ([angle], радианы) — это
/// сжатие по горизонтали с тенью на дальней половине: псевдо-3D без тяжёлого движка.
/// Все координаты — в долях высоты фигуры: (0, 0) — макушка по центру.
class AvatarPainter extends CustomPainter {
  AvatarPainter({
    required this.heightCm,
    required this.weightKg,
    required this.angle,
    required this.outfit,
    this.showBody = true,
    this.widthFactor,
    this.fillHeight = false,
  });

  final int heightCm;
  final int weightKg;
  final double angle;
  final Map<WearSlot, WornItem> outfit;

  /// false — рисуется только одежда (поверх фото пользователя).
  final bool showBody;

  /// Ширина фигуры вручную; null — считается по росту и весу.
  final double? widthFactor;

  /// Фигура занимает всю высоту области (её размер задаёт родитель).
  final bool fillHeight;

  static const Color _body = Color(0xFFD5DBE6);
  static const Color _bodyShade = Color(0xFFC2CAD8);
  static const Color _outline = Color(0x33101828);

  // Ключевые уровни фигуры (доля высоты).
  static const double _yShoulder = 0.155;
  static const double _yChest = 0.24;
  static const double _yWaist = 0.36;
  static const double _yHip = 0.45;
  static const double _yCrotch = 0.49;
  static const double _yKnee = 0.70;
  static const double _yAnkle = 0.93;

  /// Коэффициент ширины: 1.0 при ИМТ 21, шире при большем весе.
  double get _wf {
    if (widthFactor != null) return widthFactor!;
    final double meters = heightCm / 100;
    final double bmi = weightKg / (meters * meters);
    return (1 + (bmi - 21) * 0.028).clamp(0.82, 1.4);
  }

  late final double _shoulderHw = 0.112 * _wf;
  late final double _chestHw = 0.1 * _wf;
  late final double _waistHw = 0.082 * _wf * (1 + (_wf - 1) * 0.5);
  late final double _hipHw = 0.102 * _wf;

  @override
  void paint(Canvas canvas, Size size) {
    final (double figure, double top) = _layout(size);

    if (showBody) {
      // Тень на полу.
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width / 2, top + figure * 0.985),
          width: figure * 0.34,
          height: figure * 0.03,
        ),
        Paint()..color = const Color(0x1F101828),
      );
    }

    final Rect bounds = Offset.zero & size;
    canvas.saveLayer(bounds, Paint());
    canvas.translate(size.width / 2, top);
    canvas.scale(figure * (0.5 + 0.5 * math.cos(angle).abs()), figure);

    if (showBody) _paintBody(canvas);
    _paintOutfit(canvas);

    // Объём: ровная полупрозрачная тень на дальней половине фигуры.
    final double side = math.sin(angle);
    if (showBody && side.abs() > 0.05) {
      canvas.drawRect(
        side > 0
            ? const Rect.fromLTRB(0.012, 0, 0.5, 1)
            : const Rect.fromLTRB(-0.5, 0, -0.012, 1),
        Paint()
          ..blendMode = BlendMode.srcATop
          ..color = Color.fromRGBO(16, 24, 40, 0.06 + 0.16 * side.abs()),
      );
    }
    canvas.restore();
  }

  /// Высота фигуры в пикселях и отступ её макушки от верха области.
  (double, double) _layout(Size size) {
    if (fillHeight) return (size.height, 0);
    // Рост 150–200 см занимает 80–100 % высоты области.
    final double scale = (0.8 + (heightCm - 150) / 50 * 0.2).clamp(0.72, 1.0);
    final double figure = size.height * 0.96 * scale;
    return (figure, size.height * 0.98 - figure);
  }

  /// Прямоугольник головы манекена — туда ставится фото лица.
  Rect headRect(Size size) {
    final (double figure, double top) = _layout(size);
    final double squeeze = 0.5 + 0.5 * math.cos(angle).abs();
    return Rect.fromCenter(
      center: Offset(size.width / 2, top + figure * 0.062),
      width: figure * 0.092 * squeeze,
      height: figure * 0.115,
    );
  }

  // ---------------------------------------------------------------------------
  // Фигура
  // ---------------------------------------------------------------------------

  void _paintBody(Canvas canvas) {
    final Paint fill = Paint()..color = _body;
    for (final int side in const [-1, 1]) {
      _fill(canvas, _leg(side, _yHip, _yAnkle + 0.01), fill);
      // Стопа.
      canvas.drawRRect(_foot(side, 0), Paint()..color = _bodyShade);
      _fill(canvas, _arm(side, 0.165, 0.5), fill);
      canvas.drawCircle(Offset(side * (_shoulderHw + 0.043), 0.515), 0.02, fill);
    }
    _fill(canvas, _torso(_yShoulder, _yCrotch), fill);
    // Шея и голова.
    canvas.drawRect(const Rect.fromLTRB(-0.024, 0.1, 0.024, 0.165), fill);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 0.062), width: 0.092, height: 0.115),
      fill,
    );
  }

  void _paintOutfit(Canvas canvas) {
    final WornItem? upper = outfit[WearSlot.upper];
    final WornItem? lower = outfit[WearSlot.lower];
    final WornItem? feet = outfit[WearSlot.feet];
    final WornItem? extra = outfit[WearSlot.extra];

    if (extra?.kind == WearKind.socks) {
      for (final int side in const [-1, 1]) {
        _fill(canvas, _leg(side, 0.74, _yAnkle + 0.01, pad: 0.004), _paint(extra!.color));
      }
    }
    if (upper?.kind == WearKind.kimono) {
      _pants(canvas, upper!.color, 0.9, pad: 0.016);
    } else if (upper?.kind == WearKind.set) {
      _pants(canvas, upper!.color, 0.6, pad: 0.012);
    } else if (lower != null) {
      lower.kind == WearKind.shorts
          ? _pants(canvas, lower.color, 0.6, pad: 0.012)
          : _pants(canvas, lower.color, 0.915, pad: 0.005);
    }
    if (feet != null) {
      for (final int side in const [-1, 1]) {
        final RRect shoe = _foot(side, 0.008);
        canvas.drawRRect(shoe, _paint(feet.color));
        canvas.drawRRect(shoe, _stroke);
        // Подошва.
        canvas.drawRect(
          Rect.fromLTRB(shoe.left, shoe.bottom - 0.008, shoe.right, shoe.bottom),
          Paint()..color = _contrast(feet.color).withValues(alpha: 0.55),
        );
      }
    }
    if (extra?.kind == WearKind.knee) {
      for (final int side in const [-1, 1]) {
        _fill(canvas, _leg(side, 0.662, 0.738, pad: 0.007), _paint(extra!.color));
      }
    }
    if (upper != null) _upper(canvas, upper);
  }

  void _upper(Canvas canvas, WornItem item) {
    final Paint paint = _paint(item.color);
    final Paint accent = Paint()
      ..color = _contrast(item.color).withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.008;

    switch (item.kind) {
      case WearKind.top:
        for (final int side in const [-1, 1]) {
          _fill(canvas, _arm(side, 0.16, 0.285, pad: 0.008), paint);
        }
        _fill(canvas, _torso(_yShoulder - 0.004, 0.455, pad: 0.007, flatHem: true), paint);
        _neckline(canvas, 0.03);
      case WearKind.set:
        // Игровая майка без рукавов с полосой на груди.
        _fill(canvas, _torso(_yShoulder - 0.004, 0.455, pad: 0.007, flatHem: true), paint);
        _neckline(canvas, 0.036);
        canvas.drawLine(
          Offset(-_chestHw * 0.9, 0.262),
          Offset(_chestHw * 0.9, 0.262),
          accent,
        );
      case WearKind.swimsuit:
        _fill(canvas, _torso(0.185, _yCrotch + 0.004, pad: 0.003), paint);
        _neckline(canvas, 0.04);
      case WearKind.kimono:
        for (final int side in const [-1, 1]) {
          _fill(canvas, _arm(side, 0.16, 0.44, pad: 0.014), paint);
        }
        _fill(canvas, _torso(_yShoulder - 0.004, 0.56, pad: 0.014, flatHem: true), paint);
        // Запах куртки и пояс.
        final Paint lapel = Paint()
          ..color = _outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.005;
        canvas.drawLine(const Offset(-0.03, 0.15), Offset(0.025, _yWaist), lapel);
        canvas.drawLine(const Offset(0.03, 0.15), const Offset(-0.004, 0.25), lapel);
        canvas.drawRect(
          Rect.fromLTRB(-_waistHw - 0.016, _yWaist, _waistHw + 0.016, _yWaist + 0.024),
          Paint()..color = const Color(0xFF10141C),
        );
      case WearKind.shorts ||
            WearKind.pants ||
            WearKind.shoes ||
            WearKind.knee ||
            WearKind.socks:
        break;
    }
  }

  /// Шорты или штаны: пояс + две штанины до уровня [yBottom].
  void _pants(Canvas canvas, Color color, double yBottom, {required double pad}) {
    final Paint paint = _paint(color);
    for (final int side in const [-1, 1]) {
      _fill(canvas, _leg(side, _yHip - 0.01, yBottom, pad: pad, flat: true), paint);
    }
    _fill(canvas, _torso(_yWaist + 0.03, _yCrotch + 0.008, pad: pad * 0.6), paint);
  }

  void _neckline(Canvas canvas, double halfWidth) {
    // На фото вырез не закрашиваем: под одеждой видна шея человека.
    if (!showBody) return;
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(0, _yShoulder - 0.002),
        width: halfWidth * 2,
        height: 0.03,
      ),
      Paint()..color = _body,
    );
  }

  // ---------------------------------------------------------------------------
  // Геометрия
  // ---------------------------------------------------------------------------

  /// Полуширина торса на уровне [y].
  double _torsoHw(double y) {
    if (y <= _yChest) return _lerp(_shoulderHw, _chestHw, (y - _yShoulder) / (_yChest - _yShoulder));
    if (y <= _yWaist) return _lerp(_chestHw, _waistHw, (y - _yChest) / (_yWaist - _yChest));
    return _lerp(_waistHw, _hipHw, ((y - _yWaist) / (_yHip - _yWaist)).clamp(0, 1));
  }

  Path _torso(double yTop, double yBottom, {double pad = 0, bool flatHem = false}) {
    final List<Offset> right = [];
    const int steps = 10;
    final double sideBottom = flatHem ? yBottom : math.min(yBottom, _yHip);
    for (int i = 0; i <= steps; i++) {
      final double y = _lerp(yTop, sideBottom, i / steps);
      right.add(Offset(_torsoHw(math.max(y, _yShoulder)) + pad, y));
    }
    final List<Offset> points = [
      ...right,
      // Без ровного подола низ торса сходится к паху.
      if (!flatHem && yBottom > _yHip) Offset(0, yBottom),
      for (final Offset point in right.reversed) Offset(-point.dx, point.dy),
    ];
    return _polygon(points);
  }

  /// Центр и полуширина ноги на уровне [y].
  (double, double) _legAt(double y) {
    final double hipCenter = _hipHw / 2 + 0.004;
    final double kneeCenter = 0.054 * _wf;
    final double ankleCenter = 0.05 * _wf;
    if (y <= _yKnee) {
      final double t = ((y - _yHip) / (_yKnee - _yHip)).clamp(0, 1);
      return (_lerp(hipCenter, kneeCenter, t), _lerp(_hipHw / 2, 0.034 * _wf, t));
    }
    final double t = ((y - _yKnee) / (_yAnkle - _yKnee)).clamp(0, 1);
    return (_lerp(kneeCenter, ankleCenter, t), _lerp(0.034 * _wf, 0.021 * _wf, t));
  }

  Path _leg(int side, double yTop, double yBottom, {double pad = 0, bool flat = false}) {
    final List<Offset> outer = [];
    final List<Offset> inner = [];
    const int steps = 8;
    for (int i = 0; i <= steps; i++) {
      final double y = _lerp(yTop, yBottom, i / steps);
      final (double center, double hw) = _legAt(y);
      outer.add(Offset(side * (center + hw + pad), y));
      // Выше паха внутренняя граница — середина тела.
      final double innerX = y < _yCrotch ? 0 : math.max(center - hw - pad, 0.002);
      inner.add(Offset(side * innerX, y));
    }
    return _polygon([...outer, ...inner.reversed], smooth: !flat);
  }

  Path _arm(int side, double yTop, double yBottom, {double pad = 0}) {
    final List<Offset> outer = [];
    final List<Offset> inner = [];
    const int steps = 6;
    for (int i = 0; i <= steps; i++) {
      final double y = _lerp(yTop, yBottom, i / steps);
      final double t = ((y - 0.165) / (0.5 - 0.165)).clamp(0, 1);
      final double center = _lerp(_shoulderHw + 0.004, _shoulderHw + 0.04, t);
      final double hw = _lerp(0.03 * _wf, 0.019 * _wf, t) + pad;
      outer.add(Offset(side * (center + hw), y));
      inner.add(Offset(side * (center - hw), y));
    }
    return _polygon([...outer, ...inner.reversed]);
  }

  RRect _foot(int side, double pad) {
    final (double center, _) = _legAt(_yAnkle);
    return RRect.fromRectAndRadius(
      Rect.fromLTRB(
        side * (center + 0.008) - 0.033 - pad,
        0.928 - pad,
        side * (center + 0.008) + 0.033 + pad,
        0.975,
      ),
      const Radius.circular(0.018),
    );
  }

  /// Многоугольник по точкам; при [smooth] углы скругляются кривыми.
  static Path _polygon(List<Offset> points, {bool smooth = true}) {
    final Path path = Path();
    if (!smooth) {
      return path..addPolygon(points, true);
    }
    Offset mid(Offset a, Offset b) => Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
    final Offset start = mid(points.last, points.first);
    path.moveTo(start.dx, start.dy);
    for (int i = 0; i < points.length; i++) {
      final Offset next = mid(points[i], points[(i + 1) % points.length]);
      path.quadraticBezierTo(points[i].dx, points[i].dy, next.dx, next.dy);
    }
    return path..close();
  }

  void _fill(Canvas canvas, Path path, Paint paint) {
    canvas.drawPath(path, paint);
    if (paint.color != _body) canvas.drawPath(path, _stroke);
  }

  static final Paint _stroke = Paint()
    ..color = _outline
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.003;

  static Paint _paint(Color color) => Paint()..color = color;

  /// Контрастный цвет для полос и подошвы.
  static Color _contrast(Color color) =>
      color.computeLuminance() > 0.5 ? const Color(0xFF10141C) : const Color(0xFFFFFFFF);

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  bool shouldRepaint(AvatarPainter oldDelegate) =>
      oldDelegate.heightCm != heightCm ||
      oldDelegate.weightKg != weightKg ||
      oldDelegate.angle != angle ||
      oldDelegate.showBody != showBody ||
      oldDelegate.widthFactor != widthFactor ||
      oldDelegate.outfit != outfit;
}
