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
  static const String product = '/product'; // аргумент: id товара или ProductArgs

  static const String editProfile = '/profile/edit';

  static const String checkout = '/checkout';
  static const String orderSuccess = '/order-success'; // аргумент: id заказа
  static const String orderHistory = '/orders';
  static const String orderDetails = '/orders/details'; // аргумент: id заказа

  static const String recommendationQuiz = '/recommendation/quiz';
  static const String recommendationResult = '/recommendation/result';

  static const String kits = '/kits'; // аргумент: id вида спорта (необязателен)
  static const String compare = '/compare';
  static const String hallOfFame = '/hall-of-fame';
  static const String preferences = '/profile/preferences';
  static const String seller = '/seller';
  static const String shop = '/shop'; // аргумент: ShopArgs
  static const String legal = '/legal'; // аргумент: LegalDoc
  static const String sellerVerification = '/seller/verification'; // аргумент: true — открыть магазин
  static const String notifications = '/profile/notifications';
  static const String preferenceResults = '/recommendation/preferences';
  static const String ballGame = '/game/ball'; // аргумент: BallGameMode (необязателен)
  static const String exhibit = '/hall-of-fame/exhibit'; // аргумент: id экспоната
  static const String adminExhibit = '/admin/exhibit'; // аргумент: экспонат (null — новый)
  static const String admin = '/admin';
  static const String adminProduct = '/admin/product'; // аргумент: товар (null — новый)
  static const String favorites = '/favorites';
  /// Примерочная: выбор «по фотографии» или «живая». Аргумент: id товара.
  static const String tryOn = '/try-on';
  static const String photoTryOn = '/try-on/photo'; // аргумент: id товара
  static const String liveTryOn = '/try-on/live'; // аргумент: id товара
}

/// Открыть товар сразу на нужном варианте (цвете, модели) — из карточки
/// варианта в каталоге.
class ProductArgs {
  const ProductArgs(this.id, {this.variant});

  final int id;
  final String? variant;
}

/// Магазин продавца: [sellerId] null — товары самого магазина SPORT.
class ShopArgs {
  const ShopArgs(this.sellerId, this.name);

  final int? sellerId;
  final String name;
}
