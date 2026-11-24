import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sport_shop/services/try_on/garment_cutout.dart';
import 'package:sport_shop/widgets/size_fit.dart';

/// Фото 100×100: белый фон, в центре «футболка» — синий прямоугольник.
Uint8List photo({int bg = 250}) {
  final Uint8List rgba = Uint8List(100 * 100 * 4);
  for (int y = 0; y < 100; y++) {
    for (int x = 0; x < 100; x++) {
      final bool shirt = x >= 30 && x < 70 && y >= 20 && y < 80;
      rgba.setAll((y * 100 + x) * 4,
          shirt ? const [30, 60, 200, 255] : [bg, bg, bg, 255]);
    }
  }
  return rgba;
}

void main() {
  test('фон убирается, вещь и плечи измеряются', () {
    final CutoutMask mask = GarmentCutout.cut(photo(), 100, 100, isBottom: false)!;
    expect(mask.bounds.left, 30);
    expect(mask.bounds.width, 40);
    expect(mask.topSpan, 40);
    // Фон прозрачный и без цвета, вещь непрозрачная.
    expect(mask.rgba.sublist(0, 4), [0, 0, 0, 0]);
    expect(mask.rgba[(50 * 100 + 50) * 4 + 3], 255);
  });

  test('вещь на весь кадр — вырезать нельзя', () {
    final Uint8List full = Uint8List(100 * 100 * 4)..fillRange(0, 40000, 120);
    expect(GarmentCutout.cut(full, 100, 100, isBottom: false), isNull);
  });

  test('размер: больше рекомендуемого — вещь крупнее', () {
    const List<String> sizes = ['XS', 'S', 'M', 'L', 'XL'];
    expect(SizeFit.scale(sizes, 'M', 'M'), 1);
    expect(SizeFit.scale(sizes, 'XL', 'M'), closeTo(1.2, 1e-9));
    expect(SizeFit.scale(sizes, 'S', 'M'), closeTo(0.9, 1e-9));
    // Без размера в профиле — относительно среднего.
    expect(SizeFit.scale(sizes, 'XS', null), closeTo(0.8, 1e-9));
    expect(SizeFit.describe(sizes, 'XL', 'M'), 'велико');
    expect(SizeFit.describe(sizes, 'L', 'M'), 'свободно');
    expect(SizeFit.describe(sizes, 'S', 'M'), 'в обтяжку');
  });
}
