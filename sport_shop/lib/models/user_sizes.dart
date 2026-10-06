import 'enums.dart';

/// Параметры пользователя (таблица user_sizes, связь 1:1 с users).
class UserSizes {
  const UserSizes({
    this.id,
    required this.userId,
    this.height,
    this.weight,
    this.clothingSize,
    this.shoeSize,
    this.experienceYears,
    this.sportId,
    this.sportName,
  });

  // Допустимые значения — используются валидацией (этап 13)
  // и элементами выбора в профиле и опросе.
  static const List<String> clothingSizes = ['XS', 'S', 'M', 'L', 'XL', 'XXL'];
  static const int minHeight = 100;
  static const int maxHeight = 230;
  static const int minWeight = 25;
  static const int maxWeight = 200;
  static const int minShoeSize = 30;
  static const int maxShoeSize = 50;
  static const int minExperience = 0;
  static const int maxExperience = 60;

  final int? id;
  final int userId;
  final int? height; // см
  final int? weight; // кг
  final String? clothingSize;
  final int? shoeSize;
  final int? experienceYears;
  final int? sportId;

  /// Название вида спорта — заполняется через JOIN, в БД не сохраняется.
  final String? sportName;

  /// Уровень, вычисленный по стажу.
  SportLevel get level => SportLevel.fromExperience(experienceYears ?? 0);

  /// Все параметры для подбора заполнены.
  bool get isComplete =>
      height != null &&
      weight != null &&
      clothingSize != null &&
      shoeSize != null &&
      experienceYears != null &&
      sportId != null;

  factory UserSizes.fromMap(Map<String, Object?> map) {
    return UserSizes(
      id: map['id'] as int?,
      userId: map['user_id'] as int,
      height: map['height'] as int?,
      weight: map['weight'] as int?,
      clothingSize: map['clothing_size'] as String?,
      shoeSize: map['shoe_size'] as int?,
      experienceYears: map['experience_years'] as int?,
      sportId: map['sport_id'] as int?,
      sportName: map['sport_name'] as String?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'height': height,
      'weight': weight,
      'clothing_size': clothingSize,
      'shoe_size': shoeSize,
      'experience_years': experienceYears,
      'sport_id': sportId,
    };
  }

  factory UserSizes.fromJson(Map<String, Object?> json) =>
      UserSizes.fromMap(json);

  Map<String, Object?> toJson() => toMap();

  UserSizes copyWith({
    int? id,
    int? userId,
    int? height,
    int? weight,
    String? clothingSize,
    int? shoeSize,
    int? experienceYears,
    int? sportId,
    String? sportName,
  }) {
    return UserSizes(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      clothingSize: clothingSize ?? this.clothingSize,
      shoeSize: shoeSize ?? this.shoeSize,
      experienceYears: experienceYears ?? this.experienceYears,
      sportId: sportId ?? this.sportId,
      sportName: sportName ?? this.sportName,
    );
  }
}
