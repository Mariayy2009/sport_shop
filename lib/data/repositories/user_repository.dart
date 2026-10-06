import '../../models/user.dart';
import '../../models/user_sizes.dart';

/// Контракт работы с пользователями.
/// Сейчас реализация — LocalUserRepository (SQLite),
/// в дипломе — ApiUserRepository (REST API → PostgreSQL).
abstract class UserRepository {
  Future<User?> findByEmail(String email);

  Future<User?> findById(int id);

  Future<User> create(User user);

  Future<User> update(User user);

  Future<UserSizes?> getSizes(int userId);

  Future<UserSizes> saveSizes(UserSizes sizes);

  /// Для будущей административной части.
  Future<List<User>> getAll();
}
