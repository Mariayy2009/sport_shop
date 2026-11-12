/// Тексты интерфейса в одном месте.
/// Весь интерфейс на русском; подписи меняются только здесь.
class AppStrings {
  AppStrings._();

  static const String appName = 'SPORT';
  static const String currency = '₸';

  // Подписи нижней навигации
  static const String navHome = 'Главная';
  static const String navCatalog = 'Каталог';
  static const String navAi = 'Помощник';
  static const String navBasket = 'Корзина';
  static const String navProfile = 'Профиль';

  // Вход
  static const String loginTitle = 'Вход';
  static const String emailLabel = 'Email';
  static const String passwordLabel = 'Пароль';
  static const String rememberMe = 'Запомнить меня';
  static const String forgotPassword = 'Забыли пароль';
  static const String loginButton = 'Войти';
  static const String noAccount = 'У вас нет аккаунта?';
  static const String registrationLink = 'Регистрация';

  // Регистрация
  static const String registrationTitle = 'Регистрация';
  static const String firstNameLabel = 'Имя';
  static const String lastNameLabel = 'Фамилия';
  static const String registrationPasswordLabel = 'Пароль';
  static const String confirmPasswordLabel = 'Повторите пароль';
  static const String agreement = 
      'Я согласен(на) на обработку персональных данных';
  static const String registrationButton = 'Регистрация';

  // Общие сообщения
  static const String fixFormErrors = 'Проверьте правильность заполнения полей';
  static const String agreementRequired =
      'Необходимо согласие на обработку персональных данных';
  static const String notificationsEmpty = 'Новых уведомлений нет';
  static const String unexpectedError =
      'Что-то пошло не так. Попробуйте ещё раз';
  static const String forgotPasswordTitle = 'Восстановление пароля';
  static const String forgotPasswordMessage =
      'Восстановление пароля будет доступно в следующей версии приложения. '
      'Если вы забыли пароль, обратитесь в службу поддержки магазина.';
  static const String logoutTitle = 'Выход из аккаунта';
  static const String logoutMessage = 'Вы действительно хотите выйти?';
  static const String logoutConfirm = 'Выйти';
  static const String logoutDone = 'Вы вышли из аккаунта';
}
