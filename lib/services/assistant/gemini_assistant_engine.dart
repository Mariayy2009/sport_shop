import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../models/chat_message.dart';
import '../size_advisor.dart';
import 'assistant_engine.dart';
import 'claude_assistant_engine.dart';

/// Помощник на языковой модели Google Gemini.
///
/// У Gemini есть бесплатный тариф: ключ выдаётся в Google AI Studio
/// (aistudio.google.com/apikey) без привязки карты, с ограничением
/// на число запросов в минуту и в день.
///
/// Модель получает каталог и профиль покупателя и возвращает ответ
/// в том же формате, что и остальные движки. Товары, которых нет
/// в каталоге, отбрасываются. При ошибке отвечает [_fallback].
class GeminiAssistantEngine implements AssistantEngine {
  GeminiAssistantEngine({
    required String apiKey,
    required AssistantEngine fallback,
    http.Client? client,
    String model = defaultModel,
    SizeAdvisor sizeAdvisor = const SizeAdvisor(),
  })  : _apiKey = apiKey,
        _fallback = fallback,
        _client = client ?? http.Client(),
        _model = model,
        _sizeAdvisor = sizeAdvisor;

  /// Псевдоним актуальной быстрой модели: не нужно менять код,
  /// когда выходит новая версия.
  static const String defaultModel = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-flash-latest',
  );

  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';
  static const Duration _timeout = Duration(seconds: 45);

  final String _apiKey;
  final AssistantEngine _fallback;
  final http.Client _client;
  final String _model;
  final SizeAdvisor _sizeAdvisor;

  /// Схема ответа в формате Gemini (типы — заглавными буквами).
  static const Map<String, Object?> _replySchema = {
    'type': 'OBJECT',
    'properties': {
      'message': {'type': 'STRING'},
      'picks': {
        'type': 'ARRAY',
        'items': {
          'type': 'OBJECT',
          'properties': {
            'product_id': {'type': 'INTEGER'},
            'reason': {'type': 'STRING'},
          },
          'required': ['product_id', 'reason'],
        },
      },
      'is_kit': {'type': 'BOOLEAN'},
      'suggestions': {
        'type': 'ARRAY',
        'items': {'type': 'STRING'},
      },
    },
    'required': ['message', 'picks', 'is_kit', 'suggestions'],
  };

  @override
  Future<AssistantReply> reply(
    AssistantContext context,
    List<ChatMessage> history,
  ) async {
    AssistantReply? reply;
    String? problem;
    try {
      final http.Response response = await _client
          .post(
            Uri.parse('$_baseUrl/$_model:generateContent'),
            headers: {
              'content-type': 'application/json',
              'x-goog-api-key': _apiKey,
            },
            body: jsonEncode(_buildRequest(context, history)),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        reply = _parse(
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, Object?>,
          context,
        );
      } else {
        debugPrint('Gemini API: HTTP ${response.statusCode} ${response.body}');
        problem = switch (response.statusCode) {
          400 || 401 || 403 =>
            'Ключ Gemini не принят — проверь его в настройках помощника.',
          429 => 'Бесплатный лимит запросов к Gemini на сейчас исчерпан.',
          _ => null,
        };
      }
    } on Exception catch (error) {
      // Нет сети, таймаут, неожиданный формат — ответит локальный движок.
      debugPrint('Gemini API недоступен: $error');
    }
    if (reply != null) return reply;

    final AssistantReply local = await _fallback.reply(context, history);
    if (problem == null) return local;
    // Пользователь должен понимать, почему ответ стал проще.
    return AssistantReply(
      text: '$problem Пока отвечаю без нейросети.\n\n${local.text}',
      picks: local.picks,
      suggestions: local.suggestions,
      isKit: local.isKit,
    );
  }

  Map<String, Object?> _buildRequest(
    AssistantContext context,
    List<ChatMessage> history,
  ) {
    final List<ChatMessage> tail =
        history.length > ClaudeAssistantEngine.historyLimit
            ? history.sublist(history.length - ClaudeAssistantEngine.historyLimit)
            : history;
    final List<Map<String, Object?>> contents = [];
    for (final ChatMessage message in tail) {
      // Диалог для модели начинается с сообщения пользователя.
      if (contents.isEmpty && !message.isUser) continue;
      final String shown = message.picks.isEmpty
          ? ''
          : '\n[показаны товары id: '
              '${message.picks.map((pick) => pick.product.id).join(', ')}]';
      contents.add({
        'role': message.isUser ? 'user' : 'model',
        'parts': [
          {'text': '${message.text}$shown'},
        ],
      });
    }
    return {
      'systemInstruction': {
        'parts': [
          {
            'text': '${ClaudeAssistantEngine.instructions}\n\n'
                'Каталог магазина (JSON):\n'
                '${jsonEncode(ClaudeAssistantEngine.catalogJson(context))}\n\n'
                '${ClaudeAssistantEngine.profileText(context)}',
          },
        ],
      },
      'contents': contents,
      'generationConfig': {
        'responseMimeType': 'application/json',
        'responseSchema': _replySchema,
      },
    };
  }

  /// null — ответ нельзя использовать, нужен запасной движок.
  AssistantReply? _parse(Map<String, Object?> body, AssistantContext context) {
    final List<Object?> candidates =
        body['candidates'] as List<Object?>? ?? const [];
    if (candidates.isEmpty) return null;
    final Map<String, Object?> candidate =
        candidates.first! as Map<String, Object?>;
    final String? finishReason = candidate['finishReason'] as String?;
    if (finishReason == 'SAFETY' || finishReason == 'PROHIBITED_CONTENT') {
      return const AssistantReply(
        text: 'С этим вопросом я помочь не могу. Давай вернёмся к экипировке: '
            'могу собрать комплект, подобрать размер или сравнить товары.',
      );
    }
    if (finishReason == 'MAX_TOKENS') return null;

    final Map<String, Object?>? content =
        candidate['content'] as Map<String, Object?>?;
    final StringBuffer json = StringBuffer();
    for (final Object? part in (content?['parts'] as List<Object?>? ?? const [])) {
      if (part is Map<String, Object?> && part['text'] is String) {
        json.write(part['text']);
      }
    }
    if (json.isEmpty) return null;
    return ClaudeAssistantEngine.replyFromData(
      jsonDecode(json.toString()) as Map<String, Object?>,
      context,
      _sizeAdvisor,
    );
  }
}
