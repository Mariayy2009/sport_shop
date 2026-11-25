import 'dart:ui';

import '../../models/product.dart';

/// Кимоно — это куртка, штаны и пояс. В живой примерке надеваются
/// все три: куртка — по фото или 3D-модели, штаны — 3D-моделью того же
/// цвета, пояс — полосой на талии цвета пояса с фото товара.
class KimonoOutfit {
  const KimonoOutfit({this.belt, this.photoHasPants = false, this.photoUsable = true});

  /// Цвет пояса на фото товара. null — пояса на фото нет.
  final Color? belt;

  /// На фото кимоно надето целиком (куртка и штаны одной вещью) —
  /// штаны уже есть в вырезанном фото, 3D-штаны не нужны.
  final bool photoHasPants;

  /// Фото можно вырезать как одну вещь. Нельзя, если куртка и штаны
  /// лежат рядом (вырезалась бы «вещь» шириной в две).
  final bool photoUsable;

  static bool isKimono(Product product) =>
      product.name.toLowerCase().contains('кимоно');

  /// Что изображено на фото товаров магазина.
  static const Map<String, KimonoOutfit> _photos = {
    'assets/images/products/karate_kimono.jpg':
        KimonoOutfit(belt: Color(0xFFE5671B), photoUsable: false),
    'assets/images/products/kimono_classic.jpg':
        KimonoOutfit(belt: Color(0xFF151515), photoHasPants: true),
    'assets/images/products/kimono_kyokushin.jpg':
        KimonoOutfit(belt: Color(0xFFF4F4F2), photoUsable: false),
  };

  /// Кимоно от продавца без описания — с белым поясом, как продаются
  /// кимоно для начинающих.
  static KimonoOutfit of(Product product) =>
      _photos[product.imageUrl] ?? const KimonoOutfit(belt: Color(0xFFF4F4F2));
}
