import '../models/chat_message.dart';
import 'api_client.dart';

class ChatApi {
  ChatApi({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<ChatStatus> fetchStatus() async {
    final row = await _client.getJson('/api/chat/status');
    return ChatStatus.fromJson(row);
  }

  Future<String> sendMessage({
    required List<ChatMessage> messages,
    bool includeContext = true,
    int? year,
    int? month,
  }) async {
    final row = await _client.postJson('/api/chat', {
      'messages': messages.map((m) => m.toJson()).toList(),
      'include_context': includeContext,
      'year': ?year,
      'month': ?month,
    });
    return row['reply'] as String;
  }
}

class ChatStatus {
  final bool configured;
  final String model;

  const ChatStatus({
    required this.configured,
    required this.model,
  });

  factory ChatStatus.fromJson(Map<String, dynamic> json) {
    return ChatStatus(
      configured: json['configured'] as bool,
      model: json['model'] as String,
    );
  }
}
