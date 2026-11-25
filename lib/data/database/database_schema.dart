import '../../models/user_sizes.dart';

/// Схема базы данных: имена таблиц и SQL-команды создания.
///
/// Соответствует ER-схеме КР №1 с дополнениями из макетов Figma:
///   users.phone;
///   orders.customer_name, phone, delivery_address, delivery_method.
///
/// Значения ролей, уровней и статусов — английские коды из models/enums.dart.
class DatabaseSchema {
  DatabaseSchema._();

  static const String databaseName = 'sport_shop.db';

  /// При изменении схемы увеличить версию — база пересоздастся (см. onUpgrade).
  /// v2: добавлены cart_items (корзина) и order_items.size (размер в заказе).
  /// v3: products.brand / material / rating (сравнение товаров),
  ///     таблица favorites (избранное).
  /// v4: users.avatar_path, products.reviews_count, таблицы reviews (отзывы),
  ///     questions (вопросы о товаре), fitting_photos (фото для примерки).
  /// v5: картинки товаров в формате JPG (пересоздание демо-данных).
  /// v6: таблица exhibits («Зал славы»), products.try_on_photo.
  /// v7: exhibits.sport_label и экспонаты КНУС в демо-данных.
  /// v8: убраны таблица fitting_photos и products.try_on_photo —
  ///     старая 2D-примерка заменена AI-примеркой и живой 3D-примеркой.
  /// v9: exhibits.gallery (несколько фото), спортсмены Казахстана в «Зале
  ///     славы». Обновление с v8 — без потери данных (см. AppDatabase).
  /// v10: products.gallery (несколько фото товара) и новые товары,
  ///      в том числе варианты одного продавца. Обновление без потери данных.
  /// v11: дополнительные фото у товаров основного каталога (беговая
  ///      футболка, пояс, бинты, блок для йоги, вратарские перчатки).
  /// v12: продавцы (таблица sellers — магазин пользователя), у товара —
  ///      продавец и статус «снят с продажи», у заказа — «где товар»,
  ///      предупреждения продавцам от администратора (seller_warnings).
  /// v13: варианты товара (products.variants), фото в отзывах
  ///      (reviews.photos), примерка, отсканированная продавцом
  ///      (products.try_on_image, try_on_meta), демо-отзывы.
  /// v14: новые фото баскетбольных кроссовок (варианты), убраны первые
  ///      фото гетр и капы.
  /// v15: состав товара (products.composition), вид «Для всех видов
  ///      спорта», категория «Спортивное питание».
  /// v16: уведомления (notifications), рекорды игры (game_scores),
  ///      промокоды (coupons), отметка «покупатель подтверждён»
  ///      (reviews.verified), диета у спортпита (products.diet),
  ///      скидка в заказе (orders.discount).
  /// v17: заморозка и удаление продавцов (sellers.status, status_reason,
  ///      status_at), апелляции продавцов (seller_appeals).
  static const int version = 17;

  // Имена таблиц
  static const String sports = 'sports';
  static const String users = 'users';
  static const String userSizes = 'user_sizes';
  static const String categories = 'categories';
  static const String products = 'products';
  static const String sportRequirements = 'sport_requirements';
  static const String recommendations = 'recommendations';
  static const String orders = 'orders';
  static const String orderItems = 'order_items';
  static const String cartItems = 'cart_items';
  static const String favorites = 'favorites';
  static const String reviews = 'reviews';
  static const String questions = 'questions';
  static const String exhibits = 'exhibits';
  static const String sellers = 'sellers';
  static const String sellerWarnings = 'seller_warnings';
  static const String notifications = 'notifications';
  static const String gameScores = 'game_scores';
  static const String coupons = 'coupons';
  static const String sellerAppeals = 'seller_appeals';

  /// Порядок создания: сначала таблицы, на которые ссылаются внешние ключи.
  static const List<String> tablesInCreateOrder = [
    sports,
    users,
    userSizes,
    categories,
    products,
    sportRequirements,
    recommendations,
    orders,
    orderItems,
    cartItems,
    favorites,
    reviews,
    questions,
    exhibits,
    sellers,
    sellerWarnings,
    notifications,
    gameScores,
    coupons,
    sellerAppeals,
  ];

