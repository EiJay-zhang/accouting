import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../models/transaction.dart';
import '../services/transaction_service.dart';
import '../widgets/transaction_widgets.dart';
import 'add_transaction_page.dart';

class BillsPage extends StatefulWidget {
  const BillsPage({super.key});

  @override
  State<BillsPage> createState() => BillsPageState();
}

class BillsPageState extends State<BillsPage> {
  final TransactionService _service = TransactionService();
  late DateTime _selectedMonth;
  late Future<HomeData> _billsFuture;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
    _loadBills();
  }

  void refresh() {
    _loadBills();
  }

  void _loadBills() {
    setState(() {
      _billsFuture = _service.loadHomeData(month: _selectedMonth);
    });
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta);
      _loadBills();
    });
  }

  Future<void> _openEditTransaction(Transaction transaction) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddTransactionPage(transaction: transaction),
      ),
    );
    if (updated == true && mounted) {
      refresh();
    }
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
                '账单',
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
              child: FutureBuilder<HomeData>(
                future: _billsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(color: AppColors.of(context).addBtnBg),
                    );
                  }

                  if (snapshot.hasError) {
                    return ApiErrorView(error: snapshot.error, onRetry: _loadBills);
                  }

                  final data = snapshot.data!;
                  return RefreshIndicator(
                    color: AppColors.of(context).addBtnBg,
                    backgroundColor: AppColors.of(context).bgSecondary,
                    onRefresh: () async {
                      _loadBills();
                      await _billsFuture;
                    },
                    child: data.groups.isEmpty
                        ? ListView(
                            physics: AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(height: 120),
                              Center(
                                child: Text(
                                  '该月暂无账单',
                                  style: TextStyle(
                                    color: AppColors.of(context).textTertiary,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView(
                            physics: AlwaysScrollableScrollPhysics(),
                            children: [
                              _buildSummaryBar(data),
                              ...data.groups.map(
                                (group) => TransactionGroupCard(
                                  group: group,
                                  onTransactionTap: _openEditTransaction,
                                ),
                              ),
                              SizedBox(height: 100),
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

  Widget _buildSummaryBar(HomeData data) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.of(context).bgSecondary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            _buildSummaryItem('收入', data.summary.income, AppColors.of(context).incomeGreen, '+'),
            Container(width: 1, height: 36, color: AppColors.of(context).divider),
            _buildSummaryItem('支出', data.summary.expense, AppColors.of(context).expenseRed, '-'),
            Container(width: 1, height: 36, color: AppColors.of(context).divider),
            _buildSummaryItem('结余', data.summary.total, AppColors.of(context).textPrimary, ''),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    String label,
    double amount,
    Color color,
    String prefix,
  ) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(color: AppColors.of(context).textSecondary, fontSize: 12),
          ),
          SizedBox(height: 6),
          Text(
            '$prefix¥${amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
