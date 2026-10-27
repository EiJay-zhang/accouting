import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/import_api.dart';
import '../constants/app_colors.dart';
import '../models/transaction.dart';
import '../services/transaction_service.dart';

class BillImportPage extends StatefulWidget {
  const BillImportPage({super.key});

  @override
  State<BillImportPage> createState() => _BillImportPageState();
}

class _Draft {
  _Draft(this.item)
      : checked = item.canImport,
        categoryId = item.categoryId,
        categoryName = item.categoryName;

  final ImportPreviewItem item;
  bool checked;
  int? categoryId;
  String categoryName;
}

class _BillImportPageState extends State<BillImportPage> {
  final ImportApi _api = ImportApi();
  final TransactionService _transactions = TransactionService();

  ImportPreview? _preview;
  List<_Draft> _drafts = [];
  List<TransactionCategory> _categories = [];
  bool _busy = false;
  String? _error;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'xlsx', 'txt'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      _showMessage('无法读取文件，请重新选择');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.preview(bytes: bytes, filename: file.name),
        _transactions.getCategories(),
      ]);
      if (!mounted) return;
      final preview = results[0] as ImportPreview;
      setState(() {
        _preview = preview;
        _categories = results[1] as List<TransactionCategory>;
        _drafts = preview.items.map(_Draft.new).toList();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is ApiException ? error.message : '解析失败，请确认是导出的 csv 或 xlsx';
        _preview = null;
        _drafts = [];
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _commit() async {
    final preview = _preview;
    if (preview == null || _busy) return;
    final selected = _drafts.where((draft) => draft.checked && draft.categoryId != null).toList();
    if (selected.isEmpty) {
      _showMessage('请至少选择一笔账单');
      return;
    }

    setState(() => _busy = true);
    try {
      final result = await _api.commit(
        source: preview.source,
        items: [
          for (final draft in selected)
            ImportPreviewItem(
              externalId: draft.item.externalId,
              title: draft.item.title,
              amount: draft.item.amount,
              type: draft.item.type,
              date: draft.item.date,
              categoryId: draft.categoryId,
              categoryName: draft.categoryName,
              matched: draft.item.matched,
              counterparty: draft.item.counterparty,
              duplicate: false,
              skipped: false,
              skipReason: '',
            ),
        ],
      );
      if (!mounted) return;
      _showMessage('已导入 ${result.imported} 笔，跳过重复 ${result.duplicates} 笔');
      Navigator.of(context).pop(result.imported > 0);
    } catch (error) {
      if (!mounted) return;
      _showMessage(error is ApiException ? error.message : '导入失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickCategory(_Draft draft) async {
    final options = _categories.where((category) => category.type == draft.item.type).toList();
    if (options.isEmpty) {
      _showMessage(draft.item.type == TransactionType.income ? '还没有收入分类' : '还没有支出分类');
      return;
    }
    final selected = await showModalBottomSheet<TransactionCategory>(
      context: context,
      backgroundColor: AppColors.of(context).bgSecondary,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final category in options)
                ListTile(
                  leading: Text(category.icon, style: const TextStyle(fontSize: 22)),
                  title: Text(category.name, style: TextStyle(color: AppColors.of(context).textPrimary)),
                  trailing: category.id == draft.categoryId
                      ? Icon(Icons.check, color: AppColors.of(context).addBtnBg)
                      : null,
                  onTap: () => Navigator.pop(context, category),
                ),
            ],
          ),
        );
      },
    );
    if (selected == null || !mounted) return;
    setState(() {
      draft.categoryId = selected.id;
      draft.categoryName = selected.name;
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.of(context).bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.of(context).bgPrimary,
        elevation: 0,
        title: Text(
          '导入账单',
          style: TextStyle(
            color: AppColors.of(context).textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.of(context).textPrimary),
      ),
      body: SafeArea(
        child: _preview == null ? _buildPicker() : _buildPreview(),
      ),
    );
  }

  Widget _buildPicker() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Text(
          '选择支付宝、微信或银行卡导出的 csv、xlsx 文件。系统会自动识别来源，并按订单号跳过已经导入的记录。',
          style: TextStyle(color: AppColors.of(context).textSecondary, height: 1.5),
        ),
        const SizedBox(height: 20),
        _HintCard(
          title: '支付宝',
          body: '账单里导出交易流水，选择 csv 或 xlsx。不计收支和交易关闭的记录会跳过。',
        ),
        const SizedBox(height: 12),
        _HintCard(
          title: '微信',
          body: '钱包账单中下载账单明细。支付成功的收支会导入，转账等不计收支的记录会跳过。',
        ),
        const SizedBox(height: 12),
        _HintCard(
          title: '银行卡',
          body: '使用银行 App 导出的交易明细。需要包含交易日期，以及收入/支出金额或借贷金额。',
        ),
        const SizedBox(height: 24),
        if (_error != null) ...[
          Text(_error!, style: TextStyle(color: AppColors.of(context).expenseRed)),
          const SizedBox(height: 16),
        ],
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _busy ? null : _pickFile,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.of(context).addBtnBg,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('选择文件', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildPreview() {
    final preview = _preview!;
    final selectedCount = _drafts.where((draft) => draft.checked).length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '识别为${preview.sourceLabel}，共 ${preview.total} 条',
                style: TextStyle(
                  color: AppColors.of(context).textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '可导入 ${preview.readyCount} 笔，重复 ${preview.duplicateCount} 笔，跳过 ${preview.skippedCount} 笔。点分类可以改归类。',
                style: TextStyle(color: AppColors.of(context).textTertiary, fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            itemCount: _drafts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _buildRow(_drafts[index]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Row(
            children: [
              TextButton(onPressed: _busy ? null : _pickFile, child: const Text('重新选择')),
              const Spacer(),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _busy || selectedCount == 0 ? null : _commit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.of(context).addBtnBg,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text('导入 $selectedCount 笔'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRow(_Draft draft) {
    final item = draft.item;
    final income = item.type == TransactionType.income;
    final amountColor = income ? AppColors.of(context).incomeGreen : AppColors.of(context).expenseRed;
    final note = item.skipped
        ? item.skipReason
        : item.duplicate
            ? '已导入过'
            : draft.item.matched
                ? draft.categoryName
                : '${draft.categoryName}（未识别）';
    return Material(
      color: AppColors.of(context).bgSecondary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
        child: Row(
          children: [
            Checkbox(
              value: draft.checked,
              onChanged: !item.canImport || _busy
                  ? null
                  : (value) => setState(() => draft.checked = value ?? false),
              activeColor: AppColors.of(context).addBtnBg,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.of(context).textPrimary, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.date}  $note',
                    style: TextStyle(color: AppColors.of(context).textTertiary, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (item.canImport)
              TextButton(
                onPressed: _busy ? null : () => _pickCategory(draft),
                child: const Text('分类'),
              ),
            Text(
              '${income ? '+' : '-'}${item.amount.toStringAsFixed(2)}',
              style: TextStyle(color: amountColor, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  final String title;
  final String body;

  const _HintCard({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.of(context).bgSecondary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppColors.of(context).textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(color: AppColors.of(context).textTertiary, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }
}
