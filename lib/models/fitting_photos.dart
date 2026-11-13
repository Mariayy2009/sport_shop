/// Фотографии пользователя для примерки (таблица fitting_photos)
/// и подгонка одежды под фото в полный рост.
///
/// Файлы лежат в закрытой папке приложения; в базе — только пути.
class FittingPhotos {
  const FittingPhotos({
    required this.userId,
    this.facePath,
    this.bodyPath,
    this.fitScale = 1,
    this.fitWidth = 1,
    this.fitDx = 0,
    this.fitDy = 0,
    required this.consentAt,
  });

  static const double minScale = 0.5;
  static const double maxScale = 1.3;
  static const double minWidth = 0.7;
  static const double maxWidth = 1.5;

  final int userId;

  /// Фото лица — показывается на голове манекена.
  final String? facePath;

  /// Фото в полный рост — на него накладывается одежда.
  final String? bodyPath;

  /// Высота фигуры относительно высоты кадра.
  final double fitScale;

  /// Ширина одежды относительно стандартной фигуры.
  final double fitWidth;

  /// Сдвиг одежды от центра кадра в долях его ширины и высоты.
  final double fitDx;
  final double fitDy;

  /// Когда пользователь согласился на хранение фотографий.
  final DateTime consentAt;

  bool get hasFace => facePath != null;
  bool get hasBody => bodyPath != null;
  bool get isEmpty => !hasFace && !hasBody;

  factory FittingPhotos.fromMap(Map<String, Object?> map) {
    return FittingPhotos(
      userId: map['user_id'] as int,
      facePath: map['face_path'] as String?,
      bodyPath: map['body_path'] as String?,
      fitScale: (map['fit_scale'] as num?)?.toDouble() ?? 1,
      fitWidth: (map['fit_width'] as num?)?.toDouble() ?? 1,
      fitDx: (map['fit_dx'] as num?)?.toDouble() ?? 0,
      fitDy: (map['fit_dy'] as num?)?.toDouble() ?? 0,
      consentAt: DateTime.parse(map['consent_at'] as String),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'user_id': userId,
      'face_path': facePath,
      'body_path': bodyPath,
      'fit_scale': fitScale,
      'fit_width': fitWidth,
      'fit_dx': fitDx,
      'fit_dy': fitDy,
      'consent_at': consentAt.toIso8601String(),
    };
  }

  FittingPhotos copyWith({
    String? facePath,
    String? bodyPath,
    bool clearFace = false,
    bool clearBody = false,
    double? fitScale,
    double? fitWidth,
    double? fitDx,
    double? fitDy,
  }) {
    return FittingPhotos(
      userId: userId,
      facePath: clearFace ? null : (facePath ?? this.facePath),
      bodyPath: clearBody ? null : (bodyPath ?? this.bodyPath),
      fitScale: fitScale ?? this.fitScale,
      fitWidth: fitWidth ?? this.fitWidth,
      fitDx: fitDx ?? this.fitDx,
      fitDy: fitDy ?? this.fitDy,
      consentAt: consentAt,
    );
  }
}
