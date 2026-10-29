import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/report_api.dart';
import '../constants/app_colors.dart';
import '../models/transaction.dart';
import '../widgets/report_charts.dart';
import '../widgets/report_palette.dart';
import '../widgets/transaction_widgets.dart';
import 'ai_chat_page.dart';

class ReportPage extends StatefulWidget {
  final void Function(
    ReportPeriod period,
    DateTime start,
    DateTime end,
    int categoryId,
    String categoryName,
    TransactionType type,
  )?
  onOpenCategory;

  const ReportPage({super.key, this.onOpenCategory});

  @override
  State<ReportPage> createState() => ReportPageState();
}

class ReportPageState extends State<ReportPage> {
  final ReportApi _api = ReportApi();
  ReportPeriod _period = ReportPeriod.month;
  late DateTime _anchor;
  late Future<(CategoryReport, MonthlyTrend)> _reportFuture;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _anchor = DateTime(now.year, now.month, now.day);
    _loadReport();
  }

  void refresh() {
    _loadReport();
  }

  void _loadReport() {
    setState(() {
      _reportFuture = _loadBundle();
    });
  }

  DateTime get _weekStart {
    final day = DateTime(_anchor.year, _anchor.month, _anchor.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  String get _anchorText {
    final day = _weekStart;
    final month = day.month.toString().padLeft(2, '0');
    final date = day.day.toString().padLeft(2, '0');
    return '${day.year}-$month-$date';
  }

  String get _periodLabel {
    switch (_period) {
      case ReportPeriod.week:
        final start = _weekStart;
        final end = start.add(const Duration(days: 6));
        if (start.year == end.year && start.month == end.month) {
          return '${start.year}年${start.month}月${start.day}日 - ${end.day}日';
        }
        if (start.year == end.year) {
          return '${start.year}年${start.month}月${start.day}日 - ${end.month}月${end.day}日';
        }
        return '${start.year}年${start.month}月${start.day}日 - ${end.year}年${end.month}月${end.day}日';
      case ReportPeriod.month:
        return '${_anchor.year}年${_anchor.month}月';
      case ReportPeriod.year:
        return '${_anchor.year}年';
    }
  }

  String get _overviewTitle {
    switch (_period) {
      case ReportPeriod.week:
        return '周度概览';
      case ReportPeriod.month:
        return '月度概览';
      case ReportPeriod.year:
        return '年度概览';
    }
  }

  String get _balanceLabel {
    switch (_period) {
      case ReportPeriod.week:
        return '周度结余';
      case ReportPeriod.month:
        return '月度结余';
      case ReportPeriod.year:
        return '年度结余';
    }
  }

  String get _chartEmptyHint {
    switch (_period) {
      case ReportPeriod.week:
        return '该周暂无收支数据';
      case ReportPeriod.month:
        return '该月暂无收支数据';
      case ReportPeriod.year:
        return '该年暂无收支数据';
    }
  }

  String get _compareLabel {
    switch (_period) {
      case ReportPeriod.week:
        return '上周';
      case ReportPeriod.month:
        return '上月';
      case ReportPeriod.year:
        return '上年';
    }
  }

  String _trendTitle(int count) {
    switch (_period) {
      case ReportPeriod.week:
        return '近 $count 周';
      case ReportPeriod.month:
        return '近 $count 个月';
      case ReportPeriod.year:
        return '${_anchor.year}年各月';
    }
  }

  DateTime get _periodStart {
    switch (_period) {
      case ReportPeriod.week:
        return _weekStart;
      case ReportPeriod.month:
        return DateTime(_anchor.year, _anchor.month, 1);
      case ReportPeriod.year:
        return DateTime(_anchor.year, 1, 1);
    }
  }

  DateTime get _periodEnd {
    switch (_period) {
      case ReportPeriod.week:
        return _weekStart.add(const Duration(days: 6));
      case ReportPeriod.month:
        return DateTime(_anchor.year, _anchor.month + 1, 0);
      case ReportPeriod.year:
        return DateTime(_anchor.year, 12, 31);
    }
  }

  String get _emptyText {
    switch (_period) {
      case ReportPeriod.week:
        return '该周暂无分类统计';
      case ReportPeriod.month:
        return '该月暂无分类统计';
      case ReportPeriod.year:
        return '该年暂无分类统计';
    }
  }

  Future<(CategoryReport, MonthlyTrend)> _loadBundle() async {
    final year = _anchor.year;
    final month = _anchor.month;
    final anchor = _period == ReportPeriod.week ? _anchorText : null;
    final report = await _api.fetchCategoryReport(
      period: _period,
      year: _period == ReportPeriod.week ? null : year,
      month: _period == ReportPeriod.month ? month : null,
      anchor: anchor,
    );
    final trend = await _api.fetchTrend(
      period: _period,
      year: _period == ReportPeriod.week ? null : year,
      month: _period == ReportPeriod.month ? month : null,
      anchor: anchor,
    );
    return (report, trend);
  }

  void _selectPeriod(ReportPeriod period) {
    if (period == _period) return;
    _period = period;
    _loadReport();
  }

  void _shiftPeriod(int delta) {
    switch (_period) {
      case ReportPeriod.week:
        _anchor = _anchor.add(Duration(days: 7 * delta));
      case ReportPeriod.month:
        _anchor = DateTime(_anchor.year, _anchor.month + delta, 1);
      case ReportPeriod.year:
        _anchor = DateTime(_anchor.year + delta, 1, 1);
    }
    _loadReport();
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
              child: Row(
                children: [
                  Text(
                    '报告',
                    style: TextStyle(
                      color: AppColors.of(context).textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton.filled(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AiChatPage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.of(context).addBtnBg,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(40, 40),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.of(context).bgSecondary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    for (final period in ReportPeriod.values)
                      _PeriodSegment(
                        label: _periodName(period),
                        selected: _period == period,
                        onTap: () => _selectPeriod(period),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => _shiftPeriod(-1),
                    icon: Icon(
                      Icons.chevron_left,
                      color: AppColors.of(context).textPrimary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _periodLabel,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.of(context).textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _shiftPeriod(1),
                    icon: Icon(
                      Icons.chevron_right,
                      color: AppColors.of(context).textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<(CategoryReport, MonthlyTrend)>(
                future: _reportFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: AppColors.of(context).addBtnBg,
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return ApiErrorView(
                      error: snapshot.error,
                      onRetry: _loadReport,
                    );
                  }

                  final report = snapshot.data!.$1;
                  final trend = snapshot.data!.$2;
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
                        _buildTrend(trend),
                        SizedBox(height: 20),
                        ReportCharts(
                          report: report,
                          balanceLabel: _balanceLabel,
                          emptyHint: _chartEmptyHint,
                        ),
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

  Widget _buildTrend(MonthlyTrend trend) {
    final expenseText = _deltaText('支出', trend.expenseDelta);
    final incomeText = _deltaText('收入', trend.incomeDelta);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.of(context).bgSecondary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _trendTitle(trend.points.length),
              style: TextStyle(
                color: AppColors.of(context).textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '$expenseText，$incomeText',
              style: TextStyle(
                color: AppColors.of(context).textPrimary,
                fontSize: 13,
              ),
            ),
            SizedBox(height: 12),
            MonthlyTrendChart(points: trend.points),
          ],
        ),
      ),
    );
  }

  String _deltaText(String label, double delta) {
    if (delta.abs() < 0.005) return '$label与$_compareLabel持平';
    final direction = delta > 0 ? '多' : '少';
    return '比$_compareLabel$label$direction ¥${delta.abs().toStringAsFixed(2)}';
  }

  Future<void> _editBudget(CategoryReportItem item) async {
    final current = item.budget;
    final initialText = current == null
        ? ''
        : (current % 1 == 0
              ? current.toInt().toString()
              : current.toStringAsFixed(2));
    final hintText = switch (_period) {
      ReportPeriod.week => '本周预算金额，留空表示清除',
      ReportPeriod.month => '本月预算金额，留空表示清除',
      ReportPeriod.year => '全年预算金额，留空表示清除',
    };
    final amount = await showDialog<double>(
      context: context,
      builder: (context) => _BudgetAmountDialog(
        title: '${item.category.name}预算',
        hintText: hintText,
        initialText: initialText,
      ),
    );
    if (amount == null || !mounted) return;

    try {
      await _api.saveBudget(
        categoryId: item.category.id,
        year: _period == ReportPeriod.week ? _weekStart.year : _anchor.year,
        month: _anchor.month,
        amount: amount,
        scope: _period,
        anchor: _period == ReportPeriod.week ? _anchorText : null,
      );
      if (!mounted) return;
      _loadReport();
    } catch (error) {
      if (!mounted) return;
      final message = error is ApiException ? error.message : '预算保存失败';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
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
              _overviewTitle,
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
                    report.total >= 0
                        ? ReportPalette.incomeInk
                        : ReportPalette.expenseInk,
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
              style: TextStyle(
                color: AppColors.of(context).textTertiary,
                fontSize: 12,
              ),
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
          style: TextStyle(
            color: AppColors.of(context).textTertiary,
            fontSize: 12,
          ),
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
            _emptyText,
            style: TextStyle(
              color: AppColors.of(context).textTertiary,
              fontSize: 15,
            ),
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
              onOpen: () => widget.onOpenCategory?.call(
                _period,
                _periodStart,
                _periodEnd,
                item.category.id,
                item.category.name,
                item.category.type,
              ),
              budgetScope: switch (_period) {
                ReportPeriod.week => '本周',
                ReportPeriod.year => '全年',
                ReportPeriod.month => null,
              },
              onEditBudget: item.category.type == TransactionType.expense
                  ? () => _editBudget(item)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetAmountDialog extends StatefulWidget {
  final String title;
  final String hintText;
  final String initialText;

  const _BudgetAmountDialog({
    required this.title,
    required this.hintText,
    required this.initialText,
  });

  @override
  State<_BudgetAmountDialog> createState() => _BudgetAmountDialogState();
}

class _BudgetAmountDialogState extends State<_BudgetAmountDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialText,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.of(context).bgSecondary,
      title: Text(
        widget.title,
        style: TextStyle(color: AppColors.of(context).textPrimary),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(color: AppColors.of(context).textPrimary),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: TextStyle(
            color: AppColors.of(context).textTertiary,
            fontSize: 13,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, 0),
          child: const Text('清除'),
        ),
        TextButton(
          onPressed: () {
            final text = _controller.text.trim();
            if (text.isEmpty) {
              Navigator.pop(context, 0);
              return;
            }
            final parsed = double.tryParse(text);
            if (parsed == null || parsed < 0) return;
            Navigator.pop(context, parsed);
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}

class _PeriodSegment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? colors.addBtnBg : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : colors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _periodName(ReportPeriod period) {
  switch (period) {
    case ReportPeriod.week:
      return '周';
    case ReportPeriod.month:
      return '月';
    case ReportPeriod.year:
      return '年';
  }
}

class _CategoryReportTile extends StatelessWidget {
  final CategoryReportItem item;
  final double maxAmount;
  final VoidCallback? onOpen;
  final VoidCallback? onEditBudget;
  final String? budgetScope;

  const _CategoryReportTile({
    required this.item,
    required this.maxAmount,
    this.onOpen,
    this.onEditBudget,
    this.budgetScope,
  });

  @override
  Widget build(BuildContext context) {
    final hasBudget = item.budget != null && item.budget! > 0;
    final ratio = hasBudget
        ? (item.expense / item.budget!).clamp(0.0, 1.0)
        : (maxAmount == 0 ? 0.0 : item.total / maxAmount);
    final primaryAmount = item.expense > 0 ? item.expense : item.income;
    final tone = ReportPalette.category(item.category.id);
    final overBudget = hasBudget && item.expense > item.budget!;
    final primaryColor = item.expense > 0
        ? ReportPalette.expenseInk
        : ReportPalette.incomeInk;
    final remain = hasBudget ? item.budget! - item.expense : 0.0;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.of(context).bgSecondary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onOpen,
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      item.category.icon,
                      style: TextStyle(fontSize: 20),
                    ),
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
          ),
          SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: AppColors.of(
                context,
              ).divider.withValues(alpha: 0.4),
              color: overBudget ? ReportPalette.expense : tone,
            ),
          ),
          if (hasBudget || onEditBudget != null) ...[
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    hasBudget
                        ? (overBudget
                              ? '超出 ¥${(-remain).toStringAsFixed(2)}'
                              : '${budgetScope == null ? '' : '$budgetScope'}预算 ¥${item.budget!.toStringAsFixed(2)} · 还剩 ¥${remain.toStringAsFixed(2)}')
                        : '还没有预算',
                    style: TextStyle(
                      color: overBudget
                          ? ReportPalette.expenseInk
                          : AppColors.of(context).textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (onEditBudget != null)
                  TextButton(
                    onPressed: onEditBudget,
                    child: Text(hasBudget ? '改预算' : '设预算'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
