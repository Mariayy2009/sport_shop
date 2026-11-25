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

  /// Продажи товаров продавца: штуки, выручка, самый популярный товар.
  Future<SellerStats> sellerStats(int sellerId);
}

/// Статистика продавца для вкладки «Статистика».
class SellerStats {
  const SellerStats({
    required this.orders,
    required this.sold,
    required this.revenue,
    required this.monthSold,
    required this.monthRevenue,
    this.topProduct,
    this.topSold = 0,
    this.top = const [],
  });

  /// Заказов, в которых есть товары продавца.
  final int orders;
  final int sold;
  final double revenue;

  /// За текущий месяц.
  final int monthSold;
  final double monthRevenue;
  final String? topProduct;
  final int topSold;

  /// Лучшие товары: название → продано штук.
  final List<(String, int, double)> top;
}
