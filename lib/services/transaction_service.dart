import '../api/transaction_api.dart';
import '../models/transaction.dart';

class TransactionService {
  TransactionService({TransactionApi? api}) : _api = api ?? TransactionApi();

  final TransactionApi _api;

  Future<List<TransactionCategory>> getCategories({TransactionType? type}) {
    return _api.fetchCategories(type: type);
  }

  Future<TransactionCategory> createCategory({
    required String name,
    required String icon,
    required String colorHex,
    required TransactionType type,
  }) {
    return _api.createCategory(
      name: name,
      icon: icon,
      colorHex: colorHex,
      type: type,
    );
  }

  Future<TransactionCategory> updateCategory({
    required int id,
    required String name,
    required String icon,
    required String colorHex,
  }) {
    return _api.updateCategory(
      id: id,
      name: name,
      icon: icon,
      colorHex: colorHex,
    );
  }

  Future<void> deleteCategory(int id) {
    return _api.deleteCategory(id);
  }

  Future<List<CategoryTag>> getTags({int? categoryId}) {
    return _api.fetchTags(categoryId: categoryId);
  }

  Future<CategoryTag> createTag({
    required int categoryId,
    required String name,
  }) {
    return _api.createTag(categoryId: categoryId, name: name);
  }

  Future<CategoryTag> updateTag({
    required int id,
    required String name,
  }) {
    return _api.updateTag(id: id, name: name);
  }

  Future<void> deleteTag(int id) {
    return _api.deleteTag(id);
  }

  Future<HomeData> loadHomeData({DateTime? month}) async {
    final target = month ?? DateTime.now();
    final summary = await _api.fetchSummary(
      year: target.year,
      month: target.month,
    );
    final transactions = await _api.fetchTransactions(
      year: target.year,
      month: target.month,
    );

    return HomeData(
      month: DateTime(target.year, target.month),
      summary: summary,
      groups: groupTransactions(transactions),
    );
  }

  Future<Transaction> addTransaction({
    required String title,
    required TransactionCategory category,
    required double amount,
    required TransactionType type,
    DateTime? date,
  }) {
    return _api.createTransaction(
      title: title,
      categoryId: category.id,
      amount: amount,
      type: type,
      date: date,
    );
  }

  Future<Transaction> updateTransaction({
    required Transaction transaction,
    required String title,
    required TransactionCategory category,
    required double amount,
    required TransactionType type,
    required DateTime date,
  }) {
    return _api.updateTransaction(
      id: transaction.id,
      title: title,
      categoryId: category.id,
      amount: amount,
      type: type,
      date: date,
    );
  }

  Future<void> deleteTransaction(int id) {
    return _api.deleteTransaction(id);
  }
}

class HomeData {
  final DateTime month;
  final MonthlySummary summary;
  final List<TransactionGroup> groups;

  const HomeData({
    required this.month,
    required this.summary,
    required this.groups,
  });
}

List<TransactionGroup> groupTransactions(List<Transaction> transactions) {
  final map = <DateTime, List<Transaction>>{};
  for (final transaction in transactions) {
    final key = DateTime(
      transaction.date.year,
      transaction.date.month,
      transaction.date.day,
    );
    map.putIfAbsent(key, () => []).add(transaction);
  }

  final groups = <TransactionGroup>[];
  for (final entry in map.entries) {
    final income = entry.value
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);
    final expense = entry.value
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);
    groups.add(
      TransactionGroup(
        date: entry.key,
        transactions: entry.value,
        incomeTotal: income,
        expenseTotal: expense,
      ),
    );
  }

  groups.sort((a, b) => b.date.compareTo(a.date));
  return groups;
}
