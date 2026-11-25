import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/repositories/notification_repository.dart';
import '../models/app_notification.dart';

/// Уведомления вошедшего пользователя: красный кружок на «Профиле»
/// и список на экране «Уведомления».
class NotificationState extends ChangeNotifier {
  NotificationState(this._repository);

  final NotificationRepository _repository;

  int? _userId;
  int _unread = 0;
  List<AppNotification> _items = const [];
  Timer? _timer;

  int get unread => _unread;
  List<AppNotification> get items => _items;

  Future<void> setUser(int? userId) async {
    _timer?.cancel();
    _timer = null;
    _userId = userId;
    _items = const [];
    if (userId == null) {
      _unread = 0;
      notifyListeners();
      return;
    }
    // Продавец отвечает, заказ едет — проверяем раз в полминуты.
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
    await refresh();
  }

  Future<void> refresh() async {
    final int? userId = _userId;
    if (userId == null) return;
    try {
      final int unread = await _repository.unreadCount(userId);
      if (_userId != userId) return;
      if (unread != _unread) {
        _unread = unread;
        notifyListeners();
      }
    } on Exception catch (error) {
      debugPrint('Не удалось обновить уведомления: $error');
    }
  }

  /// Открыл список — всё прочитано.
  Future<void> open() async {
    final int? userId = _userId;
    if (userId == null) return;
    _items = await _repository.forUser(userId);
    await _repository.markAllRead(userId);
    _unread = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
