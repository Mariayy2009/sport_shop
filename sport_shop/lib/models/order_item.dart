/// Позиция заказа (таблица order_items).
class OrderItem {
  const OrderItem({
    this.id,
    this.orderId,
    required this.productId,
    required this.quantity,
    required this.price,
    this.productName,
    this.productImageUrl,
  });

  final int? id;

  /// null, пока заказ ещё не сохранён (id появится после INSERT в orders).
  final int? orderId;
  final int productId;
  final int quantity;

  /// Цена на момент заказа — не меняется, даже если товар подорожает.
  final double price;

  // Заполняются через JOIN с products.
  final String? productName;
  final String? productImageUrl;

  double get total => price * quantity;

  factory OrderItem.fromMap(Map<String, Object?> map) {
    return OrderItem(
      id: map['id'] as int?,
      orderId: map['order_id'] as int?,
      productId: map['product_id'] as int,
      quantity: map['quantity'] as int,
      price: (map['price'] as num).toDouble(),
      productName: map['product_name'] as String?,
      productImageUrl: map['product_image_url'] as String?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'order_id': orderId,
      'product_id': productId,
      'quantity': quantity,
      'price': price,
    };
  }

  factory OrderItem.fromJson(Map<String, Object?> json) =>
      OrderItem.fromMap(json);

  Map<String, Object?> toJson() => toMap();

  OrderItem copyWith({int? id, int? orderId}) {
    return OrderItem(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      productId: productId,
      quantity: quantity,
      price: price,
      productName: productName,
      productImageUrl: productImageUrl,
    );
  }
}
