import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../api/report_api.dart';
import '../constants/app_colors.dart';
import 'report_palette.dart';

class ReportCharts extends StatelessWidget {
  final CategoryReport report;
  final String balanceLabel;
  final String emptyHint;

  const ReportCharts({
    super.key,
    required this.report,
    this.balanceLabel = '月度结余',
    this.emptyHint = '暂无收支数据',
  });

  @override
  Widget build(BuildContext context) {
    final expenseItems =
        report.categories.where((item) => item.expense > 0).toList()
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
            balanceLabel: balanceLabel,
            emptyHint: emptyHint,
          ),
        ),
        if (expenseItems.isNotEmpty) ...[
          SizedBox(height: 16),
          _ChartCard(
            title: '支出分类占比',
            child: _CategoryExpensePieChart(items: expenseItems),
          ),
          SizedBox(height: 16),
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
              title,
              style: TextStyle(
                color: AppColors.of(context).textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 20),
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
  final String balanceLabel;
  final String emptyHint;

  const _IncomeExpenseDonutChart({
    required this.income,
    required this.expense,
    required this.total,
    required this.balanceLabel,
    required this.emptyHint,
  });

  @override
  Widget build(BuildContext context) {
    final sum = income + expense;
    if (sum == 0) {
      return _ChartEmptyHint(message: emptyHint);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final gap = width * 0.08;
        final pieBox = width * 0.46;
        return SizedBox(
          height: pieBox,
          child: Row(
            children: [
              SizedBox(
                width: pieBox,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: pieBox * 0.236,
                    startDegreeOffset: -90,
                    sections: [
                      _pieSection(
                        value: income,
                        color: ReportPalette.income,
                        radius: pieBox * 0.264,
                        title: income > 0
                            ? '${(income / sum * 100).toStringAsFixed(0)}%'
                            : '',
                      ),
                      _pieSection(
                        value: expense,
                        color: ReportPalette.expense,
                        radius: pieBox * 0.264,
                        title: expense > 0
                            ? '${(expense / sum * 100).toStringAsFixed(0)}%'
                            : '',
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: gap),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '¥${total.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: total >= 0
                              ? ReportPalette.incomeInk
                              : ReportPalette.expenseInk,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      balanceLabel,
                      style: TextStyle(
                        color: AppColors.of(context).textTertiary,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(height: 16),
                    _LegendItem(
                      color: ReportPalette.income,
                      label: '收入',
                      value: income,
                    ),
                    SizedBox(height: 8),
                    _LegendItem(
                      color: ReportPalette.expense,
                      label: '支出',
                      value: expense,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  PieChartSectionData _pieSection({
    required double value,
    required Color color,
    required double radius,
    required String title,
  }) {
    return PieChartSectionData(
      value: value,
      color: color,
      title: title,
      radius: radius,
      titleStyle: TextStyle(
        color: ReportPalette.label,
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
    final totalExpense = widget.items.fold(
      0.0,
      (sum, item) => sum + item.expense,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final diameter = constraints.maxWidth * 0.62;
        return Column(
          children: [
            SizedBox(
              height: diameter,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: diameter * 0.208,
                  startDegreeOffset: -90,
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            response?.touchedSection == null) {
                          _touchedIndex = null;
                          return;
                        }
                        _touchedIndex =
                            response!.touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                  sections: List.generate(widget.items.length, (index) {
                    final item = widget.items[index];
                    final isTouched = index == _touchedIndex;
                    final percent = item.expense / totalExpense * 100;
                    return PieChartSectionData(
                      value: item.expense,
                      color: ReportPalette.category(item.category.id),
                      radius: diameter * (isTouched ? 0.34 : 0.292),
                      title: percent >= 8
                          ? '${percent.toStringAsFixed(0)}%'
                          : '',
                      titleStyle: TextStyle(
                        color: ReportPalette.label,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    );
                  }),
                ),
              ),
            ),
            SizedBox(height: 20),
            _CategoryLegend(items: widget.items),
          ],
        );
      },
    );
  }
}

class _CategoryBarChart extends StatelessWidget {
  final List<CategoryReportItem> items;

  const _CategoryBarChart({required this.items});

  @override
  Widget build(BuildContext context) {
    final maxY = items
        .map((item) => item.expense)
        .reduce((a, b) => a > b ? a : b);

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxWidth * 0.55;
        final slot = constraints.maxWidth / items.length;
        final barWidth = slot * 0.28;
        return SizedBox(
          height: height,
          child: BarChart(
            BarChartData(
              maxY: maxY * 1.2,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY > 0 ? maxY / 4 : 1,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: AppColors.of(context).divider.withValues(alpha: 0.35),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 42,
                    getTitlesWidget: (value, meta) {
                      if (value == 0 || value == meta.max) {
                        return SizedBox.shrink();
                      }
                      return Text(
                        _compactAmount(value),
                        style: TextStyle(
                          color: AppColors.of(context).textTertiary,
                          fontSize: 10,
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= items.length) {
                        return SizedBox.shrink();
                      }
                      return Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Text(
                          items[index].category.icon,
                          style: TextStyle(fontSize: 18),
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
                      color: ReportPalette.category(item.category.id),
                      width: barWidth,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(8),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        );
      },
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

class _CategoryLegend extends StatelessWidget {
  final List<CategoryReportItem> items;

  const _CategoryLegend({required this.items});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 28,
      runSpacing: 12,
      children: [for (final item in items) _CategoryLegendTile(item: item)],
    );
  }
}

class _CategoryLegendTile extends StatelessWidget {
  final CategoryReportItem item;

  const _CategoryLegendTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = ReportPalette.category(item.category.id);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(item.category.icon, style: TextStyle(fontSize: 20)),
        ),
        SizedBox(width: 10),
        Text(
          item.category.name,
          style: TextStyle(
            color: AppColors.of(context).textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(width: 8),
        Text(
          '¥${item.expense.toStringAsFixed(2)}',
          style: TextStyle(
            color: AppColors.of(context).textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
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
        SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: AppColors.of(context).textSecondary,
            fontSize: 12,
          ),
        ),
        SizedBox(width: 6),
        Text(
          '¥${value.toStringAsFixed(2)}',
          style: TextStyle(
            color: AppColors.of(context).textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class MonthlyTrendChart extends StatelessWidget {
  final List<TrendPoint> points;

  const MonthlyTrendChart({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();
    final maxExpense = points
        .map((item) => item.expense)
        .fold<double>(0, (a, b) => a > b ? a : b);
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxWidth * 0.42;
        final slot = constraints.maxWidth / points.length;
        return SizedBox(
          height: height,
          child: BarChart(
            BarChartData(
              maxY: maxExpense <= 0 ? 1 : maxExpense * 1.2,
              gridData: FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= points.length) {
                        return const SizedBox.shrink();
                      }
                      final label = points[index].label.isNotEmpty
                          ? points[index].label
                          : '${points[index].month}月';
                      return Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          label,
                          style: TextStyle(
                            color: AppColors.of(context).textTertiary,
                            fontSize: points.length > 8 ? 10 : 11,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: List.generate(points.length, (index) {
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: points[index].expense,
                      color: ReportPalette.expense,
                      width: slot * 0.38,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        );
      },
    );
  }
}

class _ChartEmptyHint extends StatelessWidget {
  final String message;

  const _ChartEmptyHint({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 36),
      child: Center(
        child: Text(
          message,
          style: TextStyle(
            color: AppColors.of(context).textTertiary,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
