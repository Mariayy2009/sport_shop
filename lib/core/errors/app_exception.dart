/// Ошибка, понятная пользователю.
///
/// Сервисы и источники данных бросают AppException с готовым
/// русским сообщением, экраны показывают его как есть.
class AppException implements Exception {
  const AppException(this.message, {this.field});

  final String message;

  /// Поле формы, к которому относится ошибка ('email', 'password').
  /// Позволяет показать текст прямо под нужным полем.
  final String? field;

  @override
  String toString() => message;
}
