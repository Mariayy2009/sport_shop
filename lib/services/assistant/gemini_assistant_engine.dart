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

  /// Запасная модель: если основная перегружена (503), исчерпала лимит
  /// (429) или недоступна для ключа (404), отвечает облегчённая.
  /// Оба названия — псевдонимы Google, они сами указывают на свежие версии.
  static const List<String> _fallbackModels = ['gemini-flash-lite-latest'];

  static const Set<int> _tryNextModelOn = {404, 429, 500, 503};

  /// Проверка ключа перед сохранением: запрос списка моделей.
  /// null — ключ рабочий, иначе текст ошибки для пользователя.
  static Future<String?> checkKey(String apiKey, {http.Client? client}) async {
    try {
      final http.Response response = await (client ?? http.Client())
          .get(
            Uri.parse('$_baseUrl?pageSize=1'),
            headers: {'x-goog-api-key': apiKey},
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) return null;
      return _describeError(response);
    } on Exception catch (error) {
      debugPrint('Проверка ключа Gemini: $error');
      return 'Нет связи с Google. Проверьте интернет: в некоторых сетях '
          'и регионах сервис Gemini недоступен без VPN.';
    }
  }

  /// Понятное описание ошибки API: причина + текст от Google.
  static String _describeError(http.Response response) {
    String detail = '';
    try {
      final Object? body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map<String, Object?> && body['error'] is Map<String, Object?>) {
        detail = ((body['error']! as Map<String, Object?>)['message'] as String?) ?? '';
      }
    } on FormatException {
      // Тело ответа — не JSON; хватит кода ошибки.
    }
    final String reason = switch (response.statusCode) {
      400 || 401 || 403 => 'Ключ Gemini не принят',
      404 => 'Модель Gemini недоступна для этого ключа',
      503 => 'Gemini сейчас перегружен, попробуй через минуту',
      429 => 'Бесплатный лимит запросов к Gemini на сейчас исчерпан',
      _ => 'Gemini вернул ошибку ${response.statusCode}',
    };
    final String shortDetail =
        detail.length > 160 ? '${detail.substring(0, 160)}…' : detail;
    return shortDetail.isEmpty ? '$reason.' : '$reason: $shortDetail';
  }

  Future<http.Response> _send(
    String model,
    AssistantContext context,
    List<ChatMessage> history, {
    required bool withSchema,
  }) {
    return _client
        .post(
          Uri.parse('$_baseUrl/$model:generateContent'),
          headers: {
            'content-type': 'application/json',
            'x-goog-api-key': _apiKey,
          },
          body: jsonEncode(_buildRequest(context, history, withSchema: withSchema)),
        )
        .timeout(_timeout);
  }

  @override
  Future<AssistantReply> reply(
    AssistantContext context,
    List<ChatMessage> history,
  ) async {
    AssistantReply? reply;
    String? problem;
    try {
      http.Response response =
          await _send(_model, context, history, withSchema: true);
      // Основная модель перегружена или недоступна — пробуем запасную.
      for (final String model in _fallbackModels) {
        if (!_tryNextModelOn.contains(response.statusCode)) break;
        response = await _send(model, context, history, withSchema: true);
      }
      // Схему ответа сервер не принял — просим JSON без неё:
      // формат описан в самой инструкции.
      if (response.statusCode == 400 &&
          utf8.decode(response.bodyBytes).toLowerCase().contains('schema')) {
        response = await _send(_model, context, history, withSchema: false);
      }

      if (response.statusCode == 200) {
        reply = _parse(
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, Object?>,
          context,
        );
        if (reply == null) problem = 'Gemini прислал пустой ответ.';
      } else {
        debugPrint('Gemini API: HTTP ${response.statusCode} ${response.body}');
        problem = _describeError(response);
      }
    } on FormatException catch (error) {
      debugPrint('Gemini API: ответ не разобран: $error');
      problem = 'Gemini прислал ответ в неожиданном формате.';
    } on Exception catch (error) {
      // Нет сети или таймаут — ответит локальный движок.
      debugPrint('Gemini API недоступен: $error');
      problem = 'Нет связи с Gemini (интернет или блокировка сервиса).';
    }
    if (reply != null) return reply;

    final AssistantReply local = await _fallback.reply(context, history);
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
    List<ChatMessage> history, {
    required bool withSchema,
  }) {
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
                '${ClaudeAssistantEngine.profileText(context)}\n\n'
                'Ответ — один JSON-объект с полями: message (строка), '
                'picks (массив объектов {product_id: число, reason: строка}), '
                'is_kit (true/false), suggestions (массив строк).',
          },
        ],
      },
      'contents': contents,
      'generationConfig': {
        'responseMimeType': 'application/json',
        if (withSchema) 'responseSchema': _replySchema,
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
