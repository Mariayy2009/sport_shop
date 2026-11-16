/// Откуда экспонат.
enum ExhibitSource {
  /// Экспозиция университета КНУС.
  knus('knus', 'КНУС', 'Экспонат КНУС'),

  /// Экипировка известных спортсменов Казахстана.
  kazakhstan('kazakhstan', 'Казахстан', 'Спортсмены Казахстана');

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
    this.year,
    this.story,
    this.imageUrl,
    this.source = ExhibitSource.knus,
    required this.createdAt,
    this.sportName,
  });

  final int? id;

  /// Что это за вещь: «Игровая майка», «Мяч финала».
  final String title;

  /// Чья вещь.
  final String athlete;
  final int? sportId;

  /// Год или период: «2012», «2016–2020».
  final String? year;

  /// История экспоната: достижение, соревнование, факты с таблички.
  final String? story;
  final String? imageUrl;
  final ExhibitSource source;
  final DateTime createdAt;

  /// Название вида спорта — заполняется через JOIN.
  final String? sportName;

  factory Exhibit.fromMap(Map<String, Object?> map) {
    return Exhibit(
      id: map['id'] as int?,
      title: map['title'] as String,
      athlete: map['athlete'] as String,
      sportId: map['sport_id'] as int?,
      year: map['year'] as String?,
      story: map['story'] as String?,
      imageUrl: map['image_url'] as String?,
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
      'year': year,
      'story': story,
      'image_url': imageUrl,
      'source': source.value,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
