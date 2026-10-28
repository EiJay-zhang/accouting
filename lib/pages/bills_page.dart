import 'dart:async';

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../models/transaction.dart';
import '../services/transaction_service.dart';
import '../widgets/transaction_widgets.dart';
import '../utils/money.dart';
import 'add_transaction_page.dart';

enum BillsSpan { week, month, year }

String _formatSpan(DateTime start, DateTime end) {
  if (start.year == end.year && start.month == end.month) {
    return '${start.year}年${start.month}月${start.day}日 - ${end.day}日';
  }
  if (start.year == end.year) {
    return '${start.year}年${start.month}月${start.day}日 - ${end.month}月${end.day}日';
  }
  return '${start.year}年${start.month}月${start.day}日 - ${end.year}年${end.month}月${end.day}日';
}

class BillsPage extends StatefulWidget {
  final VoidCallback? onDataChanged;

  const BillsPage({super.key, this.onDataChanged});

  @override
  State<BillsPage> createState() => BillsPageState();
}

class BillsPageState extends State<BillsPage> {
  final TransactionService _service = TransactionService();
  final Set<int> _removedIds = {};
  final TextEditingController _searchController = TextEditingController();
  late DateTime _selectedMonth;
  BillsSpan _span = BillsSpan.month;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  late Future<List<Transaction>> _billsFuture;
  List<TransactionCategory> _categories = [];
  TransactionType? _typeFilter;
  int? _categoryId;
  String? _categoryName;
  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
    _billsFuture = _fetchBills();
    _loadCategories();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void refresh() {
    _loadBills();
    _loadCategories();
  }

  void focusPeriod({
    required BillsSpan span,
    required DateTime start,
    required DateTime end,
    required int categoryId,
    required String categoryName,
    required TransactionType type,
  }) {
    final rangeStart = DateTime(start.year, start.month, start.day);
    final rangeEnd = DateTime(end.year, end.month, end.day);
    setState(() {
      _span = span;
      _rangeStart = rangeStart;
      _rangeEnd = rangeEnd;
      _selectedMonth = DateTime(rangeStart.year, rangeStart.month);
      _categoryId = categoryId;
      _categoryName = categoryName;
      _typeFilter = type;
      _searchController.clear();
    });
    _loadBills();
  }

  Future<List<Transaction>> _fetchBills() {
    return _service.loadFilteredTransactions(
      month: _selectedMonth,
      keyword: _searchController.text.trim(),
      categoryId: _categoryId,
      type: _typeFilter,
      start: _span == BillsSpan.month ? null : _rangeStart,
      end: _span == BillsSpan.month ? null : _rangeEnd,
    );
  }

