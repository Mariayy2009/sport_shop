import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../models/chat_message.dart';
import '../../models/product.dart';
import '../../models/sport.dart';
import '../../models/user_sizes.dart';
import '../size_advisor.dart';
import 'assistant_engine.dart';

/// Настройки подключения к языковой модели. Задаются при сборке:
///
///   flutter run --dart-define=ANTHROPIC_API_KEY=sk-ant-...
///
/// ВАЖНО: ключ, вшитый в приложение, можно извлечь из APK. Так делаем
/// только на этапе разработки. В боевой версии приложение обращается
/// к своему серверу (AI_API_URL), а ключ хранится на сервере.
class AssistantAiConfig {
  const AssistantAiConfig({
    this.apiKey = const String.fromEnvironment('ANTHROPIC_API_KEY'),
    this.apiUrl = const String.fromEnvironment(
      'AI_API_URL',
      defaultValue: 'https://api.anthropic.com/v1/messages',
    ),
    this.model = const String.fromEnvironment(
      'AI_MODEL',
      defaultValue: 'claude-opus-5-5',
    ),
  });

  final String apiKey;
  final String apiUrl;
  final String model;

  static const String _defaultUrl = 'https://api.anthropic.com/v1/messages';

  /// Модель доступна: задан ключ или адрес собственного сервера-посредника.
  bool get isEnabled => apiKey.isNotEmpty || apiUrl != _defaultUrl;
}

/// Помощник на языковой модели Claude (Messages API).
///
/// Модель получает каталог и профиль покупателя в системном сообщении
/// и возвращает структурированный ответ: текст + id товаров с причинами.
/// Товары, которых нет в каталоге, отбрасываются — помощник не может
/// «придумать» товар. При любой ошибке сети отвечает [_fallback].
class ClaudeAssistantEngine implements AssistantEngine {
  ClaudeAssistantEngine({
    required AssistantAiConfig config,
    required AssistantEngine fallback,
    http.Client? client,
    SizeAdvisor sizeAdvisor = const SizeAdvisor(),
  })  : _config = config,
        _fallback = fallback,
        _client = client ?? http.Client(),
        _sizeAdvisor = sizeAdvisor;

  final AssistantAiConfig _config;
  final AssistantEngine _fallback;
  final http.Client _client;
  final SizeAdvisor _sizeAdvisor;

  static const Duration _timeout = Duration(seconds: 60);

  /// В запрос уходит только хвост диалога — этого достаточно для контекста.
  static const int historyLimit = 20;

  static const String instructions = '''
Ты — персональный помощник интернет-магазина спортивных товаров SPORT (Казахстан, цены в тенге ₸). Ты общаешься с покупателем в мобильном приложении и помогаешь ему принять решение о покупке: собрать комплект экипировки под вид спорта и уровень, выбрать товар под бюджет, сравнить варианты, определиться с размером.

Что важно покупателю:
- Советуй только товары из каталога ниже и ссылайся на них по id — приложение покажет карточки само, поэтому не пересказывай в тексте цену и название каждого товара. Если подходящего товара в каталоге нет, честно скажи об этом и предложи ближайшую замену.
- Объясняй выбор: для каждого товара в picks дай короткую причину (одно предложение), связанную с ситуацией покупателя — его видом спорта, стажем, параметрами, бюджетом.
- Учитывай наличие (stock = 0 — товара нет) и бюджет, если он назван. Если комплект не укладывается в бюджет, скажи, на чём нельзя экономить (обувь, защита), а что можно докупить позже.
- Размер одежды и обуви бери из профиля покупателя и из списка sizes товара. Если нужных данных в профиле нет — попроси их заполнить, а не угадывай.
- Если в запросе не хватает главного (например, вида спорта, а в профиле его нет) — задай один уточняющий вопрос вместо подборки.
- Не давай медицинских рекомендаций: при жалобах на боль или травму советуй обратиться к врачу, а экипировку предлагай как защиту, не как лечение.

Формат ответа: message — живой разговорный текст на русском, на «ты», 2–5 предложений без Markdown-разметки; picks — до 6 товаров (пустой список, если товары не нужны); is_kit — true, когда picks образуют комплект, который имеет смысл купить целиком; suggestions — 2–3 коротких варианта следующего вопроса от лица покупателя.''';

