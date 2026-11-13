import 'package:flutter/foundation.dart';

import '../data/repositories/user_repository.dart';
import '../models/user.dart';
import '../models/user_sizes.dart';
import '../services/media_storage.dart';

/// Параметры пользователя (рост, вес, размеры, стаж, вид спорта).
class ProfileState extends ChangeNotifier {
  ProfileState(this._repository, this._storage);

  final UserRepository _repository;
  final MediaStorage _storage;

  int? _userId;
  UserSizes? _sizes;
  bool _isLoading = false;
  bool _isSaving = false;

  UserSizes? get sizes => _sizes;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get hasCompleteSizes => _sizes?.isComplete ?? false;

  Future<void> setUser(int? userId) async {
    if (userId == _userId) return;
    _userId = userId;
    _sizes = null;
    notifyListeners();
    if (userId == null) return;
    await load();
  }

  Future<void> load() async {
    final int? userId = _userId;
    if (userId == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      _sizes = await _repository.getSizes(userId);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Сохранение экрана «Редактирование профиля»: users + user_sizes.
  Future<User> saveProfile({
    required User user,
    required UserSizes sizes,
  }) async {
    _isSaving = true;
    notifyListeners();
    try {
      final User updatedUser = await _repository.update(user);
      await _repository.saveSizes(sizes);
      _sizes = await _repository.getSizes(sizes.userId);
      return updatedUser;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Сохранение параметров из опроса AI-подбора.
  Future<void> saveSizes(UserSizes sizes) async {
    await _repository.saveSizes(sizes);
    _sizes = await _repository.getSizes(sizes.userId);
    notifyListeners();
  }

  /// Новый аватар из камеры или галереи. null — пользователь отменил выбор.
  Future<User?> pickAvatar(User user, PhotoSource source) async {
    final String? path = await _storage.pickAndSave(
      userId: user.id!,
      kind: PhotoKind.avatar,
      source: source,
    );
    if (path == null) return null;
    final User updated =
        await _repository.update(user.copyWith(avatarPath: path));
    await _storage.delete(user.avatarPath);
    return updated;
  }

  Future<User> removeAvatar(User user) async {
    final User updated =
        await _repository.update(user.copyWith(clearAvatar: true));
    await _storage.delete(user.avatarPath);
    return updated;
  }
}
