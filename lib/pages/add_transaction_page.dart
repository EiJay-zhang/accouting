import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../constants/app_colors.dart';
import '../models/transaction.dart';
import '../services/transaction_service.dart';
import 'category_manage_page.dart';
import 'tag_manage_page.dart';

class AddTransactionPage extends StatefulWidget {
  final Transaction? transaction;

  const AddTransactionPage({super.key, this.transaction});

  bool get isEditing => transaction != null;

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  final TransactionService _service = TransactionService();
  final _amountController = TextEditingController();
  final _titleController = TextEditingController();

  TransactionType _selectedType = TransactionType.expense;
  List<TransactionCategory> _categories = [];
  List<CategoryTag> _tags = [];
  TransactionCategory? _selectedCategory;
  late DateTime _selectedDate;
  bool _loadingCategories = true;
  bool _submitting = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    final existing = widget.transaction;
    if (existing != null) {
      _selectedType = existing.type;
      _amountController.text = existing.amount % 1 == 0
          ? existing.amount.toInt().toString()
          : existing.amount.toStringAsFixed(2);
      _titleController.text = existing.title;
      _selectedDate = existing.date;
    } else {
      _selectedDate = DateTime.now();
    }
    _titleController.addListener(_onTitleChanged);
    _loadCategories();
  }

  void _onTitleChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadCategories() async {
    try {
      final results = await Future.wait([
        _service.getCategories(),
        _service.getTags(),
      ]);
      final categories = results[0] as List<TransactionCategory>;
      final tags = results[1] as List<CategoryTag>;
      if (!mounted) return;

      final visible =
          categories.where((category) => category.type == _selectedType);
      TransactionCategory? selected;
      final preferredId = _selectedCategory?.id ?? widget.transaction?.category.id;
      if (preferredId != null) {
        for (final category in visible) {
          if (category.id == preferredId) {
            selected = category;
            break;
          }
        }
      }
      selected ??= visible.isNotEmpty ? visible.first : null;

      setState(() {
        _categories = categories;
        _tags = tags;
        _selectedCategory = selected;
        _loadingCategories = false;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingCategories = false;
        _loadError = error is ApiException
            ? error.message
            : '分类加载失败，请检查后端服务';
      });
    }
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTitleChanged);
    _amountController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  List<CategoryTag> get _visibleTags {
    final categoryId = _selectedCategory?.id;
    if (categoryId == null) return const [];
    return _tags.where((tag) => tag.categoryId == categoryId).toList();
  }

  void _applyTag(CategoryTag tag) {
    final next = _titleController.text == tag.name ? '' : tag.name;
    _titleController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  Future<void> _reloadTags() async {
    try {
      final tags = await _service.getTags();
      if (!mounted) return;
      setState(() => _tags = tags);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.of(context).bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.of(context).bgPrimary,
        elevation: 0,
        title: Text(
          widget.isEditing ? '编辑账单' : '记一笔',
          style: TextStyle(
            color: AppColors.of(context).textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.close, color: AppColors.of(context).textPrimary),
          onPressed: _submitting ? null : () => Navigator.pop(context),
        ),
        actions: [
          if (widget.isEditing)
            IconButton(
              icon: Icon(Icons.delete_outline, color: AppColors.of(context).expenseRed),
              onPressed: _submitting ? null : _confirmDelete,
            ),
        ],
      ),
      body: SafeArea(
        child: _loadingCategories
            ? Center(
                child: CircularProgressIndicator(color: AppColors.of(context).addBtnBg),
              )
            : _loadError != null
                ? _buildLoadError()
                : SingleChildScrollView(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildTypeSwitch(),
                        SizedBox(height: 24),
                        _buildAmountInput(),
                        SizedBox(height: 16),
                        _buildTitleInput(),
                        SizedBox(height: 12),
                        _buildTagShortcuts(),
                        SizedBox(height: 16),
                        _buildDateSelector(),
                        SizedBox(height: 20),
                        _buildCategorySelector(),
                        SizedBox(height: 24),
                        _buildSubmitButton(),
                        SizedBox(height: 20),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _loadError!,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.of(context).textSecondary),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _loadingCategories = true;
                  _loadError = null;
                });
                _loadCategories();
              },
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

  Widget _buildTypeSwitch() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.of(context).bgSecondary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _submitting
                  ? null
                  : () => _selectType(TransactionType.expense),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _selectedType == TransactionType.expense
                      ? AppColors.of(context).expenseRed.withValues(alpha: 0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '支出',
                    style: TextStyle(
                      color: _selectedType == TransactionType.expense
                          ? AppColors.of(context).expenseRed
                          : AppColors.of(context).textTertiary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: _submitting
                  ? null
                  : () => _selectType(TransactionType.income),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _selectedType == TransactionType.income
                      ? AppColors.of(context).incomeGreen.withValues(alpha: 0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '收入',
                    style: TextStyle(
                      color: _selectedType == TransactionType.income
                          ? AppColors.of(context).incomeGreen
                          : AppColors.of(context).textTertiary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountInput() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.of(context).bgSecondary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            _selectedType == TransactionType.expense ? '-' : '+',
            style: TextStyle(
              color: _selectedType == TransactionType.expense
                  ? AppColors.of(context).expenseRed
                  : AppColors.of(context).incomeGreen,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _amountController,
              enabled: !_submitting,
              style: TextStyle(
                color: AppColors.of(context).textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                hintText: '0.00',
                hintStyle: TextStyle(color: AppColors.of(context).textTertiary),
                border: InputBorder.none,
              ),
              keyboardType:
                  TextInputType.numberWithOptions(decimal: true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagShortcuts() {
    if (_selectedCategory == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_visibleTags.isEmpty)
          Text(
            '这个分类还没有标签，可在下方管理标签里添加',
            style: TextStyle(color: AppColors.of(context).textTertiary, fontSize: 13),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in _visibleTags)
                _TagChip(
                  label: tag.name,
                  selected: _titleController.text == tag.name,
                  onTap: _submitting ? null : () => _applyTag(tag),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildTitleInput() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.of(context).bgSecondary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _titleController,
        enabled: !_submitting,
        style: TextStyle(color: AppColors.of(context).textPrimary, fontSize: 15),
        decoration: InputDecoration(
          hintText: '添加备注...',
          hintStyle: TextStyle(color: AppColors.of(context).textTertiary),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    final label =
        '${_selectedDate.year}年${_selectedDate.month}月${_selectedDate.day}日';

    return InkWell(
      onTap: _submitting ? null : _pickDate,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.of(context).bgSecondary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: AppColors.of(context).textTertiary, size: 18),
            SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(color: AppColors.of(context).textPrimary, fontSize: 15),
            ),
            Spacer(),
            Icon(Icons.chevron_right, color: AppColors.of(context).textTertiary, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _selectType(TransactionType type) {
    if (type == _selectedType) return;
    final visible = _categories.where((category) => category.type == type).toList();
    setState(() {
      _selectedType = type;
      _selectedCategory = visible.isNotEmpty ? visible.first : null;
    });
  }

  List<TransactionCategory> get _visibleCategories =>
      _categories.where((category) => category.type == _selectedType).toList();

  Future<void> _openTagManager() async {
    final category = _selectedCategory;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => category == null
            ? TagManagePage(initialType: _selectedType)
            : CategoryTagsPage(category: category),
      ),
    );
    if (!mounted) return;
    await _reloadTags();
  }

  Future<void> _openCategoryManager() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryManagePage(initialType: _selectedType),
      ),
    );
    if (!mounted) return;
    await _loadCategories();
  }

  Widget _buildCategorySelector() {
    final visible = _visibleCategories;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            '选择分类',
            style: TextStyle(
              color: AppColors.of(context).textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (visible.isEmpty)
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.of(context).bgSecondary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _selectedType == TransactionType.expense
                  ? '还没有支出分类'
                  : '还没有收入分类',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.of(context).textTertiary),
            ),
          )
        else
          GridView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: visible.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemBuilder: (context, index) {
            final cat = visible[index];
            final isSelected = _selectedCategory?.id == cat.id;
            return GestureDetector(
              onTap: _submitting
                  ? null
                  : () => setState(() => _selectedCategory = cat),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? cat.color.withValues(alpha: 0.25)
                      : AppColors.of(context).bgSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? cat.color
                        : AppColors.of(context).divider.withValues(alpha: 0.3),
                    width: isSelected ? 2 : 0.5,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(cat.icon, style: TextStyle(fontSize: 28)),
                    SizedBox(height: 4),
                    Text(
                      cat.name,
                      style: TextStyle(
                        color: isSelected
                            ? AppColors.of(context).textPrimary
                            : AppColors.of(context).textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: _submitting ? null : _openTagManager,
                child: const Text('管理标签'),
              ),
              TextButton(
                onPressed: _submitting ? null : _openCategoryManager,
                child: const Text('管理分类'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _submitting ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.of(context).addBtnBg,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _submitting
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                widget.isEditing ? '保存修改' : '保存',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('请输入有效金额')),
      );
      return;
    }

    final category = _selectedCategory;
    if (category == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('请选择分类')),
      );
      return;
    }

    final title = _titleController.text.isEmpty ? category.name : _titleController.text;

    setState(() => _submitting = true);

    try {
      if (widget.isEditing) {
        await _service.updateTransaction(
          transaction: widget.transaction!,
          title: title,
          category: category,
          amount: amount,
          type: _selectedType,
          date: _selectedDate,
        );
      } else {
        await _service.addTransaction(
          title: title,
          category: category,
          amount: amount,
          type: _selectedType,
          date: _selectedDate,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      final message = error is ApiException
          ? error.message
          : '保存失败，请稍后重试';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.of(context).bgSecondary,
        title: Text('删除账单', style: TextStyle(color: AppColors.of(context).textPrimary)),
        content: Text(
          '确定要删除这条账单吗？此操作不可撤销。',
          style: TextStyle(color: AppColors.of(context).textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('删除', style: TextStyle(color: AppColors.of(context).expenseRed)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    try {
      await _service.deleteTransaction(widget.transaction!.id);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      final message = error is ApiException
          ? error.message
          : '删除失败，请稍后重试';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _TagChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      color: selected ? colors.addBtnBg : colors.bgSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected ? colors.addBtnBg : colors.divider,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : colors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
