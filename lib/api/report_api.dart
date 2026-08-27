import '../models/transaction.dart';
import 'api_client.dart';

class ReportApi {
  ReportApi({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<CategoryReport> fetchCategoryReport({
    required int year,
    required int month,
  }) async {
    final row = await _client.getJson(
      '/api/reports/categories',
      query: {
        'year': '$year',
        'month': '$month',
      },
    );
    return CategoryReport.fromJson(row);
  }
}

class CategoryReportItem {
  final TransactionCategory category;
  final double income;
  final double expense;
  final int transactionCount;

  const CategoryReportItem({
    required this.category,
    required this.income,
    required this.expense,
    required this.transactionCount,
  });

  factory CategoryReportItem.fromJson(Map<String, dynamic> json) {
    return CategoryReportItem(
      category: TransactionCategory.fromJson(
        json['category'] as Map<String, dynamic>,
      ),
      income: (json['income'] as num).toDouble(),
      expense: (json['expense'] as num).toDouble(),
      transactionCount: json['transaction_count'] as int,
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
