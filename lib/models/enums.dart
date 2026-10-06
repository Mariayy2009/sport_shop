/// Перечисления предметной области.
///
/// В БД (и в будущем API) хранится [value] — английский код.
/// Пользователю показывается [label] — русская подпись.
/// Так строки в БД не зависят от языка интерфейса.
library;

/// Роль пользователя.
enum UserRole {
  guest('guest', 'Гость'),
  customer('customer', 'Покупатель'),
  admin('admin', 'Администратор');

  const UserRole(this.value, this.label);

  final String value;
  final String label;

  static UserRole fromValue(String? value) {
    return UserRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => UserRole.guest,
    );
  }
}

/// Уровень подготовки (экран ии3 и таблица sport_requirements).
enum SportLevel {
  beginner('beginner', 'Новичок', 'до 1 года'),
  amateur('amateur', 'Любитель', '1–3 года'),
  experienced('experienced', 'Опытный', '3+ лет');

  const SportLevel(this.value, this.label, this.experienceHint);

  final String value;
  final String label;

  /// Подсказка под вариантом в опросе: «Новичок (до 1 года)».
  final String experienceHint;

  String get fullLabel => '$label ($experienceHint)';

  static SportLevel fromValue(String? value) {
    return SportLevel.values.firstWhere(
      (level) => level.value == value,
      orElse: () => SportLevel.beginner,
    );
  }

  /// Уровень по стажу — используется, если пользователь не выбрал уровень явно.
  static SportLevel fromExperience(int years) {
    if (years < 1) return SportLevel.beginner;
    if (years < 3) return SportLevel.amateur;
    return SportLevel.experienced;
  }
}

/// Статус заказа (чипы в истории заказов).
enum OrderStatus {
  newOrder('new', 'Новый'),
  inTransit('in_transit', 'В пути'),
  delivered('delivered', 'Доставлен');

  const OrderStatus(this.value, this.label);

  final String value;
  final String label;

  static OrderStatus fromValue(String? value) {
    return OrderStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => OrderStatus.newOrder,
    );
  }
}

/// Способ доставки (экран оформления заказа).
enum DeliveryMethod {
  courier('courier', 'Курьер'),
  pickup('pickup', 'Самовывоз');

  const DeliveryMethod(this.value, this.label);

  final String value;
  final String label;

  static DeliveryMethod fromValue(String? value) {
    return DeliveryMethod.values.firstWhere(
      (method) => method.value == value,
      orElse: () => DeliveryMethod.courier,
    );
  }
}
