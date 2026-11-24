import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:flutter/services.dart' show rootBundle;

import '../../models/product.dart';
import '../../models/shopping_preferences.dart';
import '../try_on/garment_color.dart';
import 'style_catalog.dart';

/// Товар, подобранный по анкете, и почему.
class PreferenceMatch {
  const PreferenceMatch({
    required this.product,
    required this.score,
    required this.reasons,
    required this.forPosition,
    required this.inColor,
    required this.inMaterial,
  });

  final Product product;
  final int score;

  /// Короткие причины для карточки: «Либеро: колени нужно защитить».
  final List<String> reasons;
  final bool forPosition;
  final bool inColor;
  final bool inMaterial;
}

/// Подбор по анкете: обычные правила, без нейросети — работает
/// мгновенно и одинаково объясняет выбор. Нейросеть — только
/// в ИИ-помощнике; ей анкета передаётся как часть профиля.
class PreferenceMatcher {
  const PreferenceMatcher();

  // Вес признаков: нужное для позиции важнее цвета, цвет — материала.
  static const int positionWeight = 5;
  static const int colorWeight = 3;
  static const int materialWeight = 2;
  static const int sportWeight = 1;

  /// Название цвета из [StyleCatalog.colors] для цвета вещи.
  static String colorKeyOf(Color color) {
    final double r = color.r, g = color.g, b = color.b;
    final double max = math.max(r, math.max(g, b));
    final double min = math.min(r, math.min(g, b));
    final double v = max, s = max == 0 ? 0 : (max - min) / max;
    if (s < 0.18) {
      if (v > 0.8) return 'white';
      if (v < 0.28) return 'black';
      return 'gray';
    }
    if (v < 0.2) return 'black';
    final double d = max - min;
    double h;
    if (max == r) {
      h = 60 * (((g - b) / d) % 6);
    } else if (max == g) {
      h = 60 * ((b - r) / d + 2);
    } else {
      h = 60 * ((r - g) / d + 4);
    }
    if (h < 0) h += 360;
    if (h < 15 || h >= 345) return v < 0.45 ? 'brown' : 'red';
    if (h < 40) return v < 0.6 ? 'brown' : 'orange';
    if (h < 68) return 'yellow';
    if (h < 165) return 'green';
    if (h < 200) return 'lightblue';
    if (h < 255) return 'blue';
    if (h < 290) return 'purple';
    return 'pink';
  }

  static final Map<String, String> _colorCache = {};

  /// Цвет каждого товара (ключ из каталога цветов) по его фото.
  /// Считается один раз и запоминается.
  static Future<Map<int, String>> colorsOf(List<Product> products) async {
    Future<MapEntry<int, String>?> one(Product product) async {
      final String? url = product.imageUrl;
      if (product.id == null || url == null || url.isEmpty) return null;
      String? key = _colorCache[url];
      if (key == null) {
        try {
          final Uint8List bytes = url.startsWith('assets/')
              ? (await rootBundle.load(url)).buffer.asUint8List()
              : await File(url).readAsBytes();
          key = colorKeyOf(await GarmentColor.forProduct(url, bytes));
          _colorCache[url] = key;
        } on Exception {
          return null;
        }
      }
      return MapEntry(product.id!, key);
    }

    // Фото декодируются параллельно — так подбор открывается быстрее.
    final List<MapEntry<int, String>?> entries =
        await Future.wait(products.map(one));
    return Map.fromEntries(entries.whereType<MapEntry<int, String>>());
  }

  /// Товары каталога, подходящие анкете, — лучшие первыми.
  /// [sportName] и [sportId] — вид спорта из профиля; [colors] — цвета
  /// товаров из [colorsOf].
  List<PreferenceMatch> rank(
    List<Product> catalog,
    ShoppingPreferences preferences, {
    int? sportId,
    String? sportName,
    Map<int, String> colors = const {},
  }) {
    final SportPosition? position =
        StyleCatalog.position(sportName, preferences.position);
    final List<PreferenceMatch> matches = [];
    for (final Product product in catalog) {
      if (!product.isAvailable) continue;
      int score = 0;
      final List<String> reasons = [];

      bool forPosition = false;
      if (position != null) {
        for (final PositionNeed need in position.needs) {
          if (need.matches(product.name)) {
            forPosition = true;
            score += positionWeight;
            reasons.add('${position.title}: ${_lower(need.reason)}');
            break;
          }
        }
      }

      final String? color = colors[product.id];
      final bool inColor =
          color != null && preferences.colors.contains(color);
      if (inColor) {
        score += colorWeight;
        reasons.add('В любимом цвете: '
            '${StyleCatalog.colorByKey(color)!.name.toLowerCase()}');
      }

      final String material = product.material?.toLowerCase() ?? '';
      MaterialChoice? liked;
      for (final String key in preferences.materials) {
        final MaterialChoice? choice = StyleCatalog.materialByKey(key);
        if (choice != null && choice.keywords.any(material.contains)) {
          liked = choice;
          break;
        }
      }
      if (liked != null) {
        score += materialWeight;
        reasons.add('${liked.name}: ${_lower(liked.hint)}');
      }

      if (sportId != null && product.sportId == sportId) score += sportWeight;
      // Совпал только вид спорта — это ещё не «по анкете».
      if (!forPosition && !inColor && liked == null) continue;

      matches.add(PreferenceMatch(
        product: product,
        score: score,
        reasons: reasons,
        forPosition: forPosition,
        inColor: inColor,
        inMaterial: liked != null,
      ));
    }
    matches.sort((a, b) {
      final int byScore = b.score.compareTo(a.score);
      return byScore != 0
          ? byScore
          : (b.product.rating ?? 0).compareTo(a.product.rating ?? 0);
    });
    return matches;
  }

  static String _lower(String text) =>
      text.isEmpty ? text : text[0].toLowerCase() + text.substring(1);
}
