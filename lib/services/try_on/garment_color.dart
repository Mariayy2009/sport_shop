import 'dart:typed_data';
import 'dart:ui' as ui;

/// Основной цвет вещи по фото товара — им красится 3D-модель
/// в живой примерке.
class GarmentColor {
  GarmentColor._();

  static const ui.Color fallback = ui.Color(0xFF2F6BFF);

  /// Сторона уменьшенной копии: цвету мелкие детали не нужны.
  static const int _side = 48;

  static Future<ui.Color> fromImage(Uint8List bytes) async {
    try {
      final ui.Codec codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: _side,
        targetHeight: _side,
      );
      final ui.Image image = (await codec.getNextFrame()).image;
      final ByteData? data =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      if (data == null) return fallback;
      return dominant(data.buffer.asUint8List());
    } on Exception {
      return fallback;
    }
  }

  /// Средний цвет пикселей вещи. Почти белые и почти чёрные края
  /// считаются фоном, если кроме них есть что усреднять.
  static ui.Color dominant(Uint8List rgba) {
    int r = 0, g = 0, b = 0, count = 0;
    int allR = 0, allG = 0, allB = 0, all = 0;
    for (int i = 0; i + 3 < rgba.length; i += 4) {
      if (rgba[i + 3] < 128) continue;
      final int pr = rgba[i], pg = rgba[i + 1], pb = rgba[i + 2];
      allR += pr;
      allG += pg;
      allB += pb;
      all++;
      final int max = [pr, pg, pb].reduce((a, c) => a > c ? a : c);
      final int min = [pr, pg, pb].reduce((a, c) => a < c ? a : c);
      // Фон каталожного фото — светлый и бесцветный.
      if (min > 215 && max - min < 28) continue;
      r += pr;
      g += pg;
      b += pb;
      count++;
    }
    if (all == 0) return fallback;
    // Вещь занимает слишком мало кадра (или она сама белая) — берём всё.
    if (count < all * 0.08) {
      return ui.Color.fromARGB(255, allR ~/ all, allG ~/ all, allB ~/ all);
    }
    return ui.Color.fromARGB(255, r ~/ count, g ~/ count, b ~/ count);
  }
}
