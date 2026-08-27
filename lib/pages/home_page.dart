import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../models/transaction.dart';
import '../services/transaction_service.dart';
import '../widgets/transaction_widgets.dart';
import 'add_transaction_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  final TransactionService _service = TransactionService();
  late Future<HomeData> _homeDataFuture;

  @override
  void initState() {
    super.initState();
    _homeDataFuture = _service.loadHomeData();
  }

  void refresh() {
    setState(() {
      _homeDataFuture = _service.loadHomeData();
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
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: FutureBuilder<HomeData>(
          future: _homeDataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.addBtnBg),
              );
            }

            if (snapshot.hasError) {
              return ApiErrorView(error: snapshot.error, onRetry: refresh);
            }

            final data = snapshot.data!;
            return RefreshIndicator(
              color: AppColors.addBtnBg,
              backgroundColor: AppColors.bgSecondary,
              onRefresh: () async {
                refresh();
                await _homeDataFuture;
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(data.summary.total, data.month),
                    const SizedBox(height: 20),
                    _buildSummaryCards(data.summary.income, data.summary.expense),
                    const SizedBox(height: 24),
                    _buildTransactionList(data.groups),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(double total, DateTime month) {
    final monthLabel = '${month.year}年${month.month}月概览';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            monthLabel,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '¥${total.toStringAsFixed(2)}',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 40,
              fontWeight: FontWeight.bold,
              letterSpacing: -1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(double income, double expense) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(child: _buildSummaryCard('收入', '+¥${income.toStringAsFixed(2)}', AppColors.incomeGreen)),
          const SizedBox(width: 12),
          Expanded(child: _buildSummaryCard('支出', '-¥${expense.toStringAsFixed(2)}', AppColors.expenseRed)),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionList(List<TransactionGroup> groups) {
    if (groups.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Center(
          child: Text(
            '本月还没有记账记录',
            style: TextStyle(color: AppColors.textTertiary, fontSize: 15),
          ),
        ),
      );
    }

    return Column(
      children: groups
          .map(
            (group) => TransactionGroupCard(
              group: group,
              onTransactionTap: _openEditTransaction,
            ),
          )
          .toList(),
    );
  }
}
