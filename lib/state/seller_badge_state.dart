import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/repositories/feedback_repository.dart';
import '../data/repositories/moderation_repository.dart';
import '../models/question.dart';

/// Кружочки-уведомления продавца: новые предупреждения администратора
/// (в том числе о снятом с продажи товаре) и вопросы без ответа.
/// Показываются на вкладке «Кабинет» и на вкладках внутри кабинета.
class SellerBadgeState extends ChangeNotifier {
  SellerBadgeState(this._moderation, this._feedback);

  final ModerationRepository _moderation;
  final FeedbackRepository _feedback;

  int? _sellerId;
  int _warnings = 0;
  int _questions = 0;
  Timer? _timer;

  /// Непрочитанные предупреждения.
  int get warnings => _warnings;

  /// Вопросы покупателей, на которые продавец ещё не ответил.
  int get questions => _questions;

  int get total => _warnings + _questions;

  /// Вход продавца — начинаем проверять; покупатель или выход — сброс.
  Future<void> setSeller(int? sellerId) async {
    _timer?.cancel();
    _timer = null;
    _sellerId = sellerId;
    if (sellerId == null) {
      _set(0, 0);
      return;
    }
    // Администратор может снять товар в любой момент — проверяем
    // раз в полминуты (запрос к своей базе, это быстро).
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
    await refresh();
  }

  Future<void> refresh() async {
    final int? sellerId = _sellerId;
    if (sellerId == null) return;
    try {
      final int warnings = await _moderation.unreadCount(sellerId);
      final List<Question> questions =
          await _feedback.getQuestionsForSeller(sellerId);
      if (_sellerId != sellerId) return;
      _set(warnings, questions.where((q) => q.answer == null).length);
    } on Exception catch (error) {
      debugPrint('Не удалось обновить уведомления продавца: $error');
    }
  }

  void _set(int warnings, int questions) {
    if (warnings == _warnings && questions == _questions) return;
    _warnings = warnings;
    _questions = questions;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
