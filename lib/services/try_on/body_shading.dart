import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Свет и силуэт человека в кадре камеры — делают живую примерку
/// реалистичнее:
///
/// * **свет и складки** — яркость кадра там, где на человеке своя
///   одежда. Наложенная на новую вещь, она переносит тени, складки
///   и освещение комнаты, и вещь не выглядит плоской заливкой;
/// * **силуэт** — маска человека от ML Kit Selfie Segmentation. По ней
///   обрезаются края вещи, и одежда повторяет настоящий контур тела.
///
/// Хранится как маленькая картинка RGBA в координатах кадра (как
/// [BodyPose]: вертикально, с зеркалом для фронтальной камеры):
/// RGB — яркость (128 = средняя), A — принадлежность человеку.
class BodyShading {
  BodyShading({
    required this.width,
    required this.height,
    required this.rgba,
    this.skin,
  });

  /// Цвет кожи человека в кадре (с лица) — им закрашивается своя
  /// одежда там, где у примеряемой вещи нет рукавов или штанин.
  final ui.Color? skin;

  BodyShading withSkin(ui.Color? color) =>
      BodyShading(width: width, height: height, rgba: rgba, skin: color);

  /// Цвет кожи у точки [nose] (доли вертикального кадра, как в позе;
  /// зеркало уже учтено в [mirror]). Кадр: NV21 одной плоскостью
  /// (Y, затем VU), три плоскости YUV или BGRA. null — не удалось.
  static ui.Color? skinColor({
    required List<Uint8List> planes,
    required List<int> bytesPerRow,
    required List<int?> bytesPerPixel,
    required int frameWidth,
    required int frameHeight,
    required int rotation,
    required bool mirror,
    required bool bgra,
    required double noseX,
    required double noseY,
  }) {
    final bool sideways = rotation == 90 || rotation == 270;
    final int uprightWidth = sideways ? frameHeight : frameWidth;
    final int uprightHeight = sideways ? frameWidth : frameHeight;
    double r = 0, g = 0, b = 0;
    int n = 0;
    // Пятно 9×9 точек с шагом 2 пикселя вокруг носа.
    for (int dy = -4; dy <= 4; dy++) {
      for (int dx = -4; dx <= 4; dx++) {
        final double fx = (mirror ? 1 - noseX : noseX) * uprightWidth + dx * 2;
        final double fy = noseY * uprightHeight + dy * 2;
        final (int x, int y) = sensorPoint(fx, fy, rotation, frameWidth, frameHeight);
        final List<int>? rgb = rgbAt(planes, bytesPerRow, bytesPerPixel,
            frameWidth, frameHeight, x, y, bgra);
        if (rgb == null) continue;
        r += rgb[0];
        g += rgb[1];
        b += rgb[2];
        n++;
      }
    }
    if (n == 0) return null;
    return ui.Color.fromARGB(255, r ~/ n, g ~/ n, b ~/ n);
  }

  /// Цвет пикселя кадра датчика (x, y) в RGB.
  static List<int>? rgbAt(
    List<Uint8List> planes,
    List<int> bytesPerRow,
    List<int?> bytesPerPixel,
    int w,
    int h,
    int x,
    int y,
    bool bgra,
  ) {
    if (planes.isEmpty) return null;
    if (bgra) {
      final int i = y * bytesPerRow[0] + x * 4;
      if (i + 2 >= planes[0].length) return null;
      return [planes[0][i + 2], planes[0][i + 1], planes[0][i]];
    }
    final int yi = y * bytesPerRow[0] + x;
    if (yi >= planes[0].length) return null;
    final int luma = planes[0][yi];
    int u, v;
    if (planes.length >= 3) {
      final int uvRow = bytesPerRow[1];
      final int step = bytesPerPixel[1] ?? 1;
      final int ui0 = (y ~/ 2) * uvRow + (x ~/ 2) * step;
      if (ui0 >= planes[1].length || ui0 >= planes[2].length) return null;
      u = planes[1][ui0];
      v = planes[2][ui0];
    } else {
      // NV21: после яркости — пары V, U на каждые 2×2 пикселя.
      final int i = w * h + (y ~/ 2) * w + (x ~/ 2) * 2;
      if (i + 1 >= planes[0].length) return null;
      v = planes[0][i];
      u = planes[0][i + 1];
    }
    final double c = luma.toDouble(), d = u - 128.0, e = v - 128.0;
    int clamp(double value) => value.round().clamp(0, 255);
    return [
      clamp(c + 1.402 * e),
      clamp(c - 0.344 * d - 0.714 * e),
      clamp(c + 1.772 * d),
    ];
  }

