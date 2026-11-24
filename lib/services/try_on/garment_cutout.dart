import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'garment_scan.dart';

/// Вещь, вырезанная из фото товара: фон убран, измерены плечи
/// (у верха) или пояс (у низа). Её накладывают на тело в живой
/// примерке — с настоящим цветом, принтом, номером и надписями.
class GarmentCutout {
  GarmentCutout._({
    required this.image,
    required this.width,
    required this.height,
    required this.bounds,
    required this.topSpanY,
    required this.topSpan,
    required this.torsoLeft,
    required this.torsoRight,
    required this.sleeveBottom,
    required this.hipRow,
    required this.hipSpan,
  });

  /// Строка фото, которая ложится на линию бёдер, и ширина вещи на ней.
  final double hipRow;
  final double hipSpan;

  /// Корпус вещи без рукавов (по горизонтали) и нижний край рукавов —
  /// по ним фото режется на части: корпус ложится на тело, рукава — на руки.
  final double torsoLeft;
  final double torsoRight;
  final double sleeveBottom;

  /// Картинка с прозрачным фоном.
  final ui.Image image;
  final int width;
  final int height;

  /// Где на картинке сама вещь.
  final ui.Rect bounds;

  /// Строка плеч (у верха) или пояса (у низа) и её ширина
  /// в пикселях картинки — по ним вещь подгоняется к телу.
  final double topSpanY;
  final double topSpan;
  double get centerX => bounds.center.dx;

  /// Сторона, до которой уменьшается фото: качества хватает, а фон
  /// убирается за доли секунды.
  static const int side = 480;

  /// Насколько цвет может отличаться от фона, чтобы считаться фоном.
  static const int tolerance = 42;

  /// Вещь, отсканированная продавцом: PNG с прозрачным фоном и опорные
  /// линии, измеренные по позе во время сканирования.
  static Future<GarmentCutout?> fromScan(
    Uint8List png,
    ScanAnchors anchors,
  ) async {
    try {
      final ui.Codec codec = await ui.instantiateImageCodec(png);
      final ui.Image image = (await codec.getNextFrame()).image;
      final double w = image.width.toDouble(), h = image.height.toDouble();
      return GarmentCutout._(
        image: image,
        width: image.width,
        height: image.height,
        // Снимок выровнен по центру корпуса — центр кадра и есть центр вещи.
        bounds: ui.Rect.fromLTWH(0, 0, w, h),
        topSpanY: anchors.shoulderY,
        topSpan: anchors.span,
        torsoLeft: anchors.centerX - anchors.span / 2,
        torsoRight: anchors.centerX + anchors.span / 2,
        sleeveBottom: anchors.hipY,
        hipRow: anchors.hipY,
        hipSpan: anchors.hipSpan,
      );
    } on Exception {
      return null;
    }
  }

  /// Вырезает вещь из фото [bytes]. [isBottom] — шорты или штаны
  /// (мерить пояс, а не плечи). null — фото не подходит: фон не
  /// однотонный или вещь не отделяется от него.
  static Future<GarmentCutout?> fromImage(
    Uint8List bytes, {
    required bool isBottom,
  }) async {
    try {
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.Image original = (await codec.getNextFrame()).image;
      final double k =
          math.min(1, side / math.max(original.width, original.height));
      final int w = math.max(1, (original.width * k).round());
      final int h = math.max(1, (original.height * k).round());
      original.dispose();
      final ui.Codec small = await ui.instantiateImageCodec(
        bytes,
        targetWidth: w,
        targetHeight: h,
      );
      final ui.Image image = (await small.getNextFrame()).image;
      final ByteData? data =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      if (data == null) return null;
      final Uint8List rgba = Uint8List.fromList(data.buffer.asUint8List());
      final CutoutMask? mask = cut(rgba, w, h, isBottom: isBottom);
      if (mask == null) return null;
      final Completer<ui.Image> done = Completer<ui.Image>();
      ui.decodeImageFromPixels(mask.rgba, w, h, ui.PixelFormat.rgba8888, done.complete);
      return GarmentCutout._(
        image: await done.future,
        width: w,
        height: h,
        bounds: mask.bounds,
        topSpanY: mask.topSpanY,
        topSpan: mask.topSpan,
        torsoLeft: mask.torsoLeft,
        torsoRight: mask.torsoRight,
        sleeveBottom: mask.sleeveBottom,
        hipRow: mask.hipRow,
        hipSpan: mask.hipSpan,
      );
    } on Exception {
      return null;
    }
  }

