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
  BodyShading({required this.width, required this.height, required this.rgba});

  final int width;
  final int height;
  final Uint8List rgba;

  /// Ширина картинки: складкам хватает, а кадр считается за миллисекунды.
  static const int targetWidth = 120;

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
      rgba[i * 4] = shade;
      rgba[i * 4 + 1] = shade;
      rgba[i * 4 + 2] = shade;
      // Чёткий край силуэта: внутри тела вещь полностью непрозрачна.
      rgba[i * 4 + 3] =
          hasMask ? ((person[i] - 0.42) / 0.16 * 255).round().clamp(0, 255) : 255;
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
