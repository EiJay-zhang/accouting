import '../models/transaction.dart';
import 'api_client.dart';

enum ReportPeriod { week, month, year }

class ReportApi {
  ReportApi({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<CategoryReport> fetchCategoryReport({
    required ReportPeriod period,
    int? year,
    int? month,
    String? anchor,
  }) async {
    final row = await _client.getJson(
      '/api/reports/categories',
      query: _periodQuery(period, year: year, month: month, anchor: anchor),
    );
    return CategoryReport.fromJson(row);
  }

  Future<MonthlyTrend> fetchTrend({
    required ReportPeriod period,
    int? year,
    int? month,
    String? anchor,
  }) async {
    final row = await _client.getJson(
      '/api/reports/trend',
      query: _periodQuery(period, year: year, month: month, anchor: anchor),
    );
    return MonthlyTrend.fromJson(row);
  }

  Map<String, String> _periodQuery(
    ReportPeriod period, {
    int? year,
    int? month,
    String? anchor,
  }) {
    final query = <String, String>{'period': period.name};
    if (year != null) query['year'] = '$year';
    if (month != null) query['month'] = '$month';
    if (anchor != null) query['anchor'] = anchor;
    return query;
  }

  Future<void> saveBudget({
    required int categoryId,
    required int year,
    required int month,
    required double amount,
    ReportPeriod scope = ReportPeriod.month,
    String? anchor,
  }) {
    return _client
        .putJson('/api/budgets', {
          'category_id': categoryId,
          'year': year,
          'month': month,
          'amount': amount,
          'scope': scope.name,
          'anchor': ?anchor,
        })
        .then((_) {});
  }
}

class CategoryReportItem {
  final TransactionCategory category;
  final double income;
  final double expense;
  final int transactionCount;
  final double? budget;

  const CategoryReportItem({
    required this.category,
    required this.income,
    required this.expense,
    required this.transactionCount,
    this.budget,
  });

  factory CategoryReportItem.fromJson(Map<String, dynamic> json) {
    final rawBudget = json['budget'];
    return CategoryReportItem(
      category: TransactionCategory.fromJson(
        json['category'] as Map<String, dynamic>,
      ),
      income: (json['income'] as num).toDouble(),
      expense: (json['expense'] as num).toDouble(),
      transactionCount: json['transaction_count'] as int,
      budget: rawBudget is num ? rawBudget.toDouble() : null,
    );
  }

  double get total => income + expense;
}

class CategoryReport {
  final int year;
  final int month;
  final double income;
  final double expense;
  final List<CategoryReportItem> categories;

  const CategoryReport({
    required this.year,
    required this.month,
    required this.income,
    required this.expense,
    required this.categories,
  });

  factory CategoryReport.fromJson(Map<String, dynamic> json) {
    final items = (json['categories'] as List<dynamic>)
        .map(
          (item) => CategoryReportItem.fromJson(item as Map<String, dynamic>),
        )
        .toList();

    return CategoryReport(
      year: json['year'] as int,
      month: json['month'] as int,
      income: (json['income'] as num).toDouble(),
      expense: (json['expense'] as num).toDouble(),
      categories: items,
    );
  }

  double get total => income - expense;
}

class TrendPoint {
  final int year;
  final int month;
  final int day;
  final String label;
  final double income;
  final double expense;

  const TrendPoint({
    required this.year,
    required this.month,
    required this.income,
    required this.expense,
    this.day = 1,
    this.label = '',
  });

  factory TrendPoint.fromJson(Map<String, dynamic> json) {
    return TrendPoint(
      year: json['year'] as int,
      month: json['month'] as int,
      day: json['day'] as int? ?? 1,
      label: json['label'] as String? ?? '',
      income: (json['income'] as num).toDouble(),
      expense: (json['expense'] as num).toDouble(),
    );
  }
}

class MonthlyTrend {
  final List<TrendPoint> points;
  final double incomeDelta;
  final double expenseDelta;

  const MonthlyTrend({
    required this.points,
    required this.incomeDelta,
    required this.expenseDelta,
  });

  factory MonthlyTrend.fromJson(Map<String, dynamic> json) {
    final points = (json['points'] as List<dynamic>)
        .map((item) => TrendPoint.fromJson(item as Map<String, dynamic>))
        .toList();
    return MonthlyTrend(
      points: points,
      incomeDelta: (json['income_delta'] as num).toDouble(),
      expenseDelta: (json['expense_delta'] as num).toDouble(),
    );
  }
}