  /// Таблицы прежних версий: удаляются при обновлении схемы.
  static const List<String> _removedTables = ['fitting_photos'];

  static List<String> get tablesInDropOrder =>
      [..._removedTables, ...tablesInCreateOrder.reversed];

  static final String _clothingSizesSql =
      UserSizes.clothingSizes.map((size) => "'$size'").join(', ');

  /// Колонки товара про продавца и модерацию (те же — в миграции v12).
  static const String productSellerColumns = '''
      seller_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
      status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'blocked')),
      block_reason TEXT''';

  /// Магазин продавца: пользователь с записью здесь — продавец.
  static const String createSellers = '''
    CREATE TABLE $sellers (
      user_id INTEGER PRIMARY KEY,
      shop_name TEXT NOT NULL UNIQUE,
      created_at TEXT NOT NULL,
      $sellerStatusColumns,
      FOREIGN KEY (user_id) REFERENCES $users(id) ON DELETE CASCADE
    )
    ''';

  /// Статус магазина (те же колонки — в миграции v17): работает,
  /// заморожен (товары скрыты, выставлять нельзя) или удалён
  /// администратором (можно восстановить по апелляции).
  static const String sellerStatusColumns = '''
      status TEXT NOT NULL DEFAULT 'active'
        CHECK (status IN ('active', 'frozen', 'deleted')),
      status_reason TEXT,
      status_at TEXT''';

  /// Апелляции продавцов: «почему заморозили», «верните магазин».
  static const String createSellerAppeals = '''
    CREATE TABLE $sellerAppeals (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      seller_id INTEGER NOT NULL,
      text TEXT NOT NULL,
      created_at TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'accepted', 'rejected')),
      reply TEXT,
      resolved_at TEXT,
      FOREIGN KEY (seller_id) REFERENCES $users(id) ON DELETE CASCADE
    )
    ''';

  /// Предупреждения продавцам от администратора.
  static const String createSellerWarnings = '''
    CREATE TABLE $sellerWarnings (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      seller_id INTEGER NOT NULL,
      product_id INTEGER,
      reason TEXT NOT NULL,
      text TEXT,
      created_at TEXT NOT NULL,
      is_read INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY (seller_id) REFERENCES $users(id) ON DELETE CASCADE,
      FOREIGN KEY (product_id) REFERENCES $products(id) ON DELETE SET NULL
    )
    ''';

  /// Уведомления пользователю: ответ продавца, заказ в пути,
  /// продавцу — товар заканчивается.
  static const String createNotifications = '''
    CREATE TABLE $notifications (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      title TEXT NOT NULL,
      body TEXT,
      product_id INTEGER,
      order_id INTEGER,
      created_at TEXT NOT NULL,
      is_read INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY (user_id) REFERENCES $users(id) ON DELETE CASCADE,
      FOREIGN KEY (product_id) REFERENCES $products(id) ON DELETE SET NULL,
      FOREIGN KEY (order_id) REFERENCES $orders(id) ON DELETE SET NULL
    )
    ''';

  /// Результаты игры с мячом — для таблицы рекордов.
  static const String createGameScores = '''
    CREATE TABLE $gameScores (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      mode TEXT NOT NULL,
      score INTEGER NOT NULL CHECK (score >= 0),
      created_at TEXT NOT NULL,
      FOREIGN KEY (user_id) REFERENCES $users(id) ON DELETE CASCADE
    )
    ''';

  /// Промокоды покупателя (например, за рекорд в игре).
  static const String createCoupons = '''
    CREATE TABLE $coupons (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      code TEXT NOT NULL UNIQUE,
      percent INTEGER NOT NULL CHECK (percent BETWEEN 1 AND 50),
      scope TEXT,
      title TEXT NOT NULL,
      created_at TEXT NOT NULL,
      used_at TEXT,
      FOREIGN KEY (user_id) REFERENCES $users(id) ON DELETE CASCADE
    )
    ''';

