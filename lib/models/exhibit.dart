/// Откуда экспонат.
enum ExhibitSource {
  /// Экспозиция университета КНУС.
  knus('knus', 'КНУС', 'Экспонат КНУС'),

  /// Экипировка известных спортсменов Казахстана.
  kazakhstan('kazakhstan', 'Спортсмен Казахстана', 'Спортсмены Казахстана');

  const ExhibitSource(this.value, this.label, this.fullLabel);

  final String value;

  /// Короткая подпись для плашки на фото.
  final String label;
  final String fullLabel;

  static ExhibitSource fromValue(String? value) => ExhibitSource.values
      .firstWhere((source) => source.value == value, orElse: () => knus);
}

/// Экспонат «Зала славы» (таблица exhibits): вещь спортсмена
/// с историей. От экспоната можно перейти к похожим товарам каталога
/// и примерить похожую вещь.
class Exhibit {
  const Exhibit({
    this.id,
    required this.title,
    required this.athlete,
    this.sportId,
    this.sportLabel,
    this.year,
    this.story,
    this.imageUrl,
    this.gallery = const [],
    this.source = ExhibitSource.knus,
    required this.createdAt,
    this.sportName,
  });

  final int? id;

  /// Что это за вещь: «Игровая майка», «Мяч финала».
  final String title;

  /// Чья вещь: спортсмен, сборная или федерация.
  final String athlete;
  /// Вид спорта каталога — по нему подбираются похожие товары
  /// (null — в каталоге такого вида спорта нет).
  final int? sportId;

  /// Вид спорта экспоната как на табличке: «Лыжные гонки», «Дзюдо».
  final String? sportLabel;

  /// Год или период: «2012», «2016–2020».
  final String? year;

  /// История экспоната: достижение, соревнование, факты с таблички.
  final String? story;
  final String? imageUrl;

  /// Дополнительные фото — листаются на странице экспоната после [imageUrl].
  final List<String> gallery;
  final ExhibitSource source;
  final DateTime createdAt;

  /// Название вида спорта каталога — заполняется через JOIN.
  final String? sportName;

  /// Все фото экспоната: обложка и галерея.
  List<String> get images => [
        if (imageUrl != null && imageUrl!.isNotEmpty) imageUrl!,
        ...gallery,
      ];

  /// Вид спорта для показа: подпись экспоната, а без неё — из каталога.
  String? get sportTitle {
    final String label = sportLabel?.trim() ?? '';
    return label.isEmpty ? sportName : label;
  }

  factory Exhibit.fromMap(Map<String, Object?> map) {
    return Exhibit(
      id: map['id'] as int?,
      title: map['title'] as String,
      athlete: map['athlete'] as String,
      sportId: map['sport_id'] as int?,
      sportLabel: map['sport_label'] as String?,
      year: map['year'] as String?,
      story: map['story'] as String?,
      imageUrl: map['image_url'] as String?,
      gallery: [
        for (final String line
            in ((map['gallery'] as String?) ?? '').split('\n'))
          if (line.trim().isNotEmpty) line.trim(),
      ],
      source: ExhibitSource.fromValue(map['source'] as String?),
      createdAt: DateTime.parse(map['created_at'] as String),
      sportName: map['sport_name'] as String?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'athlete': athlete,
      'sport_id': sportId,
      'sport_label': sportLabel,
      'year': year,
      'story': story,
      'image_url': imageUrl,
      'gallery': gallery.join('\n'),
      'source': source.value,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
