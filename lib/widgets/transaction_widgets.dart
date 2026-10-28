import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../constants/app_colors.dart';
import '../models/transaction.dart';
import '../services/transaction_service.dart';
import '../utils/money.dart';

class TransactionGroupCard extends StatelessWidget {
  final TransactionGroup group;
  final ValueChanged<Transaction>? onTransactionTap;
  final ValueChanged<Transaction>? onTransactionDelete;

  const TransactionGroupCard({
    super.key,
    required this.group,
    this.onTransactionTap,
    this.onTransactionDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr =
        '${group.date.month.toString().padLeft(2, '0')}月${group.date.day.toString().padLeft(2, '0')}日';
    final weekday = [
      '周一',
      '周二',
      '周三',
      '周四',
      '周五',
      '周六',
      '周日',
    ][group.date.weekday - 1];

    int dayCents = 0;
    for (final transaction in group.transactions) {
      if (transaction.type == TransactionType.income) {
        dayCents += transaction.amountCents;
      } else {
        dayCents -= transaction.amountCents;
      }
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Text(
                  '$dateStr  $weekday',
                  style: TextStyle(
                    color: AppColors.of(context).textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Spacer(),
                Text(
                  '${dayCents >= 0 ? '+' : ''}${formatYuan(dayCents)}',
                  style: TextStyle(
                    color: dayCents >= 0
                        ? AppColors.of(context).incomeGreen
                        : AppColors.of(context).expenseRed,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.of(context).bgSecondary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: group.transactions.map((transaction) {
                final tile = TransactionTile(
                  transaction: transaction,
                  isLast: transaction == group.transactions.last,
                  onTap: onTransactionTap == null
                      ? null
                      : () => onTransactionTap!(transaction),
                  onDelete: onTransactionDelete == null
                      ? null
                      : () async {
                          final confirmed = await _confirmDeleteTransaction(
                            context,
                          );
                          if (confirmed) onTransactionDelete!(transaction);
                        },
                );
                if (onTransactionDelete == null) return tile;
                return Dismissible(
                  key: ValueKey('tx-${transaction.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    color: AppColors.of(context).expenseRed,
                    child: const Icon(
                      Icons.delete_outline,
                      color: Colors.white,
                    ),
                  ),
                  confirmDismiss: (_) => _confirmDeleteTransaction(context),
                  onDismissed: (_) => onTransactionDelete!(transaction),
                  child: tile,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

Future<bool> _confirmDeleteTransaction(BuildContext context) async {
  final colors = AppColors.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: colors.bgSecondary,
      title: Text('删除账单', style: TextStyle(color: colors.textPrimary)),
      content: Text(
        '删除后可以在提示里撤销。',
        style: TextStyle(color: colors.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text('删除', style: TextStyle(color: colors.expenseRed)),
        ),
      ],
    ),
  );
  return confirmed == true;
}

class TransactionTile extends StatelessWidget {
  final Transaction transaction;
  final bool isLast;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.isLast = false,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.type == TransactionType.expense;
    final sign = isExpense ? '-' : '+';
    final color = isExpense
        ? AppColors.of(context).expenseRed
        : AppColors.of(context).incomeGreen;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: isLast
                ? null
                : Border(
                    bottom: BorderSide(
                      color: AppColors.of(
                        context,
                      ).divider.withValues(alpha: 0.3),
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
                    style: TextStyle(fontSize: 22),
                  ),
                ),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.title,
                      style: TextStyle(
                        color: AppColors.of(context).textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      transaction.tags.isEmpty
                          ? transaction.category.name
                          : '${transaction.category.name} · ${transaction.tags.map((tag) => tag.name).join(' · ')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.of(context).textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$sign¥${formatYuan(transaction.amountCents)}',
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (onDelete != null)
                IconButton(
                  tooltip: '删除',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: onDelete,
                  icon: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: AppColors.of(context).textTertiary,
                  ),
                ),
              if (onTap != null) ...[
                SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppColors.of(
                    context,
                  ).textTertiary.withValues(alpha: 0.7),
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
  final String? label;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const MonthSelector({
    super.key,
    required this.month,
    this.label,
    this.onPrevious,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrevious,
            icon: Icon(
              Icons.chevron_left,
              color: AppColors.of(context).textPrimary,
            ),
          ),
          Expanded(
            child: Text(
              label ?? '${month.year}年${month.month}月',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.of(context).textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: Icon(
              Icons.chevron_right,
              color: AppColors.of(context).textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class ApiErrorView extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;

  const ApiErrorView({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final message = error is ApiException
        ? (error! as ApiException).message
        : '加载失败，请检查后端服务是否已启动';

    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off,
              color: AppColors.of(context).textTertiary,
              size: 48,
            ),
            SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.of(context).textSecondary,
                fontSize: 15,
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.of(context).addBtnBg,
                foregroundColor: Colors.white,
              ),
              child: Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

const deleteHintText = '向左滑或点右侧图标可删除，删除后可以撤销。';

Future<void> deleteTransactionWithUndo({
  required BuildContext context,
  required Transaction transaction,
  required TransactionService service,
  required void Function(VoidCallback fn) update,
  required Set<int> removedIds,
  required VoidCallback onChanged,
}) async {
  update(() => removedIds.add(transaction.id));
  try {
    await service.deleteTransaction(transaction.id);
    if (!context.mounted) return;
    onChanged();
    _showUndoSnackBar(
      context: context,
      transaction: transaction,
      service: service,
      update: update,
      removedIds: removedIds,
      onChanged: onChanged,
    );
  } catch (error) {
    if (!context.mounted) return;
    update(() => removedIds.remove(transaction.id));
    final message = error is ApiException ? error.message : '删除失败，请稍后重试';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}

void offerUndoForDeletedTransaction({
  required BuildContext context,
  required Transaction transaction,
  required TransactionService service,
  required void Function(VoidCallback fn) update,
  required Set<int> removedIds,
  required VoidCallback onChanged,
}) {
  update(() => removedIds.add(transaction.id));
  onChanged();
  _showUndoSnackBar(
    context: context,
    transaction: transaction,
    service: service,
    update: update,
    removedIds: removedIds,
    onChanged: onChanged,
  );
}

void _showUndoSnackBar({
  required BuildContext context,
  required Transaction transaction,
  required TransactionService service,
  required void Function(VoidCallback fn) update,
  required Set<int> removedIds,
  required VoidCallback onChanged,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Text('已删除'),
      action: SnackBarAction(
        label: '撤销',
        onPressed: () async {
          try {
            await service.addTransaction(
              title: transaction.title,
              category: transaction.category,
              amount: transaction.amount,
              type: transaction.type,
              date: transaction.date,
              tagIds: [for (final tag in transaction.tags) tag.id],
            );
            update(() => removedIds.remove(transaction.id));
            onChanged();
          } catch (error) {
            if (!context.mounted) return;
            final message = error is ApiException
                ? error.message
                : '撤销失败，请稍后重试';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message)),
            );
          }
        },
      ),
    ),
  );
}
