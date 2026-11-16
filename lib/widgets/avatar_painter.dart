import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/outfit.dart';

/// Манекен для виртуальной примерки.
///
/// Пропорции строятся по росту и весу пользователя, вещи рисуются слоями
/// поверх фигуры в выбранных цветах — с объёмом: тени по краям, блик,
/// складки и швы, чтобы ткань не выглядела плоской заливкой. Поворот ([angle], радианы) — это
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
    this.garmentPhotos = const {},
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

  /// Вырезанные фото вещей: если для слота есть фото, на фигуру
  /// надевается оно, а не нарисованная одежда.
  final Map<WearSlot, ui.Image> garmentPhotos;

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

    // При повороте дальняя сторона фигуры уходит в тень.
    final double side = math.sin(angle);
    if (showBody && side.abs() > 0.05) {
      canvas.drawRect(
        side > 0
            ? const Rect.fromLTRB(0.02, 0, 0.6, 1)
            : const Rect.fromLTRB(-0.6, 0, -0.02, 1),
        Paint()
          ..blendMode = BlendMode.srcATop
          ..color = Color.fromRGBO(8, 12, 24, 0.22 * side.abs())
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.03),
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
    final ui.Image? lowerPhoto = garmentPhotos[WearSlot.lower];
    if (lowerPhoto != null && lower != null) {
      final bool isShorts = lower.kind == WearKind.shorts;
      _photo(
        canvas,
        lowerPhoto,
        Rect.fromLTRB(-_hipHw - 0.035, _yWaist + 0.025, _hipHw + 0.035, isShorts ? 0.615 : 0.94),
      );
    } else if (upper?.kind == WearKind.kimono) {
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
        _volume(canvas, Path()..addRRect(shoe), feet.color);
        canvas.drawRRect(shoe, _stroke);
        // Шнуровка.
        for (int lace = 0; lace < 3; lace++) {
          final double y = shoe.top + 0.008 + lace * 0.009;
          _seam(canvas, Offset(shoe.center.dx - 0.012, y),
              Offset(shoe.center.dx + 0.012, y), feet.color, width: 0.003);
        }
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
        final (double center, double hw) = _legAt(0.7);
        for (final double y in const [0.682, 0.7, 0.718]) {
          _seam(canvas, Offset(side * (center - hw), y),
              Offset(side * (center + hw), y), extra.color, width: 0.003);
        }
      }
    }
    final ui.Image? upperPhoto = garmentPhotos[WearSlot.upper];
    if (upper != null && upperPhoto != null) {
      // Фото вещи с рукавами шире торса: рамка — от локтя до локтя.
      final double halfWidth = _shoulderHw + 0.075;
      final double bottom = switch (upper.kind) {
        WearKind.kimono => 0.58,
        WearKind.swimsuit => _yCrotch + 0.01,
        _ => 0.475,
      };
      _photo(canvas, upperPhoto, Rect.fromLTRB(-halfWidth, 0.135, halfWidth, bottom));
    } else if (upper != null) {
      _upper(canvas, upper);
    }
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
        _torsoFolds(canvas, item.color, hem: 0.455);
        for (final int side in const [-1, 1]) {
          // Кант рукава.
          _seam(
            canvas,
            Offset(side * (_shoulderHw - 0.012), 0.283),
            Offset(side * (_shoulderHw + 0.052), 0.277),
            item.color,
          );
        }
      case WearKind.set:
        // Игровая майка без рукавов с полосой на груди.
        _fill(canvas, _torso(_yShoulder - 0.004, 0.455, pad: 0.007, flatHem: true), paint);
        _neckline(canvas, 0.036);
        _torsoFolds(canvas, item.color, hem: 0.455);
        canvas.drawLine(
          Offset(-_chestHw * 0.9, 0.262),
          Offset(_chestHw * 0.9, 0.262),
          accent,
        );
        // Боковые вставки формы.
        for (final int side in const [-1, 1]) {
          _seam(
            canvas,
            Offset(side * (_chestHw - 0.012), 0.2),
            Offset(side * (_hipHw - 0.008), 0.45),
            item.color,
            width: 0.007,
          );
        }
      case WearKind.swimsuit:
        _fill(canvas, _torso(0.185, _yCrotch + 0.004, pad: 0.003), paint);
        _neckline(canvas, 0.04);
        _fold(canvas, Offset(-_waistHw * 0.9, _yWaist), Offset(0, _yWaist + 0.012),
            Offset(_waistHw * 0.9, _yWaist), item.color);
      case WearKind.kimono:
        for (final int side in const [-1, 1]) {
          _fill(canvas, _arm(side, 0.16, 0.44, pad: 0.014), paint);
        }
        _fill(canvas, _torso(_yShoulder - 0.004, 0.56, pad: 0.014, flatHem: true), paint);
        _torsoFolds(canvas, item.color, hem: 0.56);
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

  /// Вырезанное фото вещи, растянутое на свою часть фигуры.
  void _photo(Canvas canvas, ui.Image image, Rect target) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      target,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..isAntiAlias = true,
    );
  }

  /// Шорты или штаны: пояс + две штанины до уровня [yBottom].
  void _pants(Canvas canvas, Color color, double yBottom, {required double pad}) {
    final Paint paint = _paint(color);
    for (final int side in const [-1, 1]) {
      _fill(canvas, _leg(side, _yHip - 0.01, yBottom, pad: pad, flat: true), paint);
    }
    _fill(canvas, _torso(_yWaist + 0.03, _yCrotch + 0.008, pad: pad * 0.6), paint);

    // Пояс, средний шов и складки у бёдер.
    _seam(canvas, Offset(-_waistHw - pad, _yWaist + 0.048),
        Offset(_waistHw + pad, _yWaist + 0.048), color);
    _fold(canvas, Offset(0, _yWaist + 0.06), Offset(0.004, _yCrotch - 0.02),
        Offset(0, _yCrotch + 0.006), color);
    for (final int side in const [-1, 1]) {
      _fold(
        canvas,
        Offset(side * 0.012, _yCrotch - 0.004),
        Offset(side * _hipHw * 0.5, _yCrotch + 0.012),
        Offset(side * _hipHw * 0.92, _yHip + 0.012),
        color,
      );
      if (yBottom > _yKnee + 0.05) {
        // Длинные штаны: заломы на колене и у щиколотки.
        final (double kneeCenter, double kneeHw) = _legAt(_yKnee);
        _fold(
          canvas,
          Offset(side * (kneeCenter - kneeHw * 0.8), _yKnee - 0.012),
          Offset(side * kneeCenter, _yKnee + 0.004),
          Offset(side * (kneeCenter + kneeHw * 0.8), _yKnee - 0.014),
          color,
        );
        final (double ankleCenter, double ankleHw) = _legAt(yBottom - 0.03);
        _fold(
          canvas,
          Offset(side * (ankleCenter - ankleHw), yBottom - 0.034),
          Offset(side * ankleCenter, yBottom - 0.022),
          Offset(side * (ankleCenter + ankleHw), yBottom - 0.036),
          color,
        );
      } else {
        // Шорты: подгиб штанины.
        final (double hemCenter, double hemHw) = _legAt(yBottom);
        _seam(
          canvas,
          Offset(side * (hemCenter - hemHw - pad), yBottom - 0.012),
          Offset(side * (hemCenter + hemHw + pad), yBottom - 0.012),
          color,
        );
      }
    }
  }

  /// Складки на торсе: от подмышек к талии и подгиб снизу.
  void _torsoFolds(Canvas canvas, Color color, {required double hem}) {
    for (final int side in const [-1, 1]) {
      _fold(
        canvas,
        Offset(side * (_chestHw - 0.004), _yChest - 0.03),
        Offset(side * _chestHw * 0.45, _yChest + 0.03),
        Offset(side * _waistHw * 0.35, _yWaist + 0.01),
        color,
      );
      _fold(
        canvas,
        Offset(side * (_waistHw + 0.004), _yWaist - 0.01),
        Offset(side * _waistHw * 0.5, _yWaist + 0.03),
        Offset(side * _waistHw * 0.15, _yWaist + 0.055),
        color,
      );
    }
    _seam(canvas, Offset(-_torsoHw(hem) - 0.006, hem - 0.012),
        Offset(_torsoHw(hem) + 0.006, hem - 0.012), color);
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
    _volume(canvas, path, paint.color);
    if (paint.color != _body) canvas.drawPath(path, _stroke);
  }

  /// Объём: деталь выглядит как цилиндр, а не плоская заливка —
  /// мягкая тень по краям и блик со стороны света (слева сверху).
  void _volume(Canvas canvas, Path path, Color base) {
    final Rect box = path.getBounds();
    final bool dark = base.computeLuminance() < 0.18;
    canvas.save();
    canvas.clipPath(path);
    // Тень по контуру: у тёмной ткани слабее, иначе она «проваливается».
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.min(box.width, box.height) * 0.42
        ..color = Color.fromRGBO(8, 12, 24, dark ? 0.30 : 0.20)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, box.width * 0.11),
    );
    // Правая сторона дальше от света — дополнительная тень.
    canvas.drawRect(
      Rect.fromLTRB(box.left + box.width * 0.72, box.top, box.right + box.width * 0.2, box.bottom),
      Paint()
        ..color = Color.fromRGBO(8, 12, 24, dark ? 0.22 : 0.13)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, box.width * 0.14),
    );
    // Блик.
    canvas.drawOval(
      Rect.fromLTWH(
        box.left + box.width * 0.18,
        box.top + box.height * 0.06,
        box.width * 0.26,
        box.height * 0.8,
      ),
      Paint()
        ..color = Color.fromRGBO(255, 255, 255, dark ? 0.16 : 0.22)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, box.width * 0.12),
    );
    canvas.restore();
  }

  /// Складка ткани: тёмная линия и светлая кромка рядом с ней.
  void _fold(Canvas canvas, Offset from, Offset control, Offset to, Color base) {
    final Path line = Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo(control.dx, control.dy, to.dx, to.dy);
    final bool dark = base.computeLuminance() < 0.18;
    canvas.drawPath(
      line.shift(const Offset(0.003, 0.002)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 0.006
        ..color = Color.fromRGBO(255, 255, 255, dark ? 0.12 : 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.003),
    );
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 0.005
        ..color = Color.fromRGBO(8, 12, 24, dark ? 0.55 : 0.26)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.002),
    );
  }

  /// Шов или кант: тонкая чёткая линия.
  void _seam(Canvas canvas, Offset from, Offset to, Color base, {double width = 0.004}) {
    canvas.drawLine(
      from,
      to,
      Paint()
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..color = _contrast(base).withValues(alpha: 0.35),
    );
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
      oldDelegate.garmentPhotos != garmentPhotos ||
      oldDelegate.widthFactor != widthFactor ||
      oldDelegate.outfit != outfit;
}
