import 'package:flutter/foundation.dart';

import '../models/chat_message.dart';
import '../models/user.dart';
import '../models/user_sizes.dart';
import '../services/assistant/assistant_service.dart';

/// Диалог с ИИ-помощником. История хранится, пока пользователь в аккаунте.
class AssistantState extends ChangeNotifier {
  AssistantState(this._service);

  final AssistantService _service;

  int? _userId;
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isTyping => _isTyping;
  bool get isEmpty => _messages.isEmpty;

  /// Вызывается при входе / выходе: у каждого пользователя свой диалог.
  void setUser(int? userId) {
    if (userId == _userId) return;
    _userId = userId;
    clear();
  }

  void clear() {
    _messages.clear();
    _isTyping = false;
    notifyListeners();
  }

  Future<void> send(String text, {User? user, UserSizes? sizes}) async {
    final String trimmed = text.trim();
    if (trimmed.isEmpty || _isTyping) return;
    final int? askedBy = _userId;

    _messages.add(ChatMessage.user(trimmed));
    _isTyping = true;
    notifyListeners();

    AssistantReply reply;
    try {
      reply = await _service.ask(
        history: List.of(_messages),
        user: user,
        sizes: sizes,
      );
    } catch (error) {
      debugPrint('Ошибка помощника: $error');
      reply = const AssistantReply(
        text: 'Не получилось ответить. Попробуй задать вопрос ещё раз.',
      );
    }
    // Пока ждали ответ, пользователь вышел или сменился — ответ не нужен.
    if (askedBy != _userId) return;
    _messages.add(ChatMessage.fromReply(reply));
    _isTyping = false;
    notifyListeners();
  }
}
