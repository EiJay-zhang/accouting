import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../constants/app_colors.dart';
import '../models/transaction.dart';

class TransactionGroupCard extends StatelessWidget {
  final TransactionGroup group;
  final ValueChanged<Transaction>? onTransactionTap;

  const TransactionGroupCard({
    super.key,
    required this.group,
    this.onTransactionTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr =
        '${group.date.month.toString().padLeft(2, '0')}月${group.date.day.toString().padLeft(2, '0')}日';
    final weekday = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][
        group.date.weekday - 1];

    double dayTotal = 0;
    for (final transaction in group.transactions) {
      if (transaction.type == TransactionType.income) {
        dayTotal += transaction.amount;
      } else {
        dayTotal -= transaction.amount;
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Text(
                  '$dateStr  $weekday',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  '${dayTotal >= 0 ? '+' : ''}${dayTotal.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: dayTotal >= 0
                        ? AppColors.incomeGreen
                        : AppColors.expenseRed,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.bgSecondary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: group.transactions.map((transaction) {
                return TransactionTile(
                  transaction: transaction,
                  isLast: transaction == group.transactions.last,
                  onTap: onTransactionTap == null
                      ? null
                      : () => onTransactionTap!(transaction),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class TransactionTile extends StatelessWidget {
  final Transaction transaction;
  final bool isLast;
  final VoidCallback? onTap;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.isLast = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.type == TransactionType.expense;
    final sign = isExpense ? '-' : '+';
    final color = isExpense ? AppColors.expenseRed : AppColors.incomeGreen;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: isLast
                ? null
                : Border(
                    bottom: BorderSide(
                      color: AppColors.divider.withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                  ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: transaction.category.color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    transaction.category.icon,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      transaction.category.name,
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$sign¥${transaction.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppColors.textTertiary.withValues(alpha: 0.7),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class MonthSelector extends StatelessWidget {
  final DateTime month;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const MonthSelector({
    super.key,
    required this.month,
    this.onPrevious,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
          ),
          Expanded(
            child: Text(
              '${month.year}年${month.month}月',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class ApiErrorView extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;

  const ApiErrorView({
    super.key,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final message = error is ApiException
        ? (error! as ApiException).message
        : '加载失败，请检查后端服务是否已启动';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, color: AppColors.textTertiary, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.addBtnBg,
                foregroundColor: Colors.white,
              ),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}
