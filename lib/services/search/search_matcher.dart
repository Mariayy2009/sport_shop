/// Поиск без разницы языка: «adidas» находит «Адидас» и наоборот,
/// «найк» — «Nike», «krossovki» — «Кроссовки».
///
/// Каждое слово переводится в латиницу и упрощается так, как его
/// записали бы на слух: c → k, y → i, w → v, двойные буквы — одна.
/// Совпадение — если упрощённый запрос — начало упрощённого слова
/// (можно не дописывать), или если совпадают согласные целиком
/// (так «найк» = «nike»: н-к = n-k).
class SearchMatcher {
  const SearchMatcher(this.query);

  final String query;

  static const Map<String, String> _cyrillic = {
    'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'е': 'e', 'ё': 'e',
    'ж': 'zh', 'з': 'z', 'и': 'i', 'й': 'i', 'к': 'k', 'л': 'l', 'м': 'm',
    'н': 'n', 'о': 'o', 'п': 'p', 'р': 'r', 'с': 's', 'т': 't', 'у': 'u',
    'ф': 'f', 'х': 'h', 'ц': 'ts', 'ч': 'ch', 'ш': 'sh', 'щ': 'sh', 'ъ': '',
    'ы': 'i', 'ь': '', 'э': 'e', 'ю': 'iu', 'я': 'ia',
    // Казахские буквы.
    'ә': 'a', 'ғ': 'g', 'қ': 'k', 'ң': 'n', 'ө': 'o', 'ұ': 'u', 'ү': 'u',
    'һ': 'h', 'і': 'i',
  };

  /// Слово → латиница «на слух».
  static String simplify(String word) {
    final StringBuffer latin = StringBuffer();
    for (final String char in word.toLowerCase().split('')) {
      latin.write(_cyrillic[char] ?? char);
    }
    String s = latin.toString().replaceAll(RegExp('[^a-z0-9]'), '');
    s = s
        .replaceAll('ph', 'f')
        .replaceAll('ck', 'k')
        .replaceAll('kh', 'h')
        .replaceAll('x', 'ks')
        .replaceAll('w', 'v')
        .replaceAll('y', 'i')
        .replaceAll('ee', 'i')
        .replaceAll('oo', 'u')
        .replaceAllMapped(RegExp('c(?!h)'), (_) => 'k');
    // Двойные буквы — одна: «Mizzuno» = «Мизуно».
    return s.replaceAllMapped(RegExp(r'(.)\1+'), (m) => m.group(1)!);
  }

  /// Только согласные: «nike» → «nk», «найк» → «nk».
  static String consonants(String simplified) =>
      simplified.replaceAll(RegExp('[aeiou]'), '');

  static List<String> _words(String text) => text
      .toLowerCase()
      .split(RegExp(r'[^a-zа-яёәғқңөұүһі0-9]+'))
      .where((word) => word.isNotEmpty)
      .toList();

  /// Все слова запроса нашлись в [texts] (название, бренд, описание…).
  bool matches(Iterable<String?> texts) {
    final List<String> queryWords = _words(query);
    if (queryWords.isEmpty) return true;
    final String plain = texts.whereType<String>().join(' ').toLowerCase();
    final List<String> words = _words(plain).map(simplify).toList();
    for (final String queryWord in queryWords) {
      if (plain.contains(queryWord)) continue;
      final String q = simplify(queryWord);
      final String qc = consonants(q);
      final bool found = words.any((word) =>
          (q.length >= 3 && word.startsWith(q)) ||
          (qc.length >= 2 && consonants(word) == qc));
      if (!found) return false;
    }
    return true;
  }
}
