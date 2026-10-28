import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/chat_api.dart';
import '../config/chat_model_config.dart';
import '../constants/app_colors.dart';
import '../models/chat_message.dart';
import '../models/transaction.dart';
import '../services/transaction_service.dart';

class AiChatPage extends StatefulWidget {
  final VoidCallback? onDataChanged;

  const AiChatPage({super.key, this.onDataChanged});

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  final ChatApi _chatApi = ChatApi();
  final TransactionService _transactions = TransactionService();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  final List<String> _suggestions = [
    '分析我本月支出结构',
    '有哪些地方可以省钱？',
    '帮我总结本月收支情况',
    '我的消费习惯有什么特点？',
  ];

  bool _loading = false;
  bool _includeContext = true;
  bool _checkingStatus = true;

  @override
  void initState() {
    super.initState();
    _checkStatus();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final history = await _chatApi.fetchHistory();
      if (!mounted || _messages.isNotEmpty) return;
      setState(() => _messages
        ..clear()
        ..addAll(history.where((message) => message.content.isNotEmpty || message.proposal != null)));
    } catch (_) {}
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    try {
      final status = await _chatApi.fetchStatus();
      if (!mounted) return;
      ChatModelConfig.applyProviders(status.providers);
      setState(() => _checkingStatus = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _checkingStatus = false);
    }
  }

  Future<void> _sendMessage([String? preset]) async {
    final text = (preset ?? _inputController.text).trim();
    if (text.isEmpty || _loading) return;

    setState(() {
      _messages.add(ChatMessage(role: ChatRole.user, content: text));
      _loading = true;
      _inputController.clear();
    });
    _scrollToBottom();

    try {
      final now = DateTime.now();
      final history = _includeContext
          ? _messages
          : _messages.where((message) => message.role == ChatRole.user).toList();
      final turn = await _chatApi.sendMessage(
        messages: history,
        includeContext: _includeContext,
        year: now.year,
        month: now.month,
        provider: ChatModelConfig.selection.value.providerId,
        model: ChatModelConfig.selection.value.modelId,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(
          ChatMessage(
            id: turn.assistantMessageId,
            role: ChatRole.assistant,
            content: turn.reply,
            proposal: turn.proposal,
          ),
        );
      });
    } catch (error) {
      if (!mounted) return;
      final message = error is ApiException
          ? error.message
          : 'AI 回复失败，请稍后重试';
      setState(() {
        _messages.removeLast();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _clearChat() async {
    setState(() => _messages.clear());
    try {
      await _chatApi.clearHistory();
    } catch (_) {}
  }

  Future<void> _confirmProposal(int index) async {
    final message = _messages[index];
    final proposal = message.proposal;
    if (proposal == null || proposal.applied || proposal.categoryId <= 0) return;
    try {
      final categories = await _transactions.getCategories();
      TransactionCategory? category;
      for (final item in categories) {
        if (item.id == proposal.categoryId) {
          category = item;
          break;
        }
      }
      if (category == null) {
        throw ApiException(400, '分类不存在，请重新说一次');
      }
      await _transactions.addTransaction(
        title: proposal.title,
        category: category,
        amount: proposal.amount,
        type: proposal.isExpense ? TransactionType.expense : TransactionType.income,
        date: DateTime.tryParse(proposal.date),
      );
      widget.onDataChanged?.call();
      if (message.id != null) {
        await _chatApi.markProposalApplied(message.id!);
      }
      if (!mounted) return;
      setState(() {
        _messages[index] = message.copyWith(proposal: proposal.copyWith(applied: true));
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已记入账单')));
    } catch (error) {
      if (!mounted) return;
      final text = error is ApiException ? error.message : '记账失败，请稍后重试';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.of(context).bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (!_checkingStatus) _buildConfigWarning(),
            Expanded(child: _buildMessageList()),
            if (_messages.isEmpty) _buildSuggestions(),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final canPop = Navigator.canPop(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(canPop ? 4 : 20, 16, 12, 8),
      child: Row(
        children: [
          if (canPop)
            IconButton(
              tooltip: '返回',
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.arrow_back, color: AppColors.of(context).textPrimary),
            ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.of(context).addBtnBg.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.auto_awesome, color: AppColors.of(context).addBtnBg),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI 记账助手',
                  style: TextStyle(
                    color: AppColors.of(context).textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                ValueListenableBuilder<ChatSelection>(
                  valueListenable: ChatModelConfig.selection,
                  builder: (context, _, _) {
                    final modelName = ChatModelConfig.current.name;
                    return Text(
                      _includeContext
                          ? '已带入本月账单 · $modelName'
                          : '未带入账单 · $modelName',
                      style: TextStyle(
                        color: _includeContext
                            ? AppColors.of(context).addBtnBg
                            : AppColors.of(context).textTertiary,
                        fontSize: 12,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          _ContextToggle(
            enabled: _includeContext,
            onPressed: () => setState(() => _includeContext = !_includeContext),
          ),
          IconButton(
            tooltip: '清空对话',
            onPressed: _messages.isEmpty ? null : _clearChat,
            icon: Icon(Icons.delete_outline, color: AppColors.of(context).textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigWarning() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        ChatModelConfig.selection,
        ChatModelConfig.providers,
      ]),
      builder: (context, _) {
        final provider = ChatModelConfig.selectedProvider;
        if (provider == null || provider.configured) {
          return const SizedBox.shrink();
        }
        final keyName = provider.keyEnv.isEmpty ? '对应的 API Key' : provider.keyEnv;
        return Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.of(context).expenseRed.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.of(context).expenseRed.withValues(alpha: 0.3)),
          ),
          child: Text(
            '${provider.name} API Key 未配置。请在 server/.env 中设置 $keyName 后重启后端。',
            style: TextStyle(color: AppColors.of(context).textSecondary, fontSize: 12),
          ),
        );
      },
    );
  }

  Widget _buildMessageList() {
    if (_checkingStatus) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.of(context).addBtnBg),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.smart_toy_outlined,
                size: 64,
                color: AppColors.of(context).textTertiary.withValues(alpha: 0.5),
              ),
              SizedBox(height: 16),
              Text(
                '你好，我是 AI 记账助手',
                style: TextStyle(
                  color: AppColors.of(context).textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '可以分析收支，也可以直接说：帮我记一笔午餐 28 元。',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.of(context).textTertiary, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(20, 8, 20, 16),
      itemCount: _messages.length + (_loading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) {
          return _buildTypingIndicator();
        }
        return _MessageBubble(
          message: _messages[index],
          onConfirm: _messages[index].proposal == null
              ? null
              : () => _confirmProposal(index),
        );
      },
    );
  }

  Widget _buildSuggestions() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final suggestion in _suggestions)
            ActionChip(
              label: Text(suggestion),
              labelStyle: TextStyle(color: AppColors.of(context).textSecondary, fontSize: 12),
              backgroundColor: AppColors.of(context).bgSecondary,
              side: BorderSide(color: AppColors.of(context).divider.withValues(alpha: 0.5)),
              onPressed: _loading ? null : () => _sendMessage(suggestion),
            ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.of(context).navBar,
        border: Border(top: BorderSide(color: AppColors.of(context).divider, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.of(context).bgSecondary,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _inputController,
                enabled: !_loading,
                maxLines: 3,
                minLines: 1,
                style: TextStyle(color: AppColors.of(context).textPrimary, fontSize: 15),
                decoration: InputDecoration(
                  hintText: '问我任何记账相关的问题...',
                  hintStyle: TextStyle(color: AppColors.of(context).textTertiary),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          SizedBox(width: 8),
          Material(
            color: AppColors.of(context).addBtnBg,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              onTap: _loading ? null : () => _sendMessage(),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                child: _loading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(Icons.send_rounded, color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.of(context).bgSecondary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SizedBox(
              width: 48,
              height: 16,
              child: Center(
                child: Text(
                  '...',
                  style: TextStyle(
                    color: AppColors.of(context).textTertiary,
                    fontSize: 18,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContextToggle extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPressed;

  const _ContextToggle({
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final color = enabled ? colors.addBtnBg : colors.textTertiary;
    return Tooltip(
      message: enabled ? '关闭后不再带入本月账单' : '打开后带入本月账单',
      child: Material(
        color: enabled ? colors.addBtnBg.withValues(alpha: 0.16) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: enabled ? colors.addBtnBg : colors.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  enabled ? Icons.analytics : Icons.analytics_outlined,
                  size: 18,
                  color: color,
                ),
                const SizedBox(width: 4),
                Text(
                  enabled ? '本月账单' : '不带账单',
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onConfirm;

  const _MessageBubble({required this.message, this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;

    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.of(context).addBtnBg.withValues(alpha: 0.2),
              child: Icon(Icons.auto_awesome, size: 16, color: AppColors.of(context).addBtnBg),
            ),
            SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser ? AppColors.of(context).addBtnBg : AppColors.of(context).bgSecondary,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                  ),
                  child: Text(
                    message.content,
                    style: TextStyle(
                      color: isUser ? Colors.white : AppColors.of(context).textPrimary,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                ),
                if (message.proposal != null) ...[
                  SizedBox(height: 8),
                  _ProposalCard(proposal: message.proposal!, onConfirm: onConfirm),
                ],
              ],
            ),
          ),
          if (isUser) ...[
            SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.of(context).bgCard,
              child: Icon(Icons.person, size: 16, color: AppColors.of(context).textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProposalCard extends StatelessWidget {
  final RecordProposal proposal;
  final VoidCallback? onConfirm;

  const _ProposalCard({required this.proposal, this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final sign = proposal.isExpense ? '-' : '+';
    return Container(
      padding: EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: colors.bgSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.divider.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            proposal.title,
            style: TextStyle(color: colors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 4),
          Text(
            '${proposal.categoryName} · $sign¥${proposal.amount.toStringAsFixed(2)} · ${proposal.date}',
            style: TextStyle(color: colors.textSecondary, fontSize: 12),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: proposal.applied ? null : onConfirm,
              child: Text(proposal.applied ? '已记入' : '记入账单'),
            ),
          ),
        ],
      ),
    );
  }
}
