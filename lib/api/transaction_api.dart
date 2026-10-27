import '../models/transaction.dart';
import 'api_client.dart';

class TransactionApi {
  TransactionApi({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<TransactionCategory>> fetchCategories({
    TransactionType? type,
  }) async {
    final rows = await _client.getJsonList(
      '/api/categories',
      query: type == null ? null : {'type': type.name},
    );
    return rows
        .map((row) => TransactionCategory.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<TransactionCategory> createCategory({
    required String name,
    required String icon,
    required String colorHex,
    required TransactionType type,
  }) async {
    final row = await _client.postJson('/api/categories', {
      'name': name,
      'icon': icon,
      'color': colorHex,
      'type': type.name,
    });
    return TransactionCategory.fromJson(row);
  }

  Future<TransactionCategory> updateCategory({
    required int id,
    required String name,
    required String icon,
    required String colorHex,
  }) async {
    final row = await _client.putJson('/api/categories/$id', {
      'name': name,
      'icon': icon,
      'color': colorHex,
    });
    return TransactionCategory.fromJson(row);
  }

  Future<void> deleteCategory(int id) {
    return _client.delete('/api/categories/$id');
  }

  Future<List<CategoryTag>> fetchTags({int? categoryId}) async {
    final rows = await _client.getJsonList(
      '/api/tags',
      query: categoryId == null ? null : {'category_id': '$categoryId'},
    );
    return rows
        .map((row) => CategoryTag.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<CategoryTag> createTag({
    required int categoryId,
    required String name,
  }) async {
    final row = await _client.postJson('/api/tags', {
      'category_id': categoryId,
      'name': name,
    });
    return CategoryTag.fromJson(row);
  }

  Future<CategoryTag> updateTag({
    required int id,
    required String name,
  }) async {
    final row = await _client.putJson('/api/tags/$id', {'name': name});
    return CategoryTag.fromJson(row);
  }

  Future<void> deleteTag(int id) {
    return _client.delete('/api/tags/$id');
  }

  Future<List<Transaction>> fetchTransactions({
    required int year,
    required int month,
  }) async {
    final rows = await _client.getJsonList(
      '/api/transactions',
      query: {
        'year': '$year',
        'month': '$month',
      },
    );
    return rows
        .map((row) => Transaction.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<MonthlySummary> fetchSummary({
    required int year,
    required int month,
  }) async {
    final row = await _client.getJson(
      '/api/transactions/summary',
      query: {
        'year': '$year',
        'month': '$month',
      },
    );
    return MonthlySummary.fromJson(row);
  }

  Future<Transaction> createTransaction({
    required String title,
    required int categoryId,
    required double amount,
    required TransactionType type,
    DateTime? date,
  }) async {
    final row = await _client.postJson('/api/transactions', {
      'title': title,
      'category_id': categoryId,
      'amount': amount,
      'type': type.name,
      if (date != null) 'date': _formatDate(date),
    });
    return Transaction.fromJson(row);
  }

  Future<Transaction> updateTransaction({
    required int id,
    required String title,
    required int categoryId,
    required double amount,
    required TransactionType type,
    required DateTime date,
  }) async {
    final row = await _client.putJson('/api/transactions/$id', {
      'title': title,
      'category_id': categoryId,
      'amount': amount,
      'type': type.name,
      'date': _formatDate(date),
    });
    return Transaction.fromJson(row);
  }

  Future<void> deleteTransaction(int id) {
    return _client.delete('/api/transactions/$id');
  }

  String _formatDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

class MonthlySummary {
  final int year;
  final int month;
  final double income;
  final double expense;
  final double total;

  const MonthlySummary({
    required this.year,
    required this.month,
    required this.income,
    required this.expense,
    required this.total,
  });

  factory MonthlySummary.fromJson(Map<String, dynamic> json) {
    return MonthlySummary(
      year: json['year'] as int,
      month: json['month'] as int,
      income: (json['income'] as num).toDouble(),
      expense: (json['expense'] as num).toDouble(),
      total: (json['total'] as num).toDouble(),
    );
  }
}
