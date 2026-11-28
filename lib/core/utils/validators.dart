/// Правила проверки полей ввода.
/// Каждый метод возвращает текст ошибки или null, если всё верно —
/// это формат, который ожидает TextFormField.validator.
class Validators {
  Validators._();

  static const int passwordMinLength = 8;
  static const int passwordMaxLength = 64;
  static const int nameMinLength = 2;
  static const int nameMaxLength = 30;
  static const int emailMaxLength = 100;

  static final RegExp _emailRegExp =
      RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)*\.[A-Za-z]{2,}$');
  static final RegExp _nameRegExp =
      RegExp(r'^[A-Za-zА-Яа-яЁёӘәҒғҚқҢңӨөҰұҮүҺһІі\- ]+$');
  static final RegExp _letterRegExp = RegExp(r'[A-Za-zА-Яа-яЁё]');
  static final RegExp _digitRegExp = RegExp(r'\d');
  static final RegExp _notDigitRegExp = RegExp(r'\D');

  static String? requiredField(
    String? value, [
    String message = 'Заполните обязательное поле',
  ]) {
    return (value == null || value.trim().isEmpty) ? message : null;
  }

  static String? email(String? value) {
    final String text = value?.trim() ?? '';
    if (text.isEmpty) return 'Введите адрес электронной почты';
    if (text.length > emailMaxLength) {
      return 'Адрес электронной почты слишком длинный';
    }
    if (!_emailRegExp.hasMatch(text)) return 'Некорректный формат email';
    return null;
  }

  /// При входе проверяем только заполненность: правильность пароля
  /// проверит AuthService.
  static String? loginPassword(String? value) {
    return (value == null || value.isEmpty) ? 'Введите пароль' : null;
  }

  /// Требования к новому паролю при регистрации.
  static String? password(String? value) {
    final String text = value ?? '';
    if (text.isEmpty) return 'Введите пароль';
    if (text.contains(' ')) return 'Пароль не должен содержать пробелы';
    if (text.length < passwordMinLength) {
      return 'Пароль должен содержать не менее $passwordMinLength символов';
    }
    if (text.length > passwordMaxLength) {
      return 'Пароль должен содержать не более $passwordMaxLength символов';
    }
    if (!_letterRegExp.hasMatch(text) || !_digitRegExp.hasMatch(text)) {
      return 'Пароль должен содержать буквы и цифры';
    }
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) return 'Повторите пароль';
    if (value != password) return 'Пароли не совпадают';
    return null;
  }

  static String? name(String? value, {required String emptyMessage}) {
    final String text = value?.trim() ?? '';
    if (text.isEmpty) return emptyMessage;
    if (text.length < nameMinLength) {
      return 'Должно быть не менее $nameMinLength символов';
    }
    if (text.length > nameMaxLength) {
      return 'Должно быть не более $nameMaxLength символов';
    }
    if (!_nameRegExp.hasMatch(text)) {
      return 'Допустимы только буквы, пробел и дефис';
    }
    return null;
  }

  /// Казахстанский номер: 11 цифр, начинается с 7 или 8.
  static String? phone(String? value) {
    final String digits = (value ?? '').replaceAll(_notDigitRegExp, '');
    if (digits.isEmpty) return 'Введите номер телефона';
    final bool validStart = digits.startsWith('7') || digits.startsWith('8');
    if (digits.length != 11 || !validStart) {
      return 'Введите номер в формате +7 XXX XXX XX XX';
    }
    return null;
  }

  /// Целое число в диапазоне [min; max] — рост, вес, размер обуви, стаж.
  static String? intInRange(
    String? value, {
    required int min,
    required int max,
    required String emptyMessage,
    required String rangeMessage,
  }) {
    final String text = value?.trim() ?? '';
    if (text.isEmpty) return emptyMessage;
    final int? number = int.tryParse(text);
    if (number == null) return 'Введите целое число';
    if (number < min || number > max) return rangeMessage;
    return null;
  }

  /// ИИН (физлицо, ИП, самозанятый) или БИН (ТОО): 12 цифр и верная
  /// контрольная цифра. У ИИН первые 6 цифр — дата рождения ГГММДД,
  /// 7-я — век и пол (1–6); у БИН 5-я цифра — тип организации (4–6).
  static String? iin(String? value, {required bool bin}) {
    final String text = value?.trim() ?? '';
    final String name = bin ? 'БИН' : 'ИИН';
    if (text.isEmpty) return 'Укажите $name';
    if (!RegExp(r'^\d{12}$').hasMatch(text)) return '$name — это 12 цифр';
    final List<int> d = text.split('').map(int.parse).toList();
    if (bin) {
      if (d[4] < 4 || d[4] > 6) return 'Неверный БИН: 5-я цифра — тип организации (4, 5 или 6)';
    } else {
      final int month = d[2] * 10 + d[3], day = d[4] * 10 + d[5];
      if (month < 1 || month > 12 || day < 1 || day > 31 || d[6] < 1 || d[6] > 6) {
        return 'Неверный ИИН: первые цифры — дата рождения';
      }
    }
    if (!hasValidChecksum(text)) return 'Неверный $name: не сходится контрольная цифра';
    return null;
  }

  /// Контрольная цифра ИИН/БИН: сумма цифр с весами 1–11 по модулю 11;
  /// если получилось 10 — веса 3–11, 1, 2; снова 10 — номер неверный.
  static bool hasValidChecksum(String twelveDigits) {
    final List<int> d = twelveDigits.split('').map(int.parse).toList();
    int sum(List<int> weights) {
      int s = 0;
      for (int i = 0; i < 11; i++) {
        s += d[i] * weights[i];
      }
      return s % 11;
    }

    int control = sum(const [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]);
    if (control == 10) control = sum(const [3, 4, 5, 6, 7, 8, 9, 10, 11, 1, 2]);
    return control != 10 && control == d[11];
  }
}
