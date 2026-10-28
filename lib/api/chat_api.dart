import '../config/chat_model_config.dart';
import '../models/chat_message.dart';
import 'api_client.dart';

class ChatApi {
  ChatApi({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<ChatStatus> fetchStatus() async {
    final row = await _client.getJson('/api/chat/status');
    return ChatStatus.fromJson(row);
  }

  Future<ChatTurn> sendMessage({
    required List<ChatMessage> messages,
    bool includeContext = true,
    int? year,
    int? month,
    String? provider,
    String? model,
  }) async {
    final row = await _client.postJson('/api/chat', {
      'messages': messages.map((m) => m.toJson()).toList(),
      'include_context': includeContext,
      'year': ?year,
      'month': ?month,
      'provider': ?provider,
      'model': ?model,
    });
    return ChatTurn.fromJson(row);
  }

  Future<List<ChatMessage>> fetchHistory() async {
    final rows = await _client.getJsonList('/api/chat/history');
    return rows
        .map((row) => ChatMessage.fromHistory(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> clearHistory() {
    return _client.delete('/api/chat/history');
  }

  Future<void> markProposalApplied(int messageId) {
    return _client.postJson('/api/chat/messages/$messageId/applied', {}).then((_) {});
  }
}

class ChatTurn {
  final String reply;
  final int? assistantMessageId;
  final RecordProposal? proposal;

  const ChatTurn({
    required this.reply,
    this.assistantMessageId,
    this.proposal,
  });

  factory ChatTurn.fromJson(Map<String, dynamic> json) {
    final rawProposal = json['proposal'];
    return ChatTurn(
      reply: json['reply'] as String? ?? '',
      assistantMessageId: json['assistant_message_id'] as int?,
      proposal: rawProposal is Map
          ? RecordProposal.fromJson(Map<String, dynamic>.from(rawProposal))
          : null,
    );
  }
}

class ChatStatus {
  final bool configured;
  final String provider;
  final String model;
  final List<ChatProviderOption> providers;

  const ChatStatus({
    required this.configured,
    required this.provider,
    required this.model,
    required this.providers,
  });

  factory ChatStatus.fromJson(Map<String, dynamic> json) {
    final rawProviders = json['providers'];
    final providers = rawProviders is List
        ? rawProviders
            .whereType<Map>()
            .map((item) => _providerFromJson(Map<String, dynamic>.from(item)))
            .toList()
        : ChatModelConfig.fallbackProviders;
    return ChatStatus(
      configured: json['configured'] as bool,
      provider: json['provider'] as String? ?? 'deepseek',
      model: json['model'] as String? ?? 'deepseek-flash',
      providers: providers.isEmpty ? ChatModelConfig.fallbackProviders : providers,
    );
  }
}

ChatProviderOption _providerFromJson(Map<String, dynamic> json) {
  final rawModels = json['models'];
  final models = rawModels is List
      ? rawModels.whereType<Map>().map((item) {
          final row = Map<String, dynamic>.from(item);
          return ChatModelOption(
            id: row['id'] as String,
            name: row['name'] as String? ?? row['id'] as String,
            description: row['description'] as String? ?? '',
          );
        }).toList()
      : const <ChatModelOption>[];
  return ChatProviderOption(
    id: json['id'] as String,
    name: json['name'] as String? ?? json['id'] as String,
    available: json['available'] as bool? ?? false,
    configured: json['configured'] as bool? ?? false,
    hint: json['hint'] as String? ?? '',
    keyEnv: json['key_env'] as String? ?? '',
    models: models,
  );
}