  /// Чистая часть без Flutter — для тестов: убирает фон заливкой от
  /// краёв кадра (фон каталожных фото однотонный и касается краёв)
  /// и меряет вещь. Возвращает null, если вещь не отделилась.
  static CutoutMask? cut(Uint8List rgba, int w, int h, {required bool isBottom}) {
    // Цвет фона — средний по краям кадра.
    int br = 0, bg = 0, bb = 0, n = 0;
    void sample(int x, int y) {
      final int i = (y * w + x) * 4;
      br += rgba[i];
      bg += rgba[i + 1];
      bb += rgba[i + 2];
      n++;
    }

    for (int x = 0; x < w; x++) {
      sample(x, 0);
      sample(x, h - 1);
    }
    for (int y = 0; y < h; y++) {
      sample(0, y);
      sample(w - 1, y);
    }
    br ~/= n;
    bg ~/= n;
    bb ~/= n;

    int distance2(int i, int r, int g, int b) {
      final int dr = rgba[i] - r, dg = rgba[i + 1] - g, db = rgba[i + 2] - b;
      return dr * dr + dg * dg + db * db;
    }

    // Заливка от краёв. Фон бывает с плавным переходом (студийная
    // подсветка), поэтому сравниваем точку с соседней уже залитой —
    // шаг должен быть маленьким, — и с общим цветом фона — с запасом.
    final Uint8List background = Uint8List(w * h);
    final Queue<int> queue = Queue<int>();
    void seed(int x, int y) {
      final int p = y * w + x;
      if (background[p] == 1 ||
          distance2(p * 4, br, bg, bb) > tolerance * tolerance) {
        return;
      }
      background[p] = 1;
      queue.add(p);
    }

    for (int x = 0; x < w; x++) {
      seed(x, 0);
      seed(x, h - 1);
    }
    for (int y = 0; y < h; y++) {
      seed(0, y);
      seed(w - 1, y);
    }
    const int step = 7, far = 70;
    void spread(int from, int to) {
      if (background[to] == 1) return;
      final int i = from * 4;
      if (distance2(to * 4, rgba[i], rgba[i + 1], rgba[i + 2]) > step * step) return;
      if (distance2(to * 4, br, bg, bb) > far * far) return;
      background[to] = 1;
      queue.add(to);
    }

    while (queue.isNotEmpty) {
      final int p = queue.removeFirst();
      final int x = p % w, y = p ~/ w;
      if (x > 0) spread(p, p - 1);
      if (x < w - 1) spread(p, p + 1);
      if (y > 0) spread(p, p - w);
      if (y < h - 1) spread(p, p + w);
    }

    // Вещь — всё, что не фон.
    int minX = w, minY = h, maxX = -1, maxY = -1, count = 0;
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        if (background[y * w + x] == 1) continue;
        count++;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
    final double share = count / (w * h);
    // Фон не однотонный (вещь «съела» весь кадр) или вещи почти нет.
    if (maxX < 0 || share < 0.08 || share > 0.85) return null;

    // Прозрачный фон; край вещи смягчён на пиксель. Цвет прозрачных
    // точек обнуляется: Flutter рисует пиксели как «умноженные на
    // прозрачность», и белый фон с нулевой прозрачностью проступил бы.
    for (int p = 0; p < w * h; p++) {
      if (background[p] == 1) {
        rgba.fillRange(p * 4, p * 4 + 4, 0);
      } else {
        final int x = p % w, y = p ~/ w;
        final bool edge = (x > 0 && background[p - 1] == 1) ||
            (x < w - 1 && background[p + 1] == 1) ||
            (y > 0 && background[p - w] == 1) ||
            (y < h - 1 && background[p + w] == 1);
        if (edge) {
          const int alpha = 140;
          for (int c = 0; c < 3; c++) {
            rgba[p * 4 + c] = rgba[p * 4 + c] * alpha ~/ 255;
          }
          rgba[p * 4 + 3] = alpha;
        }
      }
    }

    // Ширина вещи на строке: от крайней левой до крайней правой точки.
    double span(int y) {
      int left = -1, right = -1;
      for (int x = minX; x <= maxX; x++) {
        if (background[y * w + x] == 0) {
          if (left < 0) left = x;
          right = x;
        }
      }
      return left < 0 ? 0 : (right - left + 1).toDouble();
    }

    final int height = maxY - minY + 1;
    // Плечи — чуть ниже ворота; пояс — у самого верха вещи.
    final int row = (minY + height * (isBottom ? 0.04 : 0.1)).round();
    final double topSpan = span(row);
    if (topSpan < 4) return null;

    // Корпус — самая узкая строка в середине вещи (ниже рукавов).
    (int, int) edges(int y) {
      int left = -1, right = -1;
      for (int x = minX; x <= maxX; x++) {
        if (background[y * w + x] == 0) {
          if (left < 0) left = x;
          right = x;
        }
      }
      return (left, right);
    }

    // Линия бёдер на фото. У футболки и майки низ почти на бёдрах;
    // если на фото комплект с брюками или шортами (вещь заметно выше,
    // чем шире: кимоно, волейбольная форма), бёдра — у пояса.
    final double aspect = height / (maxX - minX + 1);
    final double hipRow =
        row + (maxY - row) * (aspect > 1.75 ? 0.5 : 0.85);

    int torsoLeft = minX, torsoRight = maxX;
    if (!isBottom) {
      int narrowest = maxX - minX + 1;
      // Корпус ищем выше пояса: ниже — уже брюки или шорты.
      for (int y = (row + (hipRow - row) * 0.5).round(); y <= hipRow; y++) {
        final (int l, int r) = edges(y);
        if (l >= 0 && r - l + 1 < narrowest) {
          narrowest = r - l + 1;
          torsoLeft = l;
          torsoRight = r;
        }
      }
    }
    // Нижний край рукавов: последняя строка, где вещь выходит за корпус.
    int sleeveBottom = row;
    for (int y = row; y <= hipRow; y++) {
      final (int l, int r) = edges(y);
      if (l >= 0 && (l < torsoLeft - 2 || r > torsoRight + 2)) sleeveBottom = y;
    }

    return CutoutMask(
      rgba: rgba,
      bounds: ui.Rect.fromLTRB(
        minX.toDouble(), minY.toDouble(), maxX + 1.0, maxY + 1.0,
      ),
      topSpanY: row.toDouble(),
      topSpan: topSpan,
      torsoLeft: torsoLeft.toDouble(),
      torsoRight: torsoRight + 1.0,
      sleeveBottom: sleeveBottom.toDouble(),
      hipRow: hipRow,
      hipSpan: math.max(span(hipRow.round().clamp(minY, maxY)), 4),
    );
  }
}

/// Результат [GarmentCutout.cut].
class CutoutMask {
  const CutoutMask({
    required this.rgba,
    required this.bounds,
    required this.topSpanY,
    required this.topSpan,
    required this.torsoLeft,
    required this.torsoRight,
    required this.sleeveBottom,
    required this.hipRow,
    required this.hipSpan,
  });

  final Uint8List rgba;
  final double hipRow;
  final double hipSpan;
  final ui.Rect bounds;
  final double topSpanY;
  final double topSpan;
  final double torsoLeft;
  final double torsoRight;
  final double sleeveBottom;
}
