/// Тексты интерфейса в одном месте.
/// Подписи совпадают с макетами Figma: если нужно перевести
/// английские подписи регистрации на русский, меняем только здесь.
class AppStrings {
  AppStrings._();

  static const String appName = 'SPORT';
  static const String currency = '₸';

  // Подписи нижней навигации (как в Figma)
  static const String navHome = 'Home';
  static const String navCatalog = 'Catalog';
  static const String navAi = 'AI';
  static const String navBasket = 'Basket';
  static const String navProfile = 'Profile';

  // Вход
  static const String loginTitle = 'Вход';
  static const String emailLabel = 'Email';
  static const String passwordLabel = 'Пароль';
  static const String rememberMe = 'Запомнить меня';
  static const String forgotPassword = 'Забыли пароль';
  static const String loginButton = 'Войти';
  static const String noAccount = 'У вас нет аккаунта?';
  static const String registrationLink = 'Регистрация';

  // Регистрация (подписи полей как в Figma)
  static const String registrationTitle = 'Регистрация';
  static const String firstNameLabel = 'Name';
  static const String lastNameLabel = 'Surname';
  static const String registrationPasswordLabel = 'Password';
  static const String confirmPasswordLabel = 'Repeat the password';
  static const String agreement = 'I agree to the processing of personal data';
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
