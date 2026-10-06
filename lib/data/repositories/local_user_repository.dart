import '../../models/user.dart';
import '../../models/user_sizes.dart';
import '../datasources/local/user_local_datasource.dart';
import 'user_repository.dart';

class LocalUserRepository implements UserRepository {
  LocalUserRepository(this._dataSource);

  final UserLocalDataSource _dataSource;

  @override
  Future<User?> findByEmail(String email) => _dataSource.findByEmail(email);

  @override
  Future<User?> findById(int id) => _dataSource.findById(id);

  @override
  Future<User> create(User user) => _dataSource.insert(user);

  @override
  Future<User> update(User user) => _dataSource.update(user);

  @override
  Future<UserSizes?> getSizes(int userId) => _dataSource.getSizes(userId);

  @override
  Future<UserSizes> saveSizes(UserSizes sizes) => _dataSource.saveSizes(sizes);

  @override
  Future<List<User>> getAll() => _dataSource.getAll();
}
