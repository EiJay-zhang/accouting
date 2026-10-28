enum ChatRole { user, assistant }

class RecordProposal {
  final String title;
  final double amount;
  final String type;
  final int categoryId;
  final String categoryName;
  final String date;
  final bool applied;

  const RecordProposal({
    required this.title,
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.categoryName,
    required this.date,
    this.applied = false,
  });

  bool get isExpense => type != 'income';

  RecordProposal copyWith({bool? applied}) {
    return RecordProposal(
      title: title,
      amount: amount,
      type: type,
      categoryId: categoryId,
      categoryName: categoryName,
      date: date,
      applied: applied ?? this.applied,
    );
  }

  factory RecordProposal.fromJson(Map<String, dynamic> json) {
    return RecordProposal(
      title: json['title'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      type: json['type'] as String? ?? 'expense',
      categoryId: json['category_id'] as int? ?? 0,
      categoryName: json['category_name'] as String? ?? '',
      date: json['date'] as String? ?? '',
      applied: json['applied'] as bool? ?? false,
    );
  }
}

class ChatMessage {
  final int? id;
  final ChatRole role;
  final String content;
  final RecordProposal? proposal;

  const ChatMessage({
    this.id,
    required this.role,
    required this.content,
    this.proposal,
  });

  ChatMessage copyWith({int? id, RecordProposal? proposal}) {
    return ChatMessage(
      id: id ?? this.id,
      role: role,
      content: content,
      proposal: proposal ?? this.proposal,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'role': role.name,
      'content': content,
    };
  }

  factory ChatMessage.fromHistory(Map<String, dynamic> json) {
    final rawProposal = json['proposal'];
    RecordProposal? proposal;
    if (rawProposal is Map) {
      proposal = RecordProposal.fromJson(Map<String, dynamic>.from(rawProposal));
      if (json['applied'] == true) {
        proposal = proposal.copyWith(applied: true);
      }
    }
    return ChatMessage(
      id: json['id'] as int?,
      role: json['role'] == 'assistant' ? ChatRole.assistant : ChatRole.user,
      content: json['content'] as String? ?? '',
      proposal: proposal,
    );
  }
}
