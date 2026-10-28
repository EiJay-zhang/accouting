import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../models/transaction.dart';
import '../services/transaction_service.dart';
import '../widgets/transaction_widgets.dart';
import 'add_transaction_page.dart';

class HomePage extends StatefulWidget {
  final VoidCallback? onDataChanged;

  const HomePage({super.key, this.onDataChanged});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  final TransactionService _service = TransactionService();
  final Set<int> _removedIds = {};
  late DateTime _month;
  late Future<HomeData> _homeDataFuture;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _homeDataFuture = _service.loadHomeData(month: _month);
  }

  void refresh() {
    setState(() {
      _homeDataFuture = _service.loadHomeData(month: _month);
    });
  }

  void _shiftMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _homeDataFuture = _service.loadHomeData(month: _month);
    });
  }

  Future<void> _deleteTransaction(Transaction transaction) {
    return deleteTransactionWithUndo(
      context: context,
      transaction: transaction,
      service: _service,
      update: setState,
      removedIds: _removedIds,
      onChanged: widget.onDataChanged ?? refresh,
    );
  }

  Future<void> _openEditTransaction(Transaction transaction) async {
    final updated = await Navigator.of(context).push<Object?>(
      MaterialPageRoute(
        builder: (_) => AddTransactionPage(transaction: transaction),
      ),
    );
    if (!mounted) return;
    if (updated == 'deleted') {
      offerUndoForDeletedTransaction(
        context: context,
        transaction: transaction,
        service: _service,
        update: setState,
        removedIds: _removedIds,
        onChanged: widget.onDataChanged ?? refresh,
      );
    } else if (updated == true) {
      if (widget.onDataChanged != null) {
        widget.onDataChanged!();
      } else {
        refresh();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.of(context).bgPrimary,
      body: SafeArea(
        child: FutureBuilder<HomeData>(
          future: _homeDataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(
                  color: AppColors.of(context).addBtnBg,
                ),
              );
            }

            if (snapshot.hasError) {
              return ApiErrorView(error: snapshot.error, onRetry: refresh);
            }

            final data = snapshot.data!;
            return Column(
              children: [
                _MonthOverview(
                  month: data.month,
                  income: data.summary.income,
                  expense: data.summary.expense,
                  balance: data.summary.total,
                  onPrevious: () => _shiftMonth(-1),
                  onNext: () => _shiftMonth(1),
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.of(context).addBtnBg,
                    backgroundColor: AppColors.of(context).bgSecondary,
                    onRefresh: () async {
                      refresh();
                      await _homeDataFuture;
                    },
                    child: ListView(
                      physics: AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.only(top: 8, bottom: 100),
                      children: [
                        _buildTransactionList(_visibleGroups(data.groups)),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<TransactionGroup> _visibleGroups(List<TransactionGroup> groups) {
    if (_removedIds.isEmpty) return groups;
    return [
      for (final group in groups)
        if (group.transactions.any((item) => !_removedIds.contains(item.id)))
          TransactionGroup(
            date: group.date,
            transactions: [
              for (final item in group.transactions)
                if (!_removedIds.contains(item.id)) item,
            ],
            incomeTotal: group.incomeTotal,
            expenseTotal: group.expenseTotal,
          ),
    ];
  }

  Widget _buildTransactionList(List<TransactionGroup> groups) {
    if (groups.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Center(
          child: Text(
            '该月还没有记账记录',
            style: TextStyle(
              color: AppColors.of(context).textTertiary,
              fontSize: 15,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
          child: Text(
            deleteHintText,
            style: TextStyle(
              color: AppColors.of(context).textTertiary,
              fontSize: 12,
            ),
          ),
        ),
        ...groups.map(
          (group) => TransactionGroupCard(
            group: group,
            onTransactionTap: _openEditTransaction,
            onTransactionDelete: _deleteTransaction,
          ),
        ),
      ],
    );
  }
}

class _MonthOverview extends StatelessWidget {
  final DateTime month;
  final double income;
  final double expense;
  final double balance;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _MonthOverview({
    required this.month,
    required this.income,
    required this.expense,
    required this.balance,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final balanceColor = balance > 0
        ? colors.incomeGreen
        : balance < 0
        ? colors.expenseRed
        : colors.textPrimary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.bgSecondary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: '上个月',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        onPressed: onPrevious,
                        icon: Icon(
                          Icons.chevron_left,
                          size: 18,
                          color: colors.textSecondary,
                        ),
                      ),
                      Text(
                        '${month.year}年${month.month}月',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      IconButton(
                        tooltip: '下个月',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        onPressed: onNext,
                        icon: Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: colors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '结余',
                        style: TextStyle(
                          color: colors.textTertiary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _signedAmount(balance),
                    style: TextStyle(
                      color: balanceColor,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: colors.divider),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: _FlowAmount(
                      label: '收入',
                      amount: income,
                      color: colors.incomeGreen,
                      positive: true,
                    ),
                  ),
                  Container(width: 1, height: 32, color: colors.divider),
                  Expanded(
                    child: _FlowAmount(
                      label: '支出',
                      amount: expense,
                      color: colors.expenseRed,
                      positive: false,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlowAmount extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final bool positive;

  const _FlowAmount({
    required this.label,
    required this.amount,
    required this.color,
    required this.positive,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final prefix = positive ? '+' : '-';

    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: colors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          '$prefix¥${amount.abs().toStringAsFixed(2)}',
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

String _signedAmount(double value) {
  if (value == 0) {
    return '¥0.00';
  }
  final sign = value > 0 ? '+' : '-';
  return '$sign¥${value.abs().toStringAsFixed(2)}';
}
