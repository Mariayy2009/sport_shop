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
}
