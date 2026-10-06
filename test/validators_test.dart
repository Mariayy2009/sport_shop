import 'package:flutter_test/flutter_test.dart';
import 'package:sport_shop/core/utils/validators.dart';

void main() {
  group('Email', () {
    test('пустой', () {
      expect(Validators.email(''), 'Введите адрес электронной почты');
    });
    test('неверный формат', () {
      expect(Validators.email('maria@mail'), 'Некорректный формат email');
      expect(Validators.email('maria.mail.kz'), 'Некорректный формат email');
    });
    test('корректный', () {
      expect(Validators.email('maria@mail.kz'), isNull);
      expect(Validators.email('  Maria.G@gmail.com '), isNull);
    });
  });

  group('Пароль', () {
    test('короткий', () {
      expect(Validators.password('abc12'), contains('не менее 8'));
    });
    test('без цифр', () {
      expect(Validators.password('abcdefgh'), 'Пароль должен содержать буквы и цифры');
    });
    test('с пробелом', () {
      expect(Validators.password('abcd 1234'), 'Пароль не должен содержать пробелы');
    });
    test('корректный', () {
      expect(Validators.password('Maria123'), isNull);
    });
    test('пароли не совпадают', () {
      expect(Validators.confirmPassword('Maria124', 'Maria123'), 'Пароли не совпадают');
      expect(Validators.confirmPassword('Maria123', 'Maria123'), isNull);
    });
  });

  group('Имя', () {
    test('пустое', () {
      expect(Validators.name(' ', emptyMessage: 'Введите имя'), 'Введите имя');
    });
    test('цифры недопустимы', () {
      expect(
        Validators.name('Мария1', emptyMessage: 'Введите имя'),
        'Допустимы только буквы, пробел и дефис',
      );
    });
    test('кириллица, латиница, казахские буквы, дефис', () {
      expect(Validators.name('Анна-Мария', emptyMessage: ''), isNull);
      expect(Validators.name('Maria', emptyMessage: ''), isNull);
      expect(Validators.name('Әйгерім', emptyMessage: ''), isNull);
    });
  });

  group('Телефон и числа', () {
    test('телефон', () {
      expect(Validators.phone('+7 708 777 5555'), isNull);
      expect(Validators.phone('8 708 777 55 55'), isNull);
      expect(Validators.phone('12345'), isNotNull);
    });
    test('диапазон', () {
      String? height(String value) => Validators.intInRange(
            value,
            min: 100,
            max: 230,
            emptyMessage: 'Введите рост',
            rangeMessage: 'Рост должен быть от 100 до 230 см',
          );
      expect(height(''), 'Введите рост');
      expect(height('abc'), 'Введите целое число');
      expect(height('300'), 'Рост должен быть от 100 до 230 см');
      expect(height('160'), isNull);
    });
  });
}
