import '../models/transaction.dart';
import 'api_client.dart';

class ImportPreview {
  final String source;
  final String sourceLabel;
  final int total;
  final int readyCount;
  final int duplicateCount;
  final int skippedCount;
  final List<ImportPreviewItem> items;

  const ImportPreview({
    required this.source,
    required this.sourceLabel,
    required this.total,
    required this.readyCount,
    required this.duplicateCount,
    required this.skippedCount,
    required this.items,
  });

  factory ImportPreview.fromJson(Map<String, dynamic> json) {
    return ImportPreview(
      source: json['source'] as String,
      sourceLabel: json['source_label'] as String,
      total: json['total'] as int,
      readyCount: json['ready_count'] as int,
      duplicateCount: json['duplicate_count'] as int,
      skippedCount: json['skipped_count'] as int,
      items: (json['items'] as List<dynamic>)
          .map((item) => ImportPreviewItem.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ImportPreviewItem {
  final String externalId;
  final String title;
  final double amount;
  final TransactionType type;
  final String date;
  final int? categoryId;
  final String categoryName;
  final bool matched;
  final String counterparty;
  final bool duplicate;
  final bool skipped;
  final String skipReason;

  const ImportPreviewItem({
    required this.externalId,
    required this.title,
    required this.amount,
    required this.type,
    required this.date,
    required this.categoryId,
    required this.categoryName,
    required this.matched,
    required this.counterparty,
    required this.duplicate,
    required this.skipped,
    required this.skipReason,
  });

  bool get canImport => !skipped && !duplicate && categoryId != null;

  factory ImportPreviewItem.fromJson(Map<String, dynamic> json) {
    return ImportPreviewItem(
      externalId: json['external_id'] as String,
      title: json['title'] as String,
      amount: (json['amount'] as num).toDouble(),
      type: json['type'] == 'income' ? TransactionType.income : TransactionType.expense,
      date: json['date'] as String,
      categoryId: json['category_id'] as int?,
      categoryName: json['category_name'] as String? ?? '',
      matched: json['matched'] as bool? ?? false,
      counterparty: json['counterparty'] as String? ?? '',
      duplicate: json['duplicate'] as bool? ?? false,
      skipped: json['skipped'] as bool? ?? false,
      skipReason: json['skip_reason'] as String? ?? '',
    );
  }
}

class ImportResult {
  final int imported;
  final int duplicates;

  const ImportResult({required this.imported, required this.duplicates});

  factory ImportResult.fromJson(Map<String, dynamic> json) {
    return ImportResult(
      imported: json['imported'] as int,
      duplicates: json['duplicates'] as int,
    );
  }
}

class ImportApi {
  ImportApi({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<ImportPreview> preview({
    required List<int> bytes,
    required String filename,
    String? source,
  }) async {
    final row = await _client.postMultipart(
      '/api/imports/preview',
      bytes: bytes,
      filename: filename,
      fields: source == null ? null : {'source': source},
    );
    return ImportPreview.fromJson(row);
  }

  Future<ImportResult> commit({
    required String source,
    required List<ImportPreviewItem> items,
  }) async {
    final row = await _client.postJson('/api/imports/commit', {
      'items': [
        for (final item in items)
          {
            'external_id': item.externalId,
            'title': item.title,
            'amount': item.amount,
            'type': item.type.name,
            'date': item.date,
            'category_id': item.categoryId,
            'source': source,
          },
      ],
    });
    return ImportResult.fromJson(row);
  }
}
