import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';
import '../data/repositories/order_repository.dart';
import '../models/cart_item.dart';
import '../models/coupon.dart';
import '../models/enums.dart';
import '../models/order.dart';
import '../models/order_item.dart';

/// История заказов и оформление нового заказа.
class OrderState extends ChangeNotifier {
  OrderState(this._repository);

  final OrderRepository _repository;

  int? _userId;
  List<Order> _orders = [];
  bool _isLoading = false;
  bool _isPlacing = false;
  String? _error;

  List<Order> get orders => _orders;
  bool get isLoading => _isLoading;
  bool get isPlacing => _isPlacing;
  String? get error => _error;

  static double deliveryPrice(DeliveryMethod method) =>
      method == DeliveryMethod.courier
          ? AppConstants.courierDeliveryPrice
          : AppConstants.pickupDeliveryPrice;

  Future<void> setUser(int? userId) async {
    if (userId == _userId) return;
    _userId = userId;
    _orders = [];
    notifyListeners();
  }

  Future<void> load() async {
    final int? userId = _userId;
    if (userId == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      _orders = await _repository.getOrdersByUser(userId);
      _error = null;
    } catch (error) {
      debugPrint('Ошибка загрузки заказов: $error');
      _error = 'Не удалось загрузить заказы';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Order?> getOrder(int orderId) => _repository.getOrderById(orderId);

  /// Скидка по промокоду: процент от товаров, на которые он действует
  /// (у промокода за игру — только мячи), с округлением до тенге.
  static double discountFor(List<CartItem> items, Coupon? coupon) {
    if (coupon == null) return 0;
    final double base = items
        .where((item) => coupon.appliesTo(item.product.name))
        .fold(0, (sum, item) => sum + item.total);
    return (base * coupon.percent / 100).roundToDouble();
  }

  Future<Order> placeOrder({
    required int userId,
    required List<CartItem> items,
    required String customerName,
    required String phone,
    required DeliveryMethod deliveryMethod,
    String? address,
    Coupon? coupon,
  }) async {
    if (items.isEmpty) throw const AppException('Корзина пуста');

    _isPlacing = true;
    notifyListeners();
    try {
      final double itemsTotal = items.fold(0, (sum, item) => sum + item.total);
      final double discount = discountFor(items, coupon);
      final Order order = Order(
        userId: userId,
        status: OrderStatus.newOrder,
        totalPrice: itemsTotal - discount + deliveryPrice(deliveryMethod),
        discount: discount,
        createdAt: DateTime.now(),
        customerName: customerName.trim(),
        phone: phone.trim(),
        deliveryAddress:
            deliveryMethod == DeliveryMethod.courier ? address?.trim() : null,
        deliveryMethod: deliveryMethod,
        items: [
          for (final CartItem item in items)
            OrderItem(
              productId: item.product.id!,
              quantity: item.quantity,
              price: item.product.price,
              size: item.selectedSize,
              productName: item.product.name,
              productImageUrl: item.product.imageUrl,
            ),
        ],
      );
      final Order saved = await _repository.createOrder(order);
      _orders = [saved, ..._orders];
      return saved;
    } finally {
      _isPlacing = false;
      notifyListeners();
    }
  }
}
