import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Вырезанное изображение: пиксели RGBA и размер.
class CutoutPixels {
  const CutoutPixels(this.rgba, this.width, this.height);

  final Uint8List rgba;
  final int width;
  final int height;
}

/// Убирает однотонный светлый фон с фото товара, чтобы вещь можно было
/// «надеть» в примерочной. Работает на устройстве, без интернета.
///
/// Подходит для каталожных фото: вещь целиком на белом или светло-сером
/// фоне. Если фон пёстрый, вырезать нечего — возвращается null,
/// и примерочная рисует вещь сама.
class CutoutService {
  CutoutService();

  /// Сторона, до которой уменьшается фото: для примерки этого хватает,
  /// а обработка занимает доли секунды.
  static const int _maxSide = 480;

  final Map<String, Future<ui.Image?>> _cache = {};

  /// Вырезанная вещь для товара с таким фото (результат кешируется).
  Future<ui.Image?> cutout(String imageUrl) =>
      _cache.putIfAbsent(imageUrl, () => _build(imageUrl));

  Future<ui.Image?> _build(String imageUrl) async {
    try {
      final Uint8List bytes = imageUrl.startsWith('assets/')
          ? (await rootBundle.load(imageUrl)).buffer.asUint8List()
          : await File(imageUrl).readAsBytes();
      final ui.Codec codec =
          await ui.instantiateImageCodec(bytes, targetWidth: _maxSide);
      final ui.Image source = (await codec.getNextFrame()).image;
      final ByteData? raw =
          await source.toByteData(format: ui.ImageByteFormat.rawRgba);
      final int width = source.width;
      final int height = source.height;
      source.dispose();
      if (raw == null) return null;

      final CutoutPixels? result =
          removeBackground(raw.buffer.asUint8List(), width, height);
      if (result == null) return null;

      final Completer<ui.Image> completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        result.rgba,
        result.width,
        result.height,
        ui.PixelFormat.rgba8888,
        completer.complete,
      );
      return await completer.future;
    } on Exception catch (error) {
      debugPrint('Не удалось вырезать фото товара: $error');
      return null;
    }
  }

  /// Удаляет фон заливкой от краёв кадра и обрезает картинку по вещи.
  ///
  /// [rgba] — пиксели по 4 байта. null — фон не однотонный и светлый
  /// либо вещь занимает слишком мало или слишком много кадра.
  @visibleForTesting
  static CutoutPixels? removeBackground(
    Uint8List rgba,
    int width,
    int height, {
    int tolerance = 34,
  }) {
    int offset(int x, int y) => (y * width + x) * 4;

    // Цвет фона — среднее по углам; углы должны быть похожи друг на друга.
    final List<int> corners = [
      offset(1, 1),
      offset(width - 2, 1),
      offset(1, height - 2),
      offset(width - 2, height - 2),
    ];
    int r = 0, g = 0, b = 0;
    for (final int corner in corners) {
      r += rgba[corner];
      g += rgba[corner + 1];
      b += rgba[corner + 2];
    }
    r ~/= 4;
    g ~/= 4;
    b ~/= 4;

    bool isBackground(int index, int limit) =>
        (rgba[index] - r).abs() <= limit &&
        (rgba[index + 1] - g).abs() <= limit &&
        (rgba[index + 2] - b).abs() <= limit;

    final bool uniform = corners.every((corner) => isBackground(corner, tolerance));
    final bool light = r + g + b > 3 * 185;
    if (!uniform || !light) return null;

    // Заливка от границ: фоном становится только то, что связано с краем,
    // поэтому белые детали внутри вещи (полосы, логотип) остаются.
    final Uint8List removed = Uint8List(width * height);
    final List<int> queue = [];
    void visit(int x, int y) {
      final int pixel = y * width + x;
      if (removed[pixel] == 1 || !isBackground(pixel * 4, tolerance)) return;
      removed[pixel] = 1;
      queue.add(pixel);
    }

    for (int x = 0; x < width; x++) {
      visit(x, 0);
      visit(x, height - 1);
    }
    for (int y = 0; y < height; y++) {
      visit(0, y);
      visit(width - 1, y);
    }
    for (int head = 0; head < queue.length; head++) {
      final int pixel = queue[head];
      final int x = pixel % width;
      final int y = pixel ~/ width;
      if (x > 0) visit(x - 1, y);
      if (x < width - 1) visit(x + 1, y);
      if (y > 0) visit(x, y - 1);
      if (y < height - 1) visit(x, y + 1);
    }

    // Границы вещи.
    int left = width, top = height, right = -1, bottom = -1;
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (removed[y * width + x] == 1) continue;
        if (x < left) left = x;
        if (x > right) right = x;
        if (y < top) top = y;
        if (y > bottom) bottom = y;
      }
    }
    if (right < left || bottom < top) return null;
    final int outWidth = right - left + 1;
    final int outHeight = bottom - top + 1;
    final double share = (width * height - queue.length) / (width * height);
    // Вещь — не весь кадр и не пара пикселей.
    if (share < 0.03 || share > 0.97) return null;

    final Uint8List out = Uint8List(outWidth * outHeight * 4);
    for (int y = 0; y < outHeight; y++) {
      for (int x = 0; x < outWidth; x++) {
        final int sx = x + left;
        final int sy = y + top;
        final int source = offset(sx, sy);
        final int target = (y * outWidth + x) * 4;
        if (removed[sy * width + sx] == 1) continue; // прозрачный пиксель
        // Пиксели на самой кромке полупрозрачные — край без «лесенки».
        final bool onEdge = (sx > 0 && removed[sy * width + sx - 1] == 1) ||
            (sx < width - 1 && removed[sy * width + sx + 1] == 1) ||
            (sy > 0 && removed[(sy - 1) * width + sx] == 1) ||
            (sy < height - 1 && removed[(sy + 1) * width + sx] == 1);
        final int alpha = onEdge ? 150 : 255;
        // Формат rgba8888 ожидает цвет, уже умноженный на прозрачность.
        out[target] = rgba[source] * alpha ~/ 255;
        out[target + 1] = rgba[source + 1] * alpha ~/ 255;
        out[target + 2] = rgba[source + 2] * alpha ~/ 255;
        out[target + 3] = alpha;
      }
    }
    return CutoutPixels(out, outWidth, outHeight);
  }
}
