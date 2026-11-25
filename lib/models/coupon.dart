/// Промокод покупателя: скидка в процентах на товары [scope].
class Coupon {
  const Coupon({
    required this.id,
    required this.code,
    required this.percent,
    this.scope,
    required this.title,
    this.usedAt,
  });

  /// Скидка только на мячи (слово «мяч» в названии товара).
  static const String scopeBalls = 'balls';

  final int id;
  final String code;
  final int percent;
  final String? scope;
  final String title;
  final DateTime? usedAt;

  bool get isUsed => usedAt != null;

  /// На какие товары действует.
  bool appliesTo(String productName) =>
      scope != scopeBalls || productName.toLowerCase().contains('мяч');

  String get scopeLabel => scope == scopeBalls ? 'на мячи' : 'на весь заказ';

  factory Coupon.fromMap(Map<String, Object?> map) => Coupon(
        id: map['id']! as int,
        code: map['code']! as String,
        percent: map['percent']! as int,
        scope: map['scope'] as String?,
        title: map['title']! as String,
        usedAt: map['used_at'] == null
            ? null
            : DateTime.parse(map['used_at']! as String),
      );
}
