/// Вид спорта (таблица sports).
class Sport {
  const Sport({
    this.id,
    required this.name,
    this.description,
  });

  final int? id;
  final String name;
  final String? description;

  factory Sport.fromMap(Map<String, Object?> map) {
    return Sport(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'description': description,
    };
  }

  factory Sport.fromJson(Map<String, Object?> json) => Sport.fromMap(json);

  Map<String, Object?> toJson() => toMap();

  @override
  bool operator ==(Object other) => other is Sport && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
