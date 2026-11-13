import 'enums.dart';

/// Пользователь (таблица users).
///
/// Поле [phone] добавлено к ER-схеме КР №1: телефон показан
/// в макетах профиля и оформления заказа.
class User {
  const User({
    this.id,
    required this.email,
    required this.passwordHash,
    required this.role,
    this.firstName,
    this.lastName,
    this.phone,
    this.avatarPath,
    required this.createdAt,
  });

  /// null — пользователь ещё не сохранён в БД.
  final int? id;
  final String email;
  final String passwordHash;
  final UserRole role;
  final String? firstName;
  final String? lastName;
  final String? phone;

  /// Путь к файлу аватара в папке приложения (null — аватара нет).
  final String? avatarPath;
  final DateTime createdAt;

  bool get isAdmin => role == UserRole.admin;

  /// «Мария Габдулина»; если имени нет — email.
  String get fullName {
    final List<String> parts = [firstName, lastName]
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    return parts.isEmpty ? email : parts.join(' ');
  }

  /// Имя для приветствия в AI-подборе: «Привет, Мария!».
  String get greetingName {
    final String name = firstName?.trim() ?? '';
    return name.isEmpty ? 'друг' : name;
  }

  // ---------- SQLite ----------

  factory User.fromMap(Map<String, Object?> map) {
    return User(
      id: map['id'] as int?,
      email: map['email'] as String,
      passwordHash: (map['password_hash'] as String?) ?? '',
      role: UserRole.fromValue(map['role'] as String?),
      firstName: map['first_name'] as String?,
      lastName: map['last_name'] as String?,
      phone: map['phone'] as String?,
      avatarPath: map['avatar_path'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'email': email,
      'password_hash': passwordHash,
      'role': role.value,
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'avatar_path': avatarPath,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // ---------- REST API (диплом) ----------

  factory User.fromJson(Map<String, Object?> json) => User.fromMap(json);

  /// Хеш пароля никогда не отправляется по сети.
  Map<String, Object?> toJson() => toMap()..remove('password_hash');

  User copyWith({
    int? id,
    String? email,
    String? passwordHash,
    UserRole? role,
    String? firstName,
    String? lastName,
    String? phone,
    String? avatarPath,
    bool clearAvatar = false,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      role: role ?? this.role,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      avatarPath: clearAvatar ? null : (avatarPath ?? this.avatarPath),
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
