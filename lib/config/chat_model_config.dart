import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatModelOption {
  final String id;
  final String name;
  final String description;

  const ChatModelOption({
    required this.id,
    required this.name,
    required this.description,
  });
}

class ChatProviderOption {
  final String id;
  final String name;
  final bool available;
  final bool configured;
  final String hint;
  final String keyEnv;
  final List<ChatModelOption> models;

  const ChatProviderOption({
    required this.id,
    required this.name,
    required this.available,
    required this.configured,
    required this.hint,
    required this.keyEnv,
    required this.models,
  });
}

class ChatSelection {
  final String providerId;
  final String modelId;

  const ChatSelection({
    required this.providerId,
    required this.modelId,
  });
}

class ChatModelConfig {
  static const _providerKey = 'chat_provider';
  static const _modelKey = 'chat_model';

  static const fallbackProviders = [
    ChatProviderOption(
      id: 'deepseek',
      name: 'DeepSeek',
      available: true,
      configured: true,
      hint: '',
      keyEnv: 'DEEPSEEK_API_KEY',
      models: [
        ChatModelOption(
          id: 'deepseek-flash',
          name: 'DeepSeek Flash',
          description: '回答更快，适合日常记账问答',
        ),
        ChatModelOption(
          id: 'deepseek-v4-pro',
          name: 'DeepSeek V4 Pro',
          description: '分析更细，适合复杂的收支建议',
        ),
      ],
    ),
    ChatProviderOption(
      id: 'kimi',
      name: 'Kimi',
      available: true,
      configured: false,
      hint: '未配置密钥',
      keyEnv: 'KIMI_API_KEY',
      models: [
        ChatModelOption(
          id: 'kimi-k2.6',
          name: 'Kimi K2.6',
          description: '回答更快，适合日常记账问答',
        ),
        ChatModelOption(
          id: 'kimi-k3.1-pro',
          name: 'Kimi K3.1 Pro',
          description: '分析更细，适合复杂的收支建议',
        ),
      ],
    ),
  ];

  static final ValueNotifier<List<ChatProviderOption>> providers =
      ValueNotifier(fallbackProviders);
  static final ValueNotifier<ChatSelection> selection = ValueNotifier(
    const ChatSelection(providerId: 'deepseek', modelId: 'deepseek-flash'),
  );

  static ChatProviderOption? get selectedProvider {
    final selected = selection.value;
    for (final provider in providers.value) {
      if (provider.id == selected.providerId) return provider;
    }
    return null;
  }

  static ChatModelOption get current {
    final selected = selection.value;
    for (final provider in providers.value) {
      if (provider.id != selected.providerId) continue;
      for (final model in provider.models) {
        if (model.id == selected.modelId) return model;
      }
    }
    return fallbackProviders.first.models.first;
  }

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = ChatSelection(
      providerId: prefs.getString(_providerKey) ?? 'deepseek',
      modelId: prefs.getString(_modelKey) ?? fallbackProviders.first.models.first.id,
    );
    selection.value = _known(saved, providers.value) ?? selection.value;
  }

  static Future<void> save(String providerId, String modelId) async {
    final resolved = _known(
      ChatSelection(providerId: providerId, modelId: modelId),
      providers.value,
    );
    if (resolved == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_providerKey, resolved.providerId);
    await prefs.setString(_modelKey, resolved.modelId);
    selection.value = resolved;
  }

  static void applyProviders(List<ChatProviderOption> next) {
    if (next.isEmpty) return;
    providers.value = next;
    final resolved = _known(selection.value, next);
    if (resolved != null && resolved != selection.value) {
      selection.value = resolved;
    }
  }

  static ChatSelection? _known(ChatSelection saved, List<ChatProviderOption> catalog) {
    for (final provider in catalog) {
      if (!provider.available || provider.id != saved.providerId) continue;
      for (final model in provider.models) {
        if (model.id == saved.modelId) return saved;
      }
    }
    for (final provider in catalog) {
      if (provider.available && provider.models.isNotEmpty) {
        return ChatSelection(providerId: provider.id, modelId: provider.models.first.id);
      }
    }
    return null;
  }
}
