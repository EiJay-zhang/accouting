import 'dart:async';

import 'package:flutter/material.dart';

import '../api/item_api.dart';
import '../constants/app_colors.dart';
import '../models/item.dart';
import '../utils/money.dart';
import '../widgets/transaction_widgets.dart';
import 'item_edit_page.dart';

class ItemsPage extends StatefulWidget {
  final VoidCallback? onDataChanged;

  const ItemsPage({super.key, this.onDataChanged});

  @override
  State<ItemsPage> createState() => _ItemsPageState();
}

class _ItemsPageState extends State<ItemsPage> {
  final ItemApi _api = ItemApi();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchTimer;
  ItemStatus? _statusFilter;
  late Future<_ItemsData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _load();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<_ItemsData> _load() async {
    final items = await _api.fetchItems(
      keyword: _searchController.text,
      status: _statusFilter,
    );
    final summary = await _api.fetchSummary();
    return _ItemsData(items: items, summary: summary);
  }

  void _reload() {
    setState(() {
      _dataFuture = _load();
    });
    widget.onDataChanged?.call();
  }

  void _onSearchChanged(String _) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _reload();
    });
  }

  void _selectStatus(ItemStatus? status) {
    setState(() {
      _statusFilter = status;
      _dataFuture = _load();
    });
  }

  Future<void> _openEditor([Item? item]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ItemEditPage(item: item)),
    );
    if (saved == true && mounted) _reload();
  }

  bool get _hasFilter =>
      _statusFilter != null || _searchController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.bgPrimary,
      appBar: AppBar(
        backgroundColor: colors.bgPrimary,
        elevation: 0,
        title: Text(
          '物品管理',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        backgroundColor: colors.addBtnBg,
        child: Icon(Icons.add_rounded, color: colors.addBtnIcon, size: 32),
      ),
      body: SafeArea(
        child: FutureBuilder<_ItemsData>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(color: colors.addBtnBg),
              );
            }
            if (snapshot.hasError) {
              return ApiErrorView(error: snapshot.error, onRetry: _reload);
            }

            final data = snapshot.data!;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: _SummaryCard(summary: data.summary),
                ),
                _buildFilters(colors),
                Expanded(
                  child: RefreshIndicator(
                    color: colors.addBtnBg,
                    backgroundColor: colors.bgSecondary,
                    onRefresh: () async {
                      _reload();
                      await _dataFuture;
                    },
                    child: data.items.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              const SizedBox(height: 80),
                              Center(
                                child: Text(
                                  _hasFilter
                                      ? '没有符合条件的物品'
                                      : '还没有物品档案\n点右下角 + 记录第一件大件消费',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: colors.textTertiary,
                                    fontSize: 15,
                                    height: 1.6,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                            children: _buildSections(data.items, colors),
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

  Widget _buildFilters(AppColors colors) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: TextStyle(color: colors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: '搜索物品名称、用途或备注',
              hintStyle: TextStyle(color: colors.textTertiary, fontSize: 14),
              prefixIcon: Icon(
                Icons.search,
                color: colors.textTertiary,
                size: 20,
              ),
              filled: true,
              fillColor: colors.bgSecondary,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              _StatusChip(
                label: '全部',
                selected: _statusFilter == null,
                onTap: () => _selectStatus(null),
              ),
              for (final status in ItemStatus.values)
                _StatusChip(
                  label: status.label,
                  selected: _statusFilter == status,
                  onTap: () => _selectStatus(status),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  List<Widget> _buildSections(List<Item> items, AppColors colors) {
    final groups = <String, List<Item>>{};
    for (final item in items) {
      groups.putIfAbsent(item.category, () => []).add(item);
    }

    return [
      for (final entry in groups.entries) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 6, 2, 8),
          child: Row(
            children: [
              Text(
                entry.value.first.categoryIcon ?? '📦',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 6),
              Text(
                entry.key,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${entry.value.length} 件 · ¥${formatYuan(entry.value.fold<int>(0, (sum, item) => sum + item.amountCents))}',
                style: TextStyle(color: colors.textTertiary, fontSize: 12),
              ),
            ],
          ),
        ),
        for (final item in entry.value)
          _ItemCard(item: item, onTap: () => _openEditor(item)),
        const SizedBox(height: 8),
      ],
    ];
  }
}

class _ItemsData {
  final List<Item> items;
  final ItemSummary summary;

  const _ItemsData({required this.items, required this.summary});
}

class _SummaryCard extends StatelessWidget {
  final ItemSummary summary;

  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        color: colors.bgSecondary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '物品总价值',
            style: TextStyle(color: colors.textTertiary, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            '¥${formatYuan(summary.totalAmountCents)}',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Divider(height: 22, thickness: 1, color: colors.divider),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: '物品件数',
                  value: '${summary.count} 件',
                ),
              ),
              Container(width: 1, height: 28, color: colors.divider),
              Expanded(
                child: _Stat(
                  label: '在用',
                  value: '${summary.inUseCount} 件',
                ),
              ),
              Container(width: 1, height: 28, color: colors.divider),
              Expanded(
                child: _Stat(
                  label: '已实现盈亏',
                  value: summary.totalProfitCents >= 0
                      ? '+¥${formatYuan(summary.totalProfitCents)}'
                      : '-¥${formatYuan(summary.totalProfitCents.abs())}',
                  valueColor: summary.totalProfitCents >= 0
                      ? colors.incomeGreen
                      : colors.expenseRed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _Stat({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      children: [
        Text(label, style: TextStyle(color: colors.textTertiary, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? colors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _StatusChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? colors.addBtnBg : colors.bgSecondary,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : colors.textSecondary,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final Item item;
  final VoidCallback onTap;

  const _ItemCard({required this.item, required this.onTap});

  Color _statusColor(AppColors colors) {
    switch (item.status) {
      case ItemStatus.inUse:
        return colors.incomeGreen;
      case ItemStatus.idle:
        return colors.textTertiary;
      case ItemStatus.sold:
        return colors.accentPurple;
      case ItemStatus.retired:
        return colors.expenseRed;
    }
  }

  String get _warrantyText {
    final left = item.warrantyDaysLeft;
    if (left == null) return '';
    if (left > 0) return '保修剩 $left 天';
    if (left == 0) return '保修今天到期';
    return '已过保';
  }

  Color _warrantyColor(AppColors colors) {
    final left = item.warrantyDaysLeft;
    if (left == null || left <= 0) return colors.textTertiary;
    return colors.incomeGreen;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final statusColor = _statusColor(colors);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: colors.bgSecondary,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: item.categoryColor != null
                          ? Color(int.parse(item.categoryColor!.substring(1), radix: 16) + 0xFF000000).withValues(alpha: 0.15)
                          : colors.bgCardLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      item.categoryIcon ?? '📦',
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.purpose.isEmpty ? item.category : item.purpose,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '¥${formatYuan(item.amountCents)}',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.status.label,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  _InfoText(
                    text: '购买 ${_formatDate(item.purchaseDate)}',
                  ),
                  if (item.status == ItemStatus.sold && item.soldDate != null)
                    _InfoText(text: '出售 ${_formatDate(item.soldDate!)}'),
                  if (item.status == ItemStatus.sold && item.heldDays != null)
                    _InfoText(text: '持有 ${item.heldDays} 天')
                  else
                    _InfoText(text: '已使用 ${item.daysUsed} 天'),
                  if (item.status != ItemStatus.sold)
                    _InfoText(text: '日均 ¥${formatYuan(item.dailyCostCents)}'),
                  if (item.status == ItemStatus.sold && item.profitCents != null)
                    _InfoText(
                      text: _formatProfit(item.profitCents!),
                      color: item.profitCents! >= 0
                          ? colors.incomeGreen
                          : colors.expenseRed,
                    ),
                  if (_warrantyText.isNotEmpty)
                    _InfoText(
                      text: _warrantyText,
                      color: _warrantyColor(colors),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  String _formatProfit(int profitCents) {
    final sign = profitCents >= 0 ? '赚 ' : '亏 ';
    return '$sign¥${formatYuan(profitCents.abs())}';
  }
}

class _InfoText extends StatelessWidget {
  final String text;
  final Color? color;

  const _InfoText({required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: color ?? AppColors.of(context).textTertiary,
        fontSize: 12,
      ),
    );
  }
}
