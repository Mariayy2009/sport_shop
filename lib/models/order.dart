import 'enums.dart';
import 'order_item.dart';

/// Заказ (таблица orders).
///
/// Поля [customerName], [phone], [deliveryAddress], [deliveryMethod]
/// добавлены к ER-схеме КР №1: они есть в макете «Оформление заказа».
/// Это «снимок» данных покупателя на момент заказа.
class Order {
  const Order({
    this.id,
    required this.userId,
    required this.status,
    required this.totalPrice,
    required this.createdAt,
    this.customerName,
    this.phone,
    this.deliveryAddress,
    this.deliveryMethod = DeliveryMethod.courier,
    this.items = const [],
    this.trackingNote,
  });

  final int? id;
  final int userId;
  final OrderStatus status;
  final double totalPrice;
  final DateTime createdAt;
  final String? customerName;
  final String? phone;
  final String? deliveryAddress;
  final DeliveryMethod deliveryMethod;

  /// Где сейчас товар — пишет продавец или магазин: «Отправлен из Алматы,
  /// привезём 27 ноября».
  final String? trackingNote;

  /// Позиции заказа — загружаются отдельным запросом к order_items.
  final List<OrderItem> items;

  int get itemsCount => items.fold(0, (sum, item) => sum + item.quantity);

  factory Order.fromMap(
    Map<String, Object?> map, {
    List<OrderItem> items = const [],
  }) {
    return Order(
      id: map['id'] as int?,
      userId: map['user_id'] as int,
      status: OrderStatus.fromValue(map['status'] as String?),
      totalPrice: (map['total_price'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
      customerName: map['customer_name'] as String?,
      phone: map['phone'] as String?,
      deliveryAddress: map['delivery_address'] as String?,
      deliveryMethod: DeliveryMethod.fromValue(map['delivery_method'] as String?),
      trackingNote: map['tracking_note'] as String?,
      items: items,
    );
  }

  /// Только поля таблицы orders; позиции сохраняются в order_items отдельно.
  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'status': status.value,
      'total_price': totalPrice,
      'created_at': createdAt.toIso8601String(),
      'customer_name': customerName,
      'phone': phone,
      'delivery_address': deliveryAddress,
      'delivery_method': deliveryMethod.value,
    };
  }

  factory Order.fromJson(Map<String, Object?> json) {
    final List<OrderItem> items = (json['items'] as List<Object?>? ?? const [])
        .map((item) => OrderItem.fromJson(item! as Map<String, Object?>))
        .toList();
    return Order.fromMap(json, items: items);
  }

  /// Для API заказ отправляется вместе с позициями.
  Map<String, Object?> toJson() {
    return {
      ...toMap(),
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  Order copyWith({
    int? id,
    OrderStatus? status,
    List<OrderItem>? items,
  }) {
    return Order(
      id: id ?? this.id,
      userId: userId,
      status: status ?? this.status,
      totalPrice: totalPrice,
      createdAt: createdAt,
      customerName: customerName,
      phone: phone,
      deliveryAddress: deliveryAddress,
      deliveryMethod: deliveryMethod,
      items: items ?? this.items,
      trackingNote: trackingNote,
    );
  }
}