  void _loadBills() {
    setState(() {
      _billsFuture = _fetchBills();
    });
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _service.getCategories();
      if (!mounted) return;
      setState(() => _categories = categories);
    } catch (_) {}
  }

  void _changeMonth(int delta) {
    setState(() {
      switch (_span) {
        case BillsSpan.week:
          final start = _rangeStart!.add(Duration(days: 7 * delta));
          _rangeStart = start;
          _rangeEnd = start.add(const Duration(days: 6));
          _selectedMonth = DateTime(start.year, start.month);
        case BillsSpan.month:
          _selectedMonth = DateTime(
            _selectedMonth.year,
            _selectedMonth.month + delta,
          );
        case BillsSpan.year:
          final year = _rangeStart!.year + delta;
          _rangeStart = DateTime(year, 1, 1);
          _rangeEnd = DateTime(year, 12, 31);
          _selectedMonth = DateTime(year, 1);
      }
    });
    _loadBills();
  }

  String get _rangeLabel {
    switch (_span) {
      case BillsSpan.week:
        return _formatSpan(_rangeStart!, _rangeEnd!);
      case BillsSpan.month:
        return '${_selectedMonth.year}年${_selectedMonth.month}月';
      case BillsSpan.year:
        return '${_rangeStart!.year}年';
    }
  }

  String get _emptyPeriodText {
    switch (_span) {
      case BillsSpan.week:
        return '该周暂无账单';
      case BillsSpan.month:
        return '该月暂无账单';
      case BillsSpan.year:
        return '该年暂无账单';
    }
  }

  void _onSearchChanged(String _) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) _loadBills();
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

  bool get _hasFilter =>
      _searchController.text.trim().isNotEmpty ||
      _typeFilter != null ||
      _categoryId != null;

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
              label: _rangeLabel,
              onPrevious: () => _changeMonth(-1),
              onNext: () => _changeMonth(1),
            ),
            _buildFilters(),
            Expanded(
              child: FutureBuilder<List<Transaction>>(
                future: _billsFuture,
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
                      onRetry: _loadBills,
                    );
                  }

                  final transactions = (snapshot.data ?? [])
                      .where((item) => !_removedIds.contains(item.id))
                      .toList();
                  return RefreshIndicator(
                    color: AppColors.of(context).addBtnBg,
                    backgroundColor: AppColors.of(context).bgSecondary,
                    onRefresh: () async {
                      _loadBills();
                      await _billsFuture;
                    },
                    child: transactions.isEmpty
                        ? ListView(
                            physics: AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(height: 80),
                              Center(
                                child: Text(
                                  _hasFilter ? '没有符合条件的账单' : _emptyPeriodText,
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
                              Padding(
                                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                                child: Text(
                                  deleteHintText,
                                  style: TextStyle(
                                    color: AppColors.of(context).textTertiary,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              _buildSummaryBar(transactions),
                              ...groupTransactions(transactions).map(
                                (group) => TransactionGroupCard(
                                  group: group,
                                  onTransactionTap: _openEditTransaction,
                                  onTransactionDelete: _deleteTransaction,
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

  void _selectType(TransactionType? type) {
    final categoryStillVisible =
        _categoryId == null ||
        _categories.any(
          (item) =>
              item.id == _categoryId && (type == null || item.type == type),
        );
    setState(() {
      _typeFilter = type;
      if (!categoryStillVisible) {
        _categoryId = null;
        _categoryName = null;
      }
    });
    _loadBills();
  }

  Widget _buildFilters() {
    final colors = AppColors.of(context);
    final selectedCategory = _categories
        .where((item) => item.id == _categoryId)
        .firstOrNull;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: TextStyle(color: colors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: '搜索标题、分类或标签',
              hintStyle: TextStyle(color: colors.textTertiary, fontSize: 14),
              prefixIcon: Icon(
                Icons.search,
                color: colors.textTertiary,
                size: 20,
              ),
              filled: true,
              fillColor: colors.bgSecondary,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          SizedBox(height: 10),
          Container(
            padding: EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: colors.bgSecondary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                _TypeSegment(
                  label: '全部',
                  selected: _typeFilter == null,
                  onTap: () => _selectType(null),
                ),
                _TypeSegment(
                  label: '支出',
                  selected: _typeFilter == TransactionType.expense,
                  onTap: () => _selectType(TransactionType.expense),
                ),
                _TypeSegment(
                  label: '收入',
                  selected: _typeFilter == TransactionType.income,
                  onTap: () => _selectType(TransactionType.income),
                ),
              ],
            ),
          ),
          SizedBox(height: 10),
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.bgSecondary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) {
                      return PopupMenuButton<int?>(
                        padding: EdgeInsets.zero,
                        offset: Offset(0, 46),
                        color: colors.bgSecondary,
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        constraints: BoxConstraints(
                          minWidth: box.maxWidth,
                          maxWidth: box.maxWidth,
                        ),
                        onSelected: (value) {
                          setState(() {
                            _categoryId = value;
                            _categoryName = value == null
                                ? null
                                : _categories
                                      .where((item) => item.id == value)
                                      .map((item) => item.name)
                                      .firstOrNull;
                          });
                          _loadBills();
                        },
                        itemBuilder: (context) {
                          final visible = _categories.where((item) {
                            if (_typeFilter == null) return true;
                            return item.type == _typeFilter;
                          });
                          return [
                            PopupMenuItem<int?>(
                              value: null,
                              child: Text('全部分类'),
                            ),
                            for (final category in visible)
                              PopupMenuItem<int?>(
                                value: category.id,
                                child: Text(
                                  '${category.icon} ${category.name}',
                                ),
                              ),
                          ];
                        },
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(14, 12, 8, 12),
                          child: Row(
                            children: [
                              Text(
                                selectedCategory?.icon ?? '',
                                style: TextStyle(fontSize: 16),
                              ),
                              if (selectedCategory != null) SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _categoryName ?? '全部分类',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _categoryId == null
                                        ? colors.textSecondary
                                        : colors.textPrimary,
                                    fontSize: 14,
                                    fontWeight: _categoryId == null
                                        ? FontWeight.w500
                                        : FontWeight.w600,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.expand_more,
                                color: colors.textTertiary,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (_categoryId != null)
                  IconButton(
                    tooltip: '清除分类',
                    onPressed: () {
                      setState(() {
                        _categoryId = null;
                        _categoryName = null;
                      });
                      _loadBills();
                    },
                    icon: Icon(
                      Icons.close,
                      size: 18,
                      color: colors.textTertiary,
                    ),
                  )
                else
                  SizedBox(width: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar(List<Transaction> transactions) {
    final income = transactions
        .where((item) => item.type == TransactionType.income)
        .fold(0, (sum, item) => sum + item.amountCents);
    final expense = transactions
        .where((item) => item.type == TransactionType.expense)
        .fold(0, (sum, item) => sum + item.amountCents);
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
            _buildSummaryItem(
              '收入',
              income,
              AppColors.of(context).incomeGreen,
              '+',
            ),
            Container(
              width: 1,
              height: 36,
              color: AppColors.of(context).divider,
            ),
            _buildSummaryItem(
              '支出',
              expense,
              AppColors.of(context).expenseRed,
              '-',
            ),
            Container(
              width: 1,
              height: 36,
              color: AppColors.of(context).divider,
            ),
            _buildSummaryItem(
              '结余',
              income - expense,
              AppColors.of(context).textPrimary,
              '',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    String label,
    int cents,
    Color color,
    String prefix,
  ) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.of(context).textSecondary,
              fontSize: 12,
            ),
          ),
          SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$prefix¥${formatYuan(cents.abs())}',
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeSegment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TypeSegment({
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
