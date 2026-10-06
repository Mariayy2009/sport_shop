import 'product.dart';

/// Позиция корзины (таблица cart_items + данные товара).
class CartItem {
  const CartItem({
    required this.product,
    this.quantity = 1,
    this.selectedSize,
  });

  final Product product;
  final int quantity;
  final String? selectedSize;

  double get total => product.price * quantity;

  /// Нельзя положить в корзину больше, чем есть на складе.
  bool get canIncrease => quantity < product.stock;

  bool get canDecrease => quantity > 1;

  CartItem copyWith({int? quantity, String? selectedSize}) {
    return CartItem(
      product: product,
      quantity: quantity ?? this.quantity,
      selectedSize: selectedSize ?? this.selectedSize,
    );
  }
}
