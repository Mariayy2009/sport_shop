/// Имена всех маршрутов приложения в одном месте.
/// В экранах пишем Navigator.pushNamed(context, AppRoutes.product),
/// а не строку '/product'.
class AppRoutes {
  AppRoutes._();

  /// Оболочка с нижней навигацией: Home / Catalog / AI / Basket / Profile.
  /// Главная, каталог, AI-приветствие, корзина и профиль — её вкладки.
  static const String main = '/';

  static const String login = '/login';
  static const String registration = '/registration';

  static const String filter = '/catalog/filter';
  static const String product = '/product'; // аргумент: id товара

  static const String editProfile = '/profile/edit';

  static const String checkout = '/checkout';
  static const String orderSuccess = '/order-success'; // аргумент: id заказа
  static const String orderHistory = '/orders';
  static const String orderDetails = '/orders/details'; // аргумент: id заказа

  static const String recommendationQuiz = '/recommendation/quiz';
  static const String recommendationResult = '/recommendation/result';
}
