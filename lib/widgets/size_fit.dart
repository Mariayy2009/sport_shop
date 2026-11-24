/// Размер вещи относительно рекомендуемого: как вещь будет сидеть.
class SizeFit {
  const SizeFit._();

  /// На сколько каждый размер шире и длиннее соседнего.
  static const double step = 0.1;

  /// Масштаб вещи для [selected] при рекомендуемом [recommended].
  static double scale(List<String> sizes, String? selected, String? recommended) {
    final int s = sizes.indexOf(selected ?? '');
    // Без анкеты в профиле — относительно среднего размера, иначе
    // размер вообще не менял бы вещь.
    final int r = recommended == null
        ? sizes.length ~/ 2
        : sizes.indexOf(recommended);
    if (s < 0 || r < 0) return 1;
    return 1 + (s - r) * step;
  }

  /// Как сидит [selected] при рекомендуемом [recommended] — для подписи.
  static String describe(List<String> sizes, String? selected, String? recommended) {
    final int s = sizes.indexOf(selected ?? '');
    final int r = recommended == null
        ? sizes.length ~/ 2
        : sizes.indexOf(recommended);
    if (s < 0 || r < 0) return '';
    final int diff = s - r;
    if (diff == 0) return 'по размеру';
    if (diff == 1) return 'свободно';
    if (diff >= 2) return 'велико';
    if (diff == -1) return 'в обтяжку';
    return 'мало';
  }
}
