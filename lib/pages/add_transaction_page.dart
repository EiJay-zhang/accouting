import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../constants/app_colors.dart';
import '../models/transaction.dart';
import '../services/transaction_service.dart';

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
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _service.getCategories();
      if (!mounted) return;

      TransactionCategory? selected;
      final existing = widget.transaction;
      if (existing != null) {
        for (final cat in categories) {
          if (cat.id == existing.category.id) {
            selected = cat;
            break;
          }
        }
      }
      selected ??= categories.isNotEmpty ? categories.first : null;

      setState(() {
        _categories = categories;
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
    _amountController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        title: Text(
          widget.isEditing ? '编辑账单' : '记一笔',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: _submitting ? null : () => Navigator.pop(context),
        ),
        actions: [
          if (widget.isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.expenseRed),
              onPressed: _submitting ? null : _confirmDelete,
            ),
        ],
      ),
      body: SafeArea(
        child: _loadingCategories
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.addBtnBg),
              )
            : _loadError != null
                ? _buildLoadError()
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildTypeSwitch(),
                        const SizedBox(height: 24),
                        _buildAmountInput(),
                        const SizedBox(height: 16),
                        _buildTitleInput(),
                        const SizedBox(height: 16),
                        _buildDateSelector(),
                        const SizedBox(height: 20),
                        _buildCategorySelector(),
                        const SizedBox(height: 24),
                        _buildSubmitButton(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _loadError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _loadingCategories = true;
                  _loadError = null;
                });
                _loadCategories();
              },
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

  Widget _buildTypeSwitch() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _submitting
                  ? null
                  : () => setState(() => _selectedType = TransactionType.expense),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _selectedType == TransactionType.expense
                      ? AppColors.expenseRed.withValues(alpha: 0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '支出',
                    style: TextStyle(
                      color: _selectedType == TransactionType.expense
                          ? AppColors.expenseRed
                          : AppColors.textTertiary,
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
                  : () => setState(() => _selectedType = TransactionType.income),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _selectedType == TransactionType.income
                      ? AppColors.incomeGreen.withValues(alpha: 0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '收入',
                    style: TextStyle(
                      color: _selectedType == TransactionType.income
                          ? AppColors.incomeGreen
                          : AppColors.textTertiary,
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            _selectedType == TransactionType.expense ? '-' : '+',
            style: TextStyle(
              color: _selectedType == TransactionType.expense
                  ? AppColors.expenseRed
                  : AppColors.incomeGreen,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _amountController,
              enabled: !_submitting,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              decoration: const InputDecoration(
                hintText: '0.00',
                hintStyle: TextStyle(color: AppColors.textTertiary),
                border: InputBorder.none,
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _titleController,
        enabled: !_submitting,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
        decoration: const InputDecoration(
          hintText: '添加备注...',
          hintStyle: TextStyle(color: AppColors.textTertiary),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.bgSecondary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: AppColors.textTertiary, size: 18),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: AppColors.textTertiary, size: 20),
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.addBtnBg,
              surface: AppColors.bgSecondary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            '选择分类',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _categories.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemBuilder: (context, index) {
            final cat = _categories[index];
            final isSelected = _selectedCategory?.id == cat.id;
            return GestureDetector(
              onTap: _submitting
                  ? null
                  : () => setState(() => _selectedCategory = cat),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? cat.color.withValues(alpha: 0.25)
                      : AppColors.bgSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? cat.color
                        : AppColors.divider.withValues(alpha: 0.3),
                    width: isSelected ? 2 : 0.5,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(cat.icon, style: const TextStyle(fontSize: 28)),
                    const SizedBox(height: 4),
                    Text(
                      cat.name,
                      style: TextStyle(
                        color: isSelected
                            ? AppColors.textPrimary
                            : AppColors.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
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
          backgroundColor: AppColors.addBtnBg,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _submitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                widget.isEditing ? '保存修改' : '保存',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效金额')),
      );
      return;
    }

    final category = _selectedCategory;
    if (category == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择分类')),
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
        backgroundColor: AppColors.bgSecondary,
        title: const Text('删除账单', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          '确定要删除这条账单吗？此操作不可撤销。',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: AppColors.expenseRed)),
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
