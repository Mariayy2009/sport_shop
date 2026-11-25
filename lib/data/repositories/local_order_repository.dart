import '../../models/enums.dart';
import '../../models/order.dart';
import '../datasources/local/order_local_datasource.dart';
import 'order_repository.dart';

class LocalOrderRepository implements OrderRepository {
  LocalOrderRepository(this._dataSource);

  final OrderLocalDataSource _dataSource;

  @override
  Future<Order> createOrder(Order order) => _dataSource.createOrder(order);

  @override
  Future<List<Order>> getOrdersByUser(int userId) =>
      _dataSource.getOrdersByUser(userId);

  @override
  Future<Order?> getOrderById(int orderId) => _dataSource.getOrderById(orderId);

  @override
  Future<List<Order>> getAllOrders() => _dataSource.getAllOrders();

  @override
  Future<void> updateStatus(int orderId, OrderStatus status) =>
      _dataSource.updateStatus(orderId, status);

  @override
  Future<List<Order>> getOrdersForSeller(int sellerId) =>
      _dataSource.getOrdersForSeller(sellerId);

  @override
  Future<SellerStats> sellerStats(int sellerId) => _dataSource.sellerStats(sellerId);

  @override
  Future<void> updateTracking(int orderId, String? note) =>
      _dataSource.updateTracking(orderId, note);
}
