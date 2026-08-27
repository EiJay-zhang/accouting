import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../api/report_api.dart';
import '../constants/app_colors.dart';

class ReportCharts extends StatelessWidget {
  final CategoryReport report;

  const ReportCharts({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final expenseItems = report.categories
        .where((item) => item.expense > 0)
        .toList()
      ..sort((a, b) => b.expense.compareTo(a.expense));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ChartCard(
          title: '收支结构',
          child: _IncomeExpenseDonutChart(
            income: report.income,
            expense: report.expense,
            total: report.total,
          ),
        ),
        if (expenseItems.isNotEmpty) ...[
          const SizedBox(height: 16),
          _ChartCard(
            title: '支出分类占比',
            child: _CategoryExpensePieChart(items: expenseItems),
          ),
          const SizedBox(height: 16),
          _ChartCard(
            title: '分类支出对比',
            child: _CategoryBarChart(items: expenseItems),
          ),
        ],
      ],
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
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
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

class _IncomeExpenseDonutChart extends StatelessWidget {
  final double income;
  final double expense;
  final double total;

  const _IncomeExpenseDonutChart({
    required this.income,
    required this.expense,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final sum = income + expense;
    if (sum == 0) {
      return const _ChartEmptyHint(message: '本月暂无收支数据');
    }

    return SizedBox(
      height: 220,
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 52,
                startDegreeOffset: -90,
                sections: [
                  _pieSection(
                    value: income,
                    color: AppColors.incomeGreen,
                    title: income > 0 ? '${(income / sum * 100).toStringAsFixed(0)}%' : '',
                  ),
                  _pieSection(
                    value: expense,
                    color: AppColors.expenseRed,
                    title: expense > 0 ? '${(expense / sum * 100).toStringAsFixed(0)}%' : '',
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¥${total.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: total >= 0
                        ? AppColors.incomeGreen
                        : AppColors.expenseRed,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '月度结余',
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                ),
                const SizedBox(height: 16),
                _LegendItem(color: AppColors.incomeGreen, label: '收入', value: income),
                const SizedBox(height: 8),
                _LegendItem(color: AppColors.expenseRed, label: '支出', value: expense),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PieChartSectionData _pieSection({
    required double value,
    required Color color,
    required String title,
  }) {
    return PieChartSectionData(
      value: value,
      color: color,
      title: title,
      radius: 58,
      titleStyle: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _CategoryExpensePieChart extends StatefulWidget {
  final List<CategoryReportItem> items;

  const _CategoryExpensePieChart({required this.items});

  @override
  State<_CategoryExpensePieChart> createState() =>
      _CategoryExpensePieChartState();
}

class _CategoryExpensePieChartState extends State<_CategoryExpensePieChart> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final totalExpense =
        widget.items.fold(0.0, (sum, item) => sum + item.expense);

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              startDegreeOffset: -90,
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        response?.touchedSection == null) {
                      _touchedIndex = null;
                      return;
                    }
                    _touchedIndex = response!.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              sections: List.generate(widget.items.length, (index) {
                final item = widget.items[index];
                final isTouched = index == _touchedIndex;
                final percent = item.expense / totalExpense * 100;
                return PieChartSectionData(
                  value: item.expense,
                  color: item.category.color,
                  radius: isTouched ? 64 : 56,
                  title: percent >= 8 ? '${percent.toStringAsFixed(0)}%' : '',
                  titleStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: widget.items.map((item) {
            return _LegendItem(
              color: item.category.color,
              label: '${item.category.icon} ${item.category.name}',
              value: item.expense,
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _CategoryBarChart extends StatelessWidget {
  final List<CategoryReportItem> items;

  const _CategoryBarChart({required this.items});

  @override
  Widget build(BuildContext context) {
    final maxY = items.map((item) => item.expense).reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          maxY: maxY * 1.2,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY > 0 ? maxY / 4 : 1,
            getDrawingHorizontalLine: (value) => FlLine(
              color: AppColors.divider.withValues(alpha: 0.35),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                getTitlesWidget: (value, meta) {
                  if (value == 0 || value == meta.max) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    _compactAmount(value),
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 10,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= items.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      items[index].category.icon,
                      style: const TextStyle(fontSize: 14),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: List.generate(items.length, (index) {
            final item = items[index];
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: item.expense,
                  color: item.category.color,
                  width: 18,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  String _compactAmount(double value) {
    if (value >= 10000) {
      return '${(value / 10000).toStringAsFixed(1)}w';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    return value.toStringAsFixed(0);
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final double value;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(width: 6),
        Text(
          '¥${value.toStringAsFixed(2)}',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ChartEmptyHint extends StatelessWidget {
  final String message;

  const _ChartEmptyHint({required this.message});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: AppColors.textTertiary, fontSize: 14),
        ),
      ),
    );
  }
}
