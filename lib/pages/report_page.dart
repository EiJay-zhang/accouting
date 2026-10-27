import 'package:flutter/material.dart';

import '../api/report_api.dart';
import '../constants/app_colors.dart';
import '../widgets/report_charts.dart';
import '../widgets/report_palette.dart';
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
      backgroundColor: AppColors.of(context).bgPrimary,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Text(
                '报告',
                style: TextStyle(
                  color: AppColors.of(context).textPrimary,
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
                    return Center(
                      child: CircularProgressIndicator(color: AppColors.of(context).addBtnBg),
                    );
                  }

                  if (snapshot.hasError) {
                    return ApiErrorView(error: snapshot.error, onRetry: _loadReport);
                  }

                  final report = snapshot.data!;
                  return RefreshIndicator(
                    color: AppColors.of(context).addBtnBg,
                    backgroundColor: AppColors.of(context).bgSecondary,
                    onRefresh: () async {
                      _loadReport();
                      await _reportFuture;
                    },
                    child: ListView(
                      physics: AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.only(bottom: 100),
                      children: [
                        _buildOverview(report),
                        SizedBox(height: 20),
                        ReportCharts(report: report),
                        SizedBox(height: 20),
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
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.of(context).bgSecondary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '月度概览',
              style: TextStyle(
                color: AppColors.of(context).textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildOverviewMetric(
                    '收入',
                    report.income,
                    ReportPalette.incomeInk,
                  ),
                ),
                Expanded(
                  child: _buildOverviewMetric(
                    '支出',
                    report.expense,
                    ReportPalette.expenseInk,
                  ),
                ),
                Expanded(
                  child: _buildOverviewMetric(
                    '结余',
                    report.total,
                    report.total >= 0 ? ReportPalette.incomeInk : ReportPalette.expenseInk,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: expenseRatio,
                minHeight: 8,
                backgroundColor: ReportPalette.income.withValues(alpha: 0.45),
                color: ReportPalette.expense,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '支出占比 ${(expenseRatio * 100).toStringAsFixed(1)}%',
              style: TextStyle(color: AppColors.of(context).textTertiary, fontSize: 12),
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
          style: TextStyle(color: AppColors.of(context).textTertiary, fontSize: 12),
        ),
        SizedBox(height: 6),
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
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Center(
          child: Text(
            '该月暂无分类统计',
            style: TextStyle(color: AppColors.of(context).textTertiary, fontSize: 15),
          ),
        ),
      );
    }

    final maxAmount = report.categories
        .map((item) => item.total)
        .reduce((a, b) => a > b ? a : b);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '分类统计',
            style: TextStyle(
              color: AppColors.of(context).textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 12),
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
    final tone = ReportPalette.category(item.category.id);
    final primaryColor = item.expense > 0 ? ReportPalette.expenseInk : ReportPalette.incomeInk;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.of(context).bgSecondary,
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
                  color: tone.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(item.category.icon, style: TextStyle(fontSize: 20)),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.category.name,
                      style: TextStyle(
                        color: AppColors.of(context).textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${item.transactionCount} 笔',
                      style: TextStyle(
                        color: AppColors.of(context).textTertiary,
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
          SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: AppColors.of(context).divider.withValues(alpha: 0.4),
              color: tone,
            ),
          ),
        ],
      ),
    );
  }
}