  final int width;
  final int height;
  final Uint8List rgba;

  /// Ширина картинки: складкам хватает, а кадр считается за миллисекунды.
  static const int targetWidth = 84;

  /// Насколько сильно переносить свет: 1 — полностью. При сильном
  /// переносе сквозь вещь «просвечивает» рисунок своей одежды (надписи,
  /// полоски), и вещь кажется полупрозрачной — поэтому только крупные тени.
  static const double strength = 0.4;

  /// Кадр камеры → яркость и маска.
  ///
  /// [luma] — яркость кадра датчика: плоскость Y (NV21/YUV) или, при
  /// [bgra], пиксели BGRA. [rotation] — поворот кадра по часовой стрелке
  /// до вертикали (0, 90, 180, 270), как в ML Kit. [mask] — уверенность
  /// «здесь человек» в вертикальном кадре размером [maskWidth]×[maskHeight].
  static BodyShading fromFrame({
    required Uint8List luma,
    required int frameWidth,
    required int frameHeight,
    required int bytesPerRow,
    required int rotation,
    required bool mirror,
    bool bgra = false,
    List<double>? mask,
    int maskWidth = 0,
    int maskHeight = 0,
  }) {
    final bool sideways = rotation == 90 || rotation == 270;
    final int uprightWidth = sideways ? frameHeight : frameWidth;
    final int uprightHeight = sideways ? frameWidth : frameHeight;
    final int width = targetWidth;
    final int height =
        (targetWidth * uprightHeight / uprightWidth).round().clamp(1, 1000);
    final Float32List light = Float32List(width * height);
    final Float32List person = Float32List(width * height);
    final bool hasMask =
        mask != null && mask.length >= maskWidth * maskHeight && maskWidth > 0;

    // Яркость усредняется по 2×2 точкам, чтобы шум датчика и мелкий
    // узор не попадали в тени.
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        double value = 0;
        for (int k = 0; k < 4; k++) {
          // Точка в вертикальном кадре, как его видит пользователь.
          final double fx = (x + 0.25 + (k & 1) * 0.5) / width;
          final double fy = (y + 0.25 + (k >> 1) * 0.5) / height;
          // Фронтальная камера показывает зеркало; кадр датчика — нет.
          final double ux = (mirror ? 1 - fx : fx) * uprightWidth;
          final double uy = fy * uprightHeight;
          final (int sx, int sy) = sensorPoint(
            ux, uy, rotation, frameWidth, frameHeight,
          );
          value += _luma(luma, sx, sy, bytesPerRow, bgra);
        }
        value /= 4;
        final int i = y * width + x;
        light[i] = value;
        double p = 1;
        if (hasMask) {
          final double fx = (x + 0.5) / width;
          p = _bilinear(
            mask,
            maskWidth,
            maskHeight,
            (mirror ? 1 - fx : fx) * maskWidth - 0.5,
            (y + 0.5) / height * maskHeight - 0.5,
          );
        }
        person[i] = p;
      }
    }

    // Средняя яркость вокруг каждой точки — только по человеку, чтобы
    // фон не попадал в тени. Делим на неё: остаются складки и тени,
    // а цвет своей одежды (белая футболка, тёмная кофта) не важен.
    final Float32List local = _localMean(
      light, hasMask ? person : null, width, height, (width / 7).round(),
    );
    // Мелкий рисунок своей одежды (принты, швы, полоски) размываем:
    // на новую вещь переходят только складки и тени.
    final Float32List soft = _localMean(
      light, hasMask ? person : null, width, height, (width / 40).round().clamp(1, 8),
    );

    final Uint8List rgba = Uint8List(width * height * 4);
    for (int i = 0; i < light.length; i++) {
      // Отношение к яркости вокруг: тень < 128 < блик.
      final double relative = soft[i] / local[i] - 1;
      final int shade =
          (128 + 128 * strength * relative).round().clamp(0, 255);
      // Чёткий край силуэта: внутри тела вещь полностью непрозрачна.
      final int alpha =
          hasMask ? ((person[i] - 0.42) / 0.16 * 255).round().clamp(0, 255) : 255;
      // Цвет умножен на прозрачность — так Flutter рисует пиксели.
      final int value = shade * alpha ~/ 255;
      rgba[i * 4] = value;
      rgba[i * 4 + 1] = value;
      rgba[i * 4 + 2] = value;
      rgba[i * 4 + 3] = alpha;
    }
    return BodyShading(width: width, height: height, rgba: rgba);
  }

  static double _bilinear(List<double> m, int w, int h, double x, double y) {
    final int x0 = x.floor().clamp(0, w - 1), y0 = y.floor().clamp(0, h - 1);
    final int x1 = (x0 + 1).clamp(0, w - 1), y1 = (y0 + 1).clamp(0, h - 1);
    final double tx = (x - x0).clamp(0, 1), ty = (y - y0).clamp(0, 1);
    final double top = m[y0 * w + x0] * (1 - tx) + m[y0 * w + x1] * tx;
    final double bottom = m[y1 * w + x0] * (1 - tx) + m[y1 * w + x1] * tx;
    return top * (1 - ty) + bottom * ty;
  }

  /// Среднее [values] в квадрате ±[radius] вокруг каждой точки с весами
  /// [weights] (интегральные суммы — быстро при любом радиусе).
  static Float32List _localMean(
    Float32List values,
    Float32List? weights,
    int width,
    int height,
    int radius,
  ) {
    final int stride = width + 1;
    final Float64List sumV = Float64List(stride * (height + 1));
    final Float64List sumW = Float64List(stride * (height + 1));
    for (int y = 0; y < height; y++) {
      double rowV = 0, rowW = 0;
      for (int x = 0; x < width; x++) {
        final double w = weights == null ? 1 : weights[y * width + x];
        rowV += values[y * width + x] * w;
        rowW += w;
        sumV[(y + 1) * stride + x + 1] = sumV[y * stride + x + 1] + rowV;
        sumW[(y + 1) * stride + x + 1] = sumW[y * stride + x + 1] + rowW;
      }
    }
    double box(Float64List s, int x0, int y0, int x1, int y1) =>
        s[y1 * stride + x1] - s[y0 * stride + x1] - s[y1 * stride + x0] + s[y0 * stride + x0];
    final Float32List result = Float32List(values.length);
    for (int y = 0; y < height; y++) {
      final int y0 = (y - radius).clamp(0, height), y1 = (y + radius + 1).clamp(0, height);
      for (int x = 0; x < width; x++) {
        final int x0 = (x - radius).clamp(0, width), x1 = (x + radius + 1).clamp(0, width);
        final double w = box(sumW, x0, y0, x1, y1);
        final double v = w > 0.5 ? box(sumV, x0, y0, x1, y1) / w : values[y * width + x];
        result[y * width + x] = v.clamp(8, 255);
      }
    }
    return result;
  }

  /// Точка вертикального кадра ([ux], [uy]) → пиксель кадра датчика.
  ///
  /// [rotation] — на сколько градусов кадр датчика поворачивают по
  /// часовой стрелке, чтобы он стал вертикальным.
  static (int, int) sensorPoint(
    double ux,
    double uy,
    int rotation,
    int frameWidth,
    int frameHeight,
  ) {
    final double x, y;
    switch (rotation) {
      case 90:
        // Поворот на 90° по часовой: (x, y) → (H − 1 − y, x).
        x = uy;
        y = frameHeight - 1 - ux;
      case 180:
        x = frameWidth - 1 - ux;
        y = frameHeight - 1 - uy;
      case 270:
        // Поворот на 270°: (x, y) → (y, W − 1 − x).
        x = frameWidth - 1 - uy;
        y = ux;
      default:
        x = ux;
        y = uy;
    }
    return (
      x.round().clamp(0, frameWidth - 1),
      y.round().clamp(0, frameHeight - 1),
    );
  }

  static double _luma(Uint8List data, int x, int y, int bytesPerRow, bool bgra) {
    if (!bgra) {
      final int i = y * bytesPerRow + x;
      return i < data.length ? data[i].toDouble() : 0;
    }
    final int i = y * bytesPerRow + x * 4;
    if (i + 2 >= data.length) return 0;
    return 0.114 * data[i] + 0.587 * data[i + 1] + 0.299 * data[i + 2];
  }

  /// Картинка для рисования на Canvas.
  Future<ui.Image> toImage() {
    final Completer<ui.Image> done = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgba, width, height, ui.PixelFormat.rgba8888, done.complete,
    );
    return done.future;
  }
}
