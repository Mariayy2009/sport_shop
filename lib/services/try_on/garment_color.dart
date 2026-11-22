import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Основной цвет вещи по фото товара — им красится 3D-модель
/// в живой примерке.
class GarmentColor {
  GarmentColor._();

  static const ui.Color fallback = ui.Color(0xFF2F6BFF);

  /// Сторона уменьшенной копии: цвету мелкие детали не нужны.
  static const int _side = 64;

  /// Цветных пикселей в центре кадра должно быть не меньше этой доли,
  /// иначе вещь считается белой, серой или чёрной.
  static const double _chromaticShare = 0.22;

  /// Фото каталога, на которых цвет вещи не определить автоматически:
  /// на фото тайтсов спортсменка в оранжевой футболке, форма снята
  /// крупным планом через сетку, у кимоно — дети и пояса.
  static const Map<String, ui.Color> knownPhotos = {
    'assets/images/products/running_tights.jpg': ui.Color(0xFF3A3D44),
    'assets/images/products/volleyball_uniform.jpg': ui.Color(0xFFE6EAF2),
    'assets/images/products/karate_kimono.jpg': ui.Color(0xFFF3F1EB),
    'assets/images/products/adidas_pants.jpg': ui.Color(0xFF8A9099),
    'assets/images/products/swimsuit.jpg': ui.Color(0xFF1E1F24),
    'assets/images/products/yoga_leggings.jpg': ui.Color(0xFF7B3FA8),
  };

  /// Цвет вещи для товара с фото [imageUrl] (байты фото — [bytes]).
  static Future<ui.Color> forProduct(String? imageUrl, Uint8List bytes) async =>
      knownPhotos[imageUrl] ?? await fromImage(bytes);

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
      return dominant(data.buffer.asUint8List(), _side, _side);
    } on Exception {
      return fallback;
    }
  }

  /// Цвет вещи на фото [width]×[height] (RGBA).
  ///
  /// Простое среднее не годится: жёлтая майка на чёрном фоне дала бы
  /// коричневый. Поэтому:
  /// 1. Смотрим центр кадра — вещь обычно там, фон по краям.
  /// 2. Если в центре достаточно насыщенных пикселей, строим гистограмму
  ///    оттенков и берём самый частый оттенок (фон и мелкие детали —
  ///    надписи, пояс, кожа — проигрывают).
  /// 3. Иначе вещь бесцветная: берём яркость пикселей центра, отличных
  ///    от фона по краям кадра.
  static ui.Color dominant(Uint8List rgba, int width, int height) {
    final List<_Pixel> center = [];
    final List<_Pixel> border = [];
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final int i = (y * width + x) * 4;
        if (i + 3 >= rgba.length || rgba[i + 3] < 128) continue;
        final _Pixel p = _Pixel(rgba[i], rgba[i + 1], rgba[i + 2]);
        final double fx = x / (width - 1), fy = y / (height - 1);
        if (fx > 0.2 && fx < 0.8 && fy > 0.15 && fy < 0.85) {
          center.add(p);
        } else if (fx < 0.08 || fx > 0.92 || fy < 0.06 || fy > 0.94) {
          border.add(p);
        }
      }
    }
    if (center.isEmpty) return fallback;

    final List<_Pixel> chromatic =
        center.where((p) => p.saturation > 0.28 && p.value > 0.22).toList();
    if (chromatic.length >= center.length * _chromaticShare) {
      return _byHue(chromatic);
    }
    return _achromatic(center, border);
  }

  static ui.Color _byHue(List<_Pixel> pixels) {
    const int bins = 24;
    final List<double> weight = List<double>.filled(bins, 0);
    int bin(_Pixel p) => (p.hue / 360 * bins).floor() % bins;
    for (final _Pixel p in pixels) {
      weight[bin(p)] += p.saturation * p.value;
    }
    int best = 0;
    double bestWeight = -1;
    for (int b = 0; b < bins; b++) {
      // Соседние корзины вместе: оттенок на границе не делится пополам.
      final double w =
          weight[(b + bins - 1) % bins] + weight[b] + weight[(b + 1) % bins];
      if (w > bestWeight) {
        bestWeight = w;
        best = b;
      }
    }
    final List<_Pixel> chosen = pixels.where((p) {
      final int d = (bin(p) - best).abs();
      return math.min(d, bins - d) <= 1;
    }).toList();
    // Тени на фото темнят цвет; ткань в живой примерке освещает камера,
    // поэтому берём освещённую часть вещи — светлую половину пикселей.
    chosen.sort((a, b) => b.value.compareTo(a.value));
    return _average(chosen.sublist(0, (chosen.length / 2).ceil()));
  }

  /// Бесцветная вещь (белое кимоно, чёрные тайтсы): пиксели центра,
  /// которые не похожи на фон по краям кадра.
  static ui.Color _achromatic(List<_Pixel> center, List<_Pixel> border) {
    if (border.isEmpty) return _average(center);
    final double background =
        border.map((p) => p.value).reduce((a, b) => a + b) / border.length;
    final List<_Pixel> garment =
        center.where((p) => (p.value - background).abs() > 0.15).toList();
    return _average(garment.length >= center.length * 0.15 ? garment : center);
  }

  static ui.Color _average(List<_Pixel> pixels) {
    int r = 0, g = 0, b = 0;
    for (final _Pixel p in pixels) {
      r += p.r;
      g += p.g;
      b += p.b;
    }
    final int n = pixels.length;
    return ui.Color.fromARGB(255, r ~/ n, g ~/ n, b ~/ n);
  }
}

class _Pixel {
  _Pixel(this.r, this.g, this.b) {
    final int max = math.max(r, math.max(g, b));
    final int min = math.min(r, math.min(g, b));
    value = max / 255;
    saturation = max == 0 ? 0 : (max - min) / max;
    final double d = (max - min).toDouble();
    if (d == 0) {
      hue = 0;
    } else if (max == r) {
      hue = 60 * (((g - b) / d) % 6);
    } else if (max == g) {
      hue = 60 * ((b - r) / d + 2);
    } else {
      hue = 60 * ((r - g) / d + 4);
    }
    if (hue < 0) hue += 360;
  }

  final int r, g, b;
  late final double value;
  late final double saturation;
  late final double hue;
}
