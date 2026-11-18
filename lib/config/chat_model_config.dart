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

  // 初始为空列表，完全依赖后端 /api/chat/status 返回的 provider catalog
  static final ValueNotifier<List<ChatProviderOption>> providers =
      ValueNotifier(const []);
  static final ValueNotifier<ChatSelection> selection = ValueNotifier(
    const ChatSelection(providerId: '', modelId: ''),
  );

  static ChatProviderOption? get selectedProvider {
    final selected = selection.value;
    for (final provider in providers.value) {
      if (provider.id == selected.providerId) return provider;
    }
    return null;
  }

  /// 从当前 providers 列表中找到当前选择的模型；若找不到则返回第一个可用模型
  static ChatModelOption? get current {
    final selected = selection.value;
    // 精确匹配
    for (final provider in providers.value) {
      if (provider.id != selected.providerId) continue;
      for (final model in provider.models) {
        if (model.id == selected.modelId) return model;
      }
    }
    // 回退：第一个可用 provider 的第一个模型
    for (final provider in providers.value) {
      if (provider.available && provider.models.isNotEmpty) {
        return provider.models.first;
      }
    }
    return null;
  }

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = ChatSelection(
      providerId: prefs.getString(_providerKey) ?? '',
      modelId: prefs.getString(_modelKey) ?? '',
    );
    // 如果后端 providers 已加载，立即校验
    final resolved = _known(saved, providers.value);
    if (resolved != null) {
      selection.value = resolved;
    }
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

  /// 应用后端返回的 providers 列表，并校验当前选中是否有效
  static void applyProviders(List<ChatProviderOption> next) {
    if (next.isEmpty) return;
    providers.value = next;
    final resolved = _known(selection.value, next);
    if (resolved != null && resolved != selection.value) {
      selection.value = resolved;
    }
  }

  static ChatSelection? _known(ChatSelection saved, List<ChatProviderOption> catalog) {
    if (saved.providerId.isNotEmpty && saved.modelId.isNotEmpty) {
      for (final provider in catalog) {
        if (!provider.available || provider.id != saved.providerId) continue;
        for (final model in provider.models) {
          if (model.id == saved.modelId) return saved;
        }
      }
    }
    // 回退：第一个可用 provider 的第一个模型
    for (final provider in catalog) {
      if (provider.available && provider.models.isNotEmpty) {
        return ChatSelection(providerId: provider.id, modelId: provider.models.first.id);
      }
    }
    return null;
  }
}
