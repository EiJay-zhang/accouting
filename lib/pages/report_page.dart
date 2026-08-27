import 'package:flutter/material.dart';

import '../api/report_api.dart';
import '../constants/app_colors.dart';
import '../widgets/report_charts.dart';
import '../widgets/transaction_widgets.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => ReportPageState();
}

class ReportPageState extends State<ReportPage> {
  final ReportApi _api = ReportApi();
  late DateTime _selectedMonth;
  late Future<CategoryReport> _reportFuture;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
    _loadReport();
  }

  void refresh() {
    _loadReport();
  }

  void _loadReport() {
    setState(() {
      _reportFuture = _api.fetchCategoryReport(
        year: _selectedMonth.year,
        month: _selectedMonth.month,
      );
    });
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta);
      _loadReport();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Text(
                '报告',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            MonthSelector(
              month: _selectedMonth,
              onPrevious: () => _changeMonth(-1),
              onNext: () => _changeMonth(1),
            ),
            Expanded(
              child: FutureBuilder<CategoryReport>(
                future: _reportFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.addBtnBg),
                    );
                  }

                  if (snapshot.hasError) {
                    return ApiErrorView(error: snapshot.error, onRetry: _loadReport);
                  }

                  final report = snapshot.data!;
                  return RefreshIndicator(
                    color: AppColors.addBtnBg,
                    backgroundColor: AppColors.bgSecondary,
                    onRefresh: () async {
                      _loadReport();
                      await _reportFuture;
                    },
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 100),
                      children: [
                        _buildOverview(report),
                        const SizedBox(height: 20),
                        ReportCharts(report: report),
                        const SizedBox(height: 20),
                        _buildCategorySection(report),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverview(CategoryReport report) {
    final expenseRatio = report.income + report.expense == 0
        ? 0.0
        : report.expense / (report.income + report.expense);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.bgSecondary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '月度概览',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildOverviewMetric(
                    '收入',
                    report.income,
                    AppColors.incomeGreen,
                  ),
                ),
                Expanded(
                  child: _buildOverviewMetric(
                    '支出',
                    report.expense,
                    AppColors.expenseRed,
                  ),
                ),
                Expanded(
                  child: _buildOverviewMetric(
                    '结余',
                    report.total,
                    report.total >= 0
                        ? AppColors.incomeGreen
                        : AppColors.expenseRed,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: expenseRatio,
                minHeight: 8,
                backgroundColor: AppColors.incomeGreen.withValues(alpha: 0.25),
                color: AppColors.expenseRed,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '支出占比 ${(expenseRatio * 100).toStringAsFixed(1)}%',
              style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewMetric(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Text(
          '¥${value.toStringAsFixed(2)}',
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySection(CategoryReport report) {
    if (report.categories.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Center(
          child: Text(
            '该月暂无分类统计',
            style: TextStyle(color: AppColors.textTertiary, fontSize: 15),
          ),
        ),
      );
    }

    final maxAmount = report.categories
        .map((item) => item.total)
        .reduce((a, b) => a > b ? a : b);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '分类统计',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          ...report.categories.map(
            (item) => _CategoryReportTile(
              item: item,
              maxAmount: maxAmount,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryReportTile extends StatelessWidget {
  final CategoryReportItem item;
  final double maxAmount;

  const _CategoryReportTile({
    required this.item,
    required this.maxAmount,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = maxAmount == 0 ? 0.0 : item.total / maxAmount;
    final primaryAmount = item.expense > 0 ? item.expense : item.income;
    final primaryColor =
        item.expense > 0 ? AppColors.expenseRed : AppColors.incomeGreen;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: item.category.color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(item.category.icon, style: const TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.category.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${item.transactionCount} 笔',
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '¥${primaryAmount.toStringAsFixed(2)}',
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: AppColors.divider.withValues(alpha: 0.4),
              color: item.category.color,
            ),
          ),
        ],
      ),
    );
  }
}