  static const Map<String, Object?> _replySchema = {
    'type': 'object',
    'properties': {
      'message': {'type': 'string'},
      'picks': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'product_id': {'type': 'integer'},
            'reason': {'type': 'string'},
          },
          'required': ['product_id', 'reason'],
          'additionalProperties': false,
        },
      },
      'is_kit': {'type': 'boolean'},
      'suggestions': {
        'type': 'array',
        'items': {'type': 'string'},
      },
    },
    'required': ['message', 'picks', 'is_kit', 'suggestions'],
    'additionalProperties': false,
  };

  @override
  Future<AssistantReply> reply(
    AssistantContext context,
    List<ChatMessage> history,
  ) async {
    AssistantReply? reply;
    try {
      final http.Response response = await _client
          .post(
            Uri.parse(_config.apiUrl),
            headers: {
              'content-type': 'application/json',
              'anthropic-version': '2026-10-21',
              // Запасная модель на случай отказа основной (см. fallbacks ниже).
              'anthropic-beta': 'server-side-fallback-2026-07-01',
              if (_config.apiKey.isNotEmpty) 'x-api-key': _config.apiKey,
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
        debugPrint('AI API: HTTP ${response.statusCode} ${response.body}');
      }
    } on Exception catch (error) {
      // Нет сети, таймаут, неожиданный формат — ответит локальный движок.
      debugPrint('AI API недоступен: $error');
    }
    return reply ?? await _fallback.reply(context, history);
  }

  Map<String, Object?> _buildRequest(
    AssistantContext context,
    List<ChatMessage> history,
  ) {
    return {
      'model': _config.model,
      'max_tokens': 8000,
      // Инструкции и каталог одинаковы между запросами — кешируем их.
      'cache_control': {'type': 'ephemeral'},
      'fallbacks': 'default',
      'output_config': {
        // Для чата важна скорость ответа.
        'effort': 'low',
        'format': {'type': 'json_schema', 'schema': _replySchema},
      },
      'system': [
        {
          'type': 'text',
          'text': '$instructions\n\nКаталог магазина (JSON):\n'
              '${jsonEncode(catalogJson(context))}',
        },
        {'type': 'text', 'text': profileText(context)},
      ],
      'messages': _messages(history),
    };
  }

  static List<Map<String, Object?>> catalogJson(AssistantContext context) => [
        for (final Product product in context.catalog)
          {
            'id': product.id,
            'name': product.name,
            'sport': product.sportName,
            'category': product.categoryName,
            'price': product.price.round(),
            'brand': product.brand,
            'material': product.material,
            'rating': product.rating,
            'sizes': product.availableSizes,
            'stock': product.stock,
            'description': product.description,
          },
      ];

  static String profileText(AssistantContext context) {
    final UserSizes? sizes = context.sizes;
    final Sport? sport = context.sportById(sizes?.sportId);
    if (context.user == null) {
      return 'Покупатель не вошёл в аккаунт, профиля нет.';
    }
    String orUnknown(Object? value, [String suffix = '']) =>
        value == null ? 'не указано' : '$value$suffix';
    return 'Профиль покупателя:\n'
        '- имя: ${context.user!.greetingName}\n'
        '- вид спорта: ${orUnknown(sport?.name)}\n'
        '- стаж: ${orUnknown(sizes?.experienceYears, ' лет')}'
        '${sizes?.experienceYears == null ? '' : ' (уровень: ${sizes!.level.label})'}\n'
        '- рост: ${orUnknown(sizes?.height, ' см')}\n'
        '- вес: ${orUnknown(sizes?.weight, ' кг')}\n'
        '- размер одежды: ${orUnknown(sizes?.clothingSize)}\n'
        '- размер обуви (EU): ${orUnknown(sizes?.shoeSize)}';
  }

  /// Диалог в формате API: начинается с сообщения пользователя.
  static List<Map<String, Object?>> _messages(List<ChatMessage> history) {
    final List<ChatMessage> tail = history.length > historyLimit
        ? history.sublist(history.length - historyLimit)
        : history;
    final List<Map<String, Object?>> messages = [];
    for (final ChatMessage message in tail) {
      if (messages.isEmpty && !message.isUser) continue;
      final String shown = message.picks.isEmpty
          ? ''
          : '\n[показаны товары id: '
              '${message.picks.map((pick) => pick.product.id).join(', ')}]';
      messages.add({
        'role': message.isUser ? 'user' : 'assistant',
        'content': '${message.text}$shown',
      });
    }
    return messages;
  }

  /// null — ответ нельзя использовать (обрезан или пуст), нужен запасной движок.
  AssistantReply? _parse(Map<String, Object?> body, AssistantContext context) {
    final String? stopReason = body['stop_reason'] as String?;
    if (stopReason == 'refusal') {
      return const AssistantReply(
        text: 'С этим вопросом я помочь не могу. Давай вернёмся к экипировке: '
            'могу собрать комплект, подобрать размер или сравнить товары.',
      );
    }
    if (stopReason == 'max_tokens') return null;

    final StringBuffer json = StringBuffer();
    for (final Object? block in (body['content'] as List<Object?>? ?? const [])) {
      if (block is Map<String, Object?> && block['type'] == 'text') {
        json.write(block['text']);
      }
    }
    if (json.isEmpty) return null;
    final Map<String, Object?> data =
        jsonDecode(json.toString()) as Map<String, Object?>;

    return replyFromData(data, context, _sizeAdvisor);
  }

  /// Ответ модели (message / picks / is_kit / suggestions) → ответ помощника.
  /// Общий для всех языковых моделей. null — ответ пуст.
  static AssistantReply? replyFromData(
    Map<String, Object?> data,
    AssistantContext context,
    SizeAdvisor sizeAdvisor,
  ) {
    final List<ProductPick> picks = [];
    final Set<int> seen = {};
    for (final Object? item in (data['picks'] as List<Object?>? ?? const [])) {
      if (item is! Map<String, Object?>) continue;
      final int? id = (item['product_id'] as num?)?.toInt();
      // Модель могла ошибиться в id — показываем только реальные товары.
      final Product? product = context.productById(id);
      if (product == null || !seen.add(product.id!)) continue;
      picks.add(ProductPick(
        product: product,
        reason: (item['reason'] as String?) ?? '',
        size: sizeAdvisor.pickSize(product, context.sizes),
      ));
    }

    final String message = (data['message'] as String?)?.trim() ?? '';
    if (message.isEmpty && picks.isEmpty) return null;
    return AssistantReply(
      text: message,
      picks: picks,
      isKit: data['is_kit'] == true && picks.length > 1,
      suggestions: [
        for (final Object? item
            in (data['suggestions'] as List<Object?>? ?? const []).take(3))
          if (item is String && item.trim().isNotEmpty) item.trim(),
      ],
    );
  }
}
