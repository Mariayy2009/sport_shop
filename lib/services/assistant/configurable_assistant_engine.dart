import 'package:http/http.dart' as http;

import '../../models/chat_message.dart';
import 'ai_key_store.dart';
import 'assistant_engine.dart';
import 'claude_assistant_engine.dart';
import 'gemini_assistant_engine.dart';

/// Какая модель сейчас отвечает в чате.
enum AiProvider {
  local('Без нейросети'),
  gemini('Gemini'),
  claude('Claude');

  const AiProvider(this.label);

  final String label;
}

/// Выбирает движок под текущие настройки:
///   1. ключ Gemini, введённый в приложении (или заданный при сборке
///      через --dart-define=GEMINI_API_KEY=...) — бесплатный тариф;
///   2. ключ Claude, заданный при сборке;
///   3. локальные правила — работают всегда и без сети.
/// Локальный движок остаётся запасным для обеих моделей.
class ConfigurableAssistantEngine implements AssistantEngine {
  ConfigurableAssistantEngine({
    required AssistantEngine local,
    required AiKeyStore keyStore,
    AssistantAiConfig claudeConfig = const AssistantAiConfig(),
    http.Client? client,
  })  : _local = local,
        _keyStore = keyStore,
        _claudeConfig = claudeConfig,
        _client = client;

  static const String _buildGeminiKey = String.fromEnvironment('GEMINI_API_KEY');

  final AssistantEngine _local;
  final AiKeyStore _keyStore;
  final AssistantAiConfig _claudeConfig;
  final http.Client? _client;

  Future<String?> _geminiKey() async {
    final String? saved = await _keyStore.readGeminiKey();
    if (saved != null && saved.isNotEmpty) return saved;
    return _buildGeminiKey.isEmpty ? null : _buildGeminiKey;
  }

  Future<AiProvider> currentProvider() async {
    if (await _geminiKey() != null) return AiProvider.gemini;
    return _claudeConfig.isEnabled ? AiProvider.claude : AiProvider.local;
  }

  Future<void> setGeminiKey(String? key) => _keyStore.saveGeminiKey(key?.trim());

  /// Проверяет ключ запросом к Google. null — ключ рабочий,
  /// иначе текст ошибки.
  Future<String?> checkGeminiKey(String key) =>
      GeminiAssistantEngine.checkKey(key.trim(), client: _client);

  @override
  Future<AssistantReply> reply(
    AssistantContext context,
    List<ChatMessage> history,
  ) async {
    final String? geminiKey = await _geminiKey();
    final AssistantEngine engine = geminiKey != null
        ? GeminiAssistantEngine(apiKey: geminiKey, fallback: _local, client: _client)
        : _claudeConfig.isEnabled
            ? ClaudeAssistantEngine(
                config: _claudeConfig,
                fallback: _local,
                client: _client,
              )
            : _local;
    return engine.reply(context, history);
  }
}
