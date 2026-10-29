import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/item_api.dart';
import '../api/transaction_api.dart';
import '../constants/app_colors.dart';
import '../models/item.dart';
import '../models/transaction.dart';
import '../utils/money.dart';

class ItemEditPage extends StatefulWidget {
  final Item? item;

  const ItemEditPage({super.key, this.item});

  bool get isEditing => item != null;

  @override
  State<ItemEditPage> createState() => _ItemEditPageState();
}

class _ItemEditPageState extends State<ItemEditPage> {
  final ItemApi _api = ItemApi();
  final TransactionApi _catApi = TransactionApi();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _soldAmountController = TextEditingController();
  final _purposeController = TextEditingController();
  final _noteController = TextEditingController();

  List<TransactionCategory> _expenseCategories = const [];
  bool _categoriesLoading = true;
  int? _categoryId;
  late DateTime _purchaseDate;
  DateTime? _warrantyUntil;
  DateTime? _soldDate;
  late ItemStatus _status;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.item;
    _nameController.text = existing?.name ?? '';
    _amountController.text = existing == null
        ? ''
        : existing.amount % 1 == 0
        ? existing.amount.toInt().toString()
        : existing.amount.toStringAsFixed(2);
    final sold = existing?.soldAmount;
    _soldAmountController.text = sold == null
        ? ''
        : sold % 1 == 0
        ? sold.toInt().toString()
        : sold.toStringAsFixed(2);
    _purposeController.text = existing?.purpose ?? '';
    _noteController.text = existing?.note ?? '';
    _purchaseDate = existing?.purchaseDate ?? DateTime.now();
    _warrantyUntil = existing?.warrantyUntil;
    _soldDate = existing?.soldDate;
    _categoryId = existing?.categoryId;
    _status = existing?.status ?? ItemStatus.inUse;
    _amountController.addListener(_onAmountChanged);
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _catApi.fetchCategories(type: TransactionType.expense);
      if (!mounted) return;
      setState(() {
        _expenseCategories = cats;
        _categoriesLoading = false;
      });
      // 如果还没选过分类，默认选第一个
      if (_categoryId == null && cats.isNotEmpty) {
        setState(() => _categoryId = cats.first.id);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _categoriesLoading = false);
    }
  }

  void _onAmountChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _nameController.dispose();
    _amountController.dispose();
    _soldAmountController.dispose();
    _purposeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  int? get _amountCents {
    final value = double.tryParse(_amountController.text.trim());
    if (value == null || value <= 0) return null;
    return (value * 100).round();
  }

  int get _daysUsed {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(
      _purchaseDate.year,
      _purchaseDate.month,
      _purchaseDate.day,
    );
    final days = today.difference(day).inDays;
    return days < 0 ? 0 : days;
  }

  String? get _previewText {
    final cents = _amountCents;
    if (cents == null) return null;
    final days = _daysUsed;
    final perDay = cents ~/ (days < 1 ? 1 : days);
    return '已使用 $days 天，日均成本 ¥${formatYuan(perDay)}';
  }

  Future<void> _pickPurchaseDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _purchaseDate = picked);
    }
  }

  Future<void> _pickWarrantyDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _warrantyUntil ?? _purchaseDate,
      firstDate: _purchaseDate,
      lastDate: DateTime(DateTime.now().year + 20, 12, 31),
    );
    if (picked != null) {
      setState(() => _warrantyUntil = picked);
    }
  }

  Future<void> _pickSoldDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _soldDate ?? DateTime.now(),
      firstDate: _purchaseDate,
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _soldDate = picked);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showMessage('请填写物品名称');
      return;
    }
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      _showMessage('请填写有效的购买金额');
      return;
    }

    setState(() => _submitting = true);
    try {
      final soldAmountText = _soldAmountController.text.trim();
      double? soldAmount;
      if (_status == ItemStatus.sold) {
        if (soldAmountText.isEmpty) {
          setState(() => _submitting = false);
          _showMessage('请填写出售金额');
          return;
        }
        soldAmount = double.tryParse(soldAmountText);
        if (soldAmount == null || soldAmount < 0) {
          setState(() => _submitting = false);
          _showMessage('请填写有效的出售金额');
          return;
        }
      } else {
        soldAmount = null;
      }
      final soldDate = _status == ItemStatus.sold
          ? (_soldDate ?? DateTime.now())
          : null;

      if (_categoryId == null) {
        setState(() => _submitting = false);
        _showMessage('请选择物品分类');
        return;
      }

      if (widget.isEditing) {
        await _api.updateItem(
          id: widget.item!.id,
          name: name,
          categoryId: _categoryId!,
          amount: amount,
          purchaseDate: _purchaseDate,
          purpose: _purposeController.text.trim(),
          status: _status,
          soldAmount: soldAmount,
          soldDate: soldDate,
          warrantyUntil: _warrantyUntil,
          note: _noteController.text.trim(),
        );
      } else {
        await _api.createItem(
          name: name,
          categoryId: _categoryId!,
          amount: amount,
          purchaseDate: _purchaseDate,
          purpose: _purposeController.text.trim(),
          status: _status,
          soldAmount: soldAmount,
          soldDate: soldDate,
          warrantyUntil: _warrantyUntil,
          note: _noteController.text.trim(),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      final message = error is ApiException ? error.message : '保存失败，请稍后重试';
      setState(() => _submitting = false);
      _showMessage(message);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除物品'),
        content: Text('确定删除「${widget.item?.name ?? ''}」的档案吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.of(context).expenseRed,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _submitting = true);
    try {
      await _api.deleteItem(widget.item!.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      final message = error is ApiException ? error.message : '删除失败，请稍后重试';
      setState(() => _submitting = false);
      _showMessage(message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.bgPrimary,
      appBar: AppBar(
        backgroundColor: colors.bgPrimary,
        elevation: 0,
        title: Text(
          widget.isEditing ? '编辑物品' : '新增物品',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.close, color: colors.textPrimary),
          onPressed: _submitting ? null : () => Navigator.pop(context),
        ),
        actions: [
          if (widget.isEditing)
            IconButton(
              tooltip: '删除',
              icon: Icon(Icons.delete_outline, color: colors.expenseRed),
              onPressed: _submitting ? null : _confirmDelete,
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildAmountInput(colors),
              if (_previewText != null) ...[
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    _previewText!,
                    style: TextStyle(color: colors.textTertiary, fontSize: 12),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              _SectionLabel('物品名称'),
              _buildTextField(
                colors,
                controller: _nameController,
                hint: '例如 笔记本电脑、电动车',
                maxLength: 60,
              ),
              const SizedBox(height: 20),
              _SectionLabel('购买日期'),
              _buildValueTile(
                colors,
                value: _formatDate(_purchaseDate),
                onTap: _pickPurchaseDate,
              ),
              const SizedBox(height: 20),
              _SectionLabel('物品分类'),
              _buildCategoryPicker(colors),
              const SizedBox(height: 20),
              _SectionLabel('当前状态'),
              _buildChoiceWrap(
                colors,
                options: ItemStatus.values,
                selected: _status,
                labelOf: (value) => value.label,
                onSelect: (value) {
                  setState(() {
                    _status = value;
                    if (value != ItemStatus.sold) {
                      _soldAmountController.clear();
                      _soldDate = null;
                    }
                  });
                },
              ),
              if (_status == ItemStatus.sold) ...[
                const SizedBox(height: 20),
                _SectionLabel('出售金额'),
                _buildSoldAmountInput(colors),
                const SizedBox(height: 12),
                _SectionLabel('出售日期'),
                _buildValueTile(
                  colors,
                  value: _soldDate == null
                      ? '请选择日期'
                      : _formatDate(_soldDate!),
                  muted: _soldDate == null,
                  onTap: _pickSoldDate,
                  onClear: _soldDate == null
                      ? null
                      : () => setState(() => _soldDate = null),
                ),
              ],
              const SizedBox(height: 20),
              _SectionLabel('保修到期日（选填）'),
              _buildValueTile(
                colors,
                value: _warrantyUntil == null
                    ? '未设置'
                    : _formatDate(_warrantyUntil!),
                muted: _warrantyUntil == null,
                onTap: _pickWarrantyDate,
                onClear: _warrantyUntil == null
                    ? null
                    : () => setState(() => _warrantyUntil = null),
              ),
              const SizedBox(height: 20),
              _SectionLabel('用途'),
              _buildTextField(
                colors,
                controller: _purposeController,
                hint: '例如 通勤代步、主力办公',
                maxLines: 2,
                maxLength: 200,
              ),
              const SizedBox(height: 20),
              _SectionLabel('备注'),
              _buildTextField(
                colors,
                controller: _noteController,
                hint: '维修记录、使用心得等',
                maxLines: 3,
                maxLength: 500,
              ),
              const SizedBox(height: 28),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.addBtnBg,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(widget.isEditing ? '保存修改' : '保存档案'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmountInput(AppColors colors) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      decoration: BoxDecoration(
        color: colors.bgSecondary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '购入金额',
            style: TextStyle(color: colors.textTertiary, fontSize: 13),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '¥',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: _amountController,
                  enabled: !_submitting,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    hintStyle: TextStyle(
                      color: colors.textTertiary,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPicker(AppColors colors) {
    if (_categoriesLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.addBtnBg,
            ),
          ),
        ),
      );
    }
    if (_expenseCategories.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.bgSecondary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '还没有支出分类，请先到"我的 → 分类管理"里添加',
          style: TextStyle(color: colors.textTertiary, fontSize: 13),
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final cat in _expenseCategories)
          GestureDetector(
            onTap: _submitting
                ? null
                : () => setState(() => _categoryId = cat.id),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: _categoryId == cat.id
                    ? cat.color
                    : colors.bgSecondary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    cat.icon,
                    style: TextStyle(
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    cat.name,
                    style: TextStyle(
                      color: _categoryId == cat.id
                          ? Colors.white
                          : colors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSoldAmountInput(AppColors colors) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: colors.bgSecondary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '¥',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _soldAmountController,
              enabled: !_submitting,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: '0.00',
                hintStyle: TextStyle(
                  color: colors.textTertiary,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    AppColors colors, {
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    int? maxLength,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: colors.bgSecondary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        enabled: !_submitting,
        maxLines: maxLines,
        maxLength: maxLength,
        style: TextStyle(color: colors.textPrimary, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: colors.textTertiary, fontSize: 15),
          border: InputBorder.none,
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildValueTile(
    AppColors colors, {
    required String value,
    required VoidCallback onTap,
    bool muted = false,
    VoidCallback? onClear,
  }) {
    return Material(
      color: colors.bgSecondary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _submitting ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    color: muted ? colors.textTertiary : colors.textPrimary,
                    fontSize: 15,
                  ),
                ),
              ),
              if (onClear != null)
                GestureDetector(
                  onTap: _submitting ? null : onClear,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.close,
                      size: 18,
                      color: colors.textTertiary,
                    ),
                  ),
                ),
              Icon(
                Icons.calendar_today_outlined,
                size: 18,
                color: colors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceWrap<T>(
    AppColors colors, {
    required List<T> options,
    required T selected,
    required String Function(T value) labelOf,
    required ValueChanged<T> onSelect,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          GestureDetector(
            onTap: _submitting ? null : () => onSelect(option),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: option == selected ? colors.addBtnBg : colors.bgSecondary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                labelOf(option),
                style: TextStyle(
                  color: option == selected ? Colors.white : colors.textSecondary,
                  fontSize: 14,
                  fontWeight: option == selected
                      ? FontWeight.w600
                      : FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _formatDate(DateTime value) {
    return '${value.year}年${value.month}月${value.day}日';
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.of(context).textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
