import 'package:flutter_test/flutter_test.dart';
import 'package:sport_shop/services/search/search_matcher.dart';

void main() {
  bool find(String query, String text) => SearchMatcher(query).matches([text]);

  test('поиск без разницы языка', () {
    expect(find('адидас', 'Штаны Adidas'), isTrue);
    expect(find('adidas', 'Штаны Адидас'), isTrue);
    expect(find('найк', 'Футболка тренировочная Nike Academy'), isTrue);
    expect(find('асикс', 'Наколенники ASICS'), isTrue);
    expect(find('микаса', 'Профессиональный мяч MIKASA'), isTrue);
    expect(find('krossovki', 'Кроссовки для бега'), isTrue);
    expect(find('kimono', 'Кимоно для карате'), isTrue);
    expect(find('адид', 'Мяч Adidas Trionda'), isTrue); // не дописали
    expect(find('кимоно карате', 'Кимоно для карате классическое'), isTrue);
  });

  test('лишнего не находит', () {
    expect(find('адидас', 'Мяч Mikasa'), isFalse);
    expect(find('найк', 'Наколенники ASICS'), isFalse);
    expect(find('кимоно', 'Кроссовки для бега'), isFalse);
    expect(find('nike', 'Бинты боксёрские'), isFalse);
  });
}
