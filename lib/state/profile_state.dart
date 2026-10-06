import 'package:flutter/foundation.dart';

import '../data/repositories/user_repository.dart';
import '../models/user.dart';
import '../models/user_sizes.dart';

/// Параметры пользователя (рост, вес, размеры, стаж, вид спорта).
class ProfileState extends ChangeNotifier {
  ProfileState(this._repository);

  final UserRepository _repository;

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
}