  static final List<String> createStatements = [
    '''
    CREATE TABLE $sports (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE,
      description TEXT
    )
    ''',
    '''
    CREATE TABLE $users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      email TEXT NOT NULL COLLATE NOCASE UNIQUE,
      password_hash TEXT NOT NULL,
      role TEXT NOT NULL DEFAULT 'customer'
        CHECK (role IN ('guest', 'customer', 'admin')),
      first_name TEXT,
      last_name TEXT,
      phone TEXT,
      avatar_path TEXT,
      created_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE $userSizes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL UNIQUE,
      height INTEGER CHECK (height IS NULL OR height BETWEEN ${UserSizes.minHeight} AND ${UserSizes.maxHeight}),
      weight INTEGER CHECK (weight IS NULL OR weight BETWEEN ${UserSizes.minWeight} AND ${UserSizes.maxWeight}),
      clothing_size TEXT CHECK (clothing_size IS NULL OR clothing_size IN ($_clothingSizesSql)),
      shoe_size INTEGER CHECK (shoe_size IS NULL OR shoe_size BETWEEN ${UserSizes.minShoeSize} AND ${UserSizes.maxShoeSize}),
      experience_years INTEGER CHECK (experience_years IS NULL OR experience_years BETWEEN ${UserSizes.minExperience} AND ${UserSizes.maxExperience}),
      sport_id INTEGER,
      FOREIGN KEY (user_id) REFERENCES $users(id) ON DELETE CASCADE,
      FOREIGN KEY (sport_id) REFERENCES $sports(id) ON DELETE SET NULL
    )
    ''',
    '''
    CREATE TABLE $categories (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      sport_id INTEGER,
      FOREIGN KEY (sport_id) REFERENCES $sports(id) ON DELETE SET NULL
    )
    ''',
    '''
    CREATE TABLE $products (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      description TEXT,
      price REAL NOT NULL CHECK (price >= 0),
      category_id INTEGER NOT NULL,
      sport_id INTEGER NOT NULL,
      size TEXT,
      stock INTEGER NOT NULL DEFAULT 0 CHECK (stock >= 0),
      image_url TEXT,
      gallery TEXT,
      brand TEXT,
      material TEXT,
      rating REAL CHECK (rating IS NULL OR rating BETWEEN 0 AND 5),
      reviews_count INTEGER NOT NULL DEFAULT 0,
      $productSellerColumns,
      variants TEXT,
      try_on_image TEXT,
      try_on_meta TEXT,
      composition TEXT,
      diet TEXT,
      FOREIGN KEY (category_id) REFERENCES $categories(id) ON DELETE RESTRICT,
      FOREIGN KEY (sport_id) REFERENCES $sports(id) ON DELETE RESTRICT
    )
    ''',
    '''
    CREATE TABLE $sportRequirements (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      sport_id INTEGER NOT NULL,
      product_id INTEGER NOT NULL,
      level TEXT NOT NULL CHECK (level IN ('beginner', 'amateur', 'experienced')),
      is_mandatory INTEGER NOT NULL DEFAULT 1 CHECK (is_mandatory IN (0, 1)),
      UNIQUE (sport_id, product_id, level),
      FOREIGN KEY (sport_id) REFERENCES $sports(id) ON DELETE CASCADE,
      FOREIGN KEY (product_id) REFERENCES $products(id) ON DELETE CASCADE
    )
    ''',
    '''
    CREATE TABLE $recommendations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      sport_id INTEGER NOT NULL,
      min_experience INTEGER NOT NULL DEFAULT 0 CHECK (min_experience >= 0),
      product_id INTEGER NOT NULL,
      reason TEXT,
      FOREIGN KEY (sport_id) REFERENCES $sports(id) ON DELETE CASCADE,
      FOREIGN KEY (product_id) REFERENCES $products(id) ON DELETE CASCADE
    )
    ''',
    '''
    CREATE TABLE $orders (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      status TEXT NOT NULL DEFAULT 'new'
        CHECK (status IN ('new', 'in_transit', 'delivered')),
      total_price REAL NOT NULL CHECK (total_price >= 0),
      created_at TEXT NOT NULL,
      customer_name TEXT,
      phone TEXT,
      delivery_address TEXT,
      delivery_method TEXT NOT NULL DEFAULT 'courier'
        CHECK (delivery_method IN ('courier', 'pickup')),
      tracking_note TEXT,
      discount REAL NOT NULL DEFAULT 0,
      FOREIGN KEY (user_id) REFERENCES $users(id) ON DELETE RESTRICT
    )
    ''',
    '''
    CREATE TABLE $orderItems (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      order_id INTEGER NOT NULL,
      product_id INTEGER NOT NULL,
      quantity INTEGER NOT NULL CHECK (quantity > 0),
      price REAL NOT NULL CHECK (price >= 0),
      size TEXT,
      FOREIGN KEY (order_id) REFERENCES $orders(id) ON DELETE CASCADE,
      FOREIGN KEY (product_id) REFERENCES $products(id) ON DELETE RESTRICT
    )
    ''',
    '''
    CREATE TABLE $cartItems (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      product_id INTEGER NOT NULL,
      size TEXT,
      quantity INTEGER NOT NULL CHECK (quantity > 0),
      FOREIGN KEY (user_id) REFERENCES $users(id) ON DELETE CASCADE,
      FOREIGN KEY (product_id) REFERENCES $products(id) ON DELETE CASCADE
    )
    ''',
    '''
    CREATE TABLE $favorites (
      user_id INTEGER NOT NULL,
      product_id INTEGER NOT NULL,
      created_at TEXT NOT NULL,
      PRIMARY KEY (user_id, product_id),
      FOREIGN KEY (user_id) REFERENCES $users(id) ON DELETE CASCADE,
      FOREIGN KEY (product_id) REFERENCES $products(id) ON DELETE CASCADE
    )
    ''',
    '''
    CREATE TABLE $reviews (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      product_id INTEGER NOT NULL,
      rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
      text TEXT,
      photos TEXT,
      verified INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      UNIQUE (user_id, product_id),
      FOREIGN KEY (user_id) REFERENCES $users(id) ON DELETE CASCADE,
      FOREIGN KEY (product_id) REFERENCES $products(id) ON DELETE CASCADE
    )
    ''',
    '''
    CREATE TABLE $questions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      product_id INTEGER NOT NULL,
      user_id INTEGER NOT NULL,
      text TEXT NOT NULL,
      created_at TEXT NOT NULL,
      answer TEXT,
      answered_at TEXT,
      FOREIGN KEY (user_id) REFERENCES $users(id) ON DELETE CASCADE,
      FOREIGN KEY (product_id) REFERENCES $products(id) ON DELETE CASCADE
    )
    ''',
    '''
    CREATE TABLE $exhibits (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      athlete TEXT NOT NULL,
      sport_id INTEGER,
      sport_label TEXT,
      year TEXT,
      story TEXT,
      image_url TEXT,
      gallery TEXT,
      source TEXT NOT NULL DEFAULT 'knus'
        CHECK (source IN ('knus', 'kazakhstan')),
      created_at TEXT NOT NULL,
      FOREIGN KEY (sport_id) REFERENCES $sports(id) ON DELETE SET NULL
    )
    ''',
    createSellers,
    createSellerWarnings,
    createNotifications,
    createGameScores,
    createCoupons,
    createSellerAppeals,
    // Индексы для частых выборок: каталог, подбор, история заказов
    'CREATE INDEX idx_products_sport ON $products(sport_id)',
    'CREATE INDEX idx_products_category ON $products(category_id)',
    'CREATE INDEX idx_requirements_sport_level ON $sportRequirements(sport_id, level)',
    'CREATE INDEX idx_recommendations_sport ON $recommendations(sport_id)',
    'CREATE INDEX idx_orders_user ON $orders(user_id)',
    'CREATE INDEX idx_order_items_order ON $orderItems(order_id)',
    'CREATE INDEX idx_cart_items_user ON $cartItems(user_id)',
    'CREATE INDEX idx_reviews_product ON $reviews(product_id)',
    'CREATE INDEX idx_questions_product ON $questions(product_id)',
  ];
}
