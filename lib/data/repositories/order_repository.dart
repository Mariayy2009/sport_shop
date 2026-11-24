import '../../models/enums.dart';
import '../../models/order.dart';

/// Контракт работы с заказами.
abstract class OrderRepository {
  /// Сохраняет заказ с позициями и возвращает его с присвоенным номером.
  Future<Order> createOrder(Order order);

  Future<List<Order>> getOrdersByUser(int userId);

  Future<Order?> getOrderById(int orderId);

  // Для будущей административной части
  Future<List<Order>> getAllOrders();

  Future<void> updateStatus(int orderId, OrderStatus status);

  /// Заказы с товарами продавца — для кабинета продавца.
  Future<List<Order>> getOrdersForSeller(int sellerId);

  /// «Где товар» — пишет продавец или магазин. null — убрать.
  Future<void> updateTracking(int orderId, String? note);
}
