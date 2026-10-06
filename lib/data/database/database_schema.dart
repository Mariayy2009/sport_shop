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
  static const int version = 2;

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
  ];

  static List<String> get tablesInDropOrder =>
      tablesInCreateOrder.reversed.toList();

  static final String _clothingSizesSql =
      UserSizes.clothingSizes.map((size) => "'$size'").join(', ');

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
    // Индексы для частых выборок: каталог, подбор, история заказов
    'CREATE INDEX idx_products_sport ON $products(sport_id)',
    'CREATE INDEX idx_products_category ON $products(category_id)',
    'CREATE INDEX idx_requirements_sport_level ON $sportRequirements(sport_id, level)',
    'CREATE INDEX idx_recommendations_sport ON $recommendations(sport_id)',
    'CREATE INDEX idx_orders_user ON $orders(user_id)',
    'CREATE INDEX idx_order_items_order ON $orderItems(order_id)',
    'CREATE INDEX idx_cart_items_user ON $cartItems(user_id)',
  ];
}
