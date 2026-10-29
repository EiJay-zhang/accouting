import '../utils/money.dart';

enum ItemStatus {
  inUse('in_use', '在用'),
  idle('idle', '闲置'),
  sold('sold', '已出售'),
  retired('retired', '已报废');

  const ItemStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static ItemStatus fromApi(String? value) {
    for (final status in ItemStatus.values) {
      if (status.apiValue == value) return status;
    }
    return ItemStatus.inUse;
  }
}

class Item {
  final int id;
  final String name;
  final int? categoryId;
  final String category;
  final String? categoryIcon;
  final String? categoryColor;
  final int amountCents;
  final DateTime purchaseDate;
  final int daysUsed;
  final String purpose;
  final ItemStatus status;
  final int? soldAmountCents;
  final DateTime? soldDate;
  final int? heldDays;
  final int? profitCents;
  final DateTime? warrantyUntil;
  final String note;

  const Item({
    required this.id,
    required this.name,
    this.categoryId,
    required this.category,
    this.categoryIcon,
    this.categoryColor,
    required this.amountCents,
    required this.purchaseDate,
    required this.daysUsed,
    required this.purpose,
    required this.status,
    this.soldAmountCents,
    this.soldDate,
    this.heldDays,
    this.profitCents,
    this.warrantyUntil,
    this.note = '',
  });

  double get amount => amountCents / 100;

  double? get soldAmount =>
      soldAmountCents == null ? null : soldAmountCents! / 100;

  /// 正数 = 用一天亏多少（支出摊销）。只在在用/闲置时看这个。
  int get dailyCostCents {
    final days = daysUsed < 1 ? 1 : daysUsed;
    return amountCents ~/ days;
  }

  /// 正数表示还剩多少天，0 表示今天到期，负数表示已经过保。
  int? get warrantyDaysLeft {
    final until = warrantyUntil;
    if (until == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return DateTime(
      until.year,
      until.month,
      until.day,
    ).difference(today).inDays;
  }

  factory Item.fromJson(Map<String, dynamic> json) {
    final warranty = json['warranty_until'] as String?;
    final sold = json['sold_amount'];
    final soldDate = json['sold_date'] as String?;
    final profit = json['profit'];
    return Item(
      id: json['id'] as int,
      name: json['name'] as String,
      categoryId: json['category_id'] as int?,
      category: json['category'] as String? ?? '未分类',
      categoryIcon: json['category_icon'] as String?,
      categoryColor: json['category_color'] as String?,
      amountCents: centsFromYuan(json['amount'] as num),
      purchaseDate: DateTime.parse(json['purchase_date'] as String),
      daysUsed: (json['days_used'] as num?)?.toInt() ?? 0,
      purpose: json['purpose'] as String? ?? '',
      status: ItemStatus.fromApi(json['status'] as String?),
      soldAmountCents: sold == null ? null : centsFromYuan(sold as num),
      soldDate: soldDate == null || soldDate.isEmpty
          ? null
          : DateTime.parse(soldDate),
      heldDays: (json['held_days'] as num?)?.toInt(),
      profitCents: profit == null ? null : centsFromYuan(profit as num),
      warrantyUntil: warranty == null || warranty.isEmpty
          ? null
          : DateTime.parse(warranty),
      note: json['note'] as String? ?? '',
    );
  }
}

class ItemSummary {
  final int count;
  final int inUseCount;
  final int totalAmountCents;
  final int dailyCostCents;
  final int totalProfitCents;

  const ItemSummary({
    required this.count,
    required this.inUseCount,
    required this.totalAmountCents,
    required this.dailyCostCents,
    required this.totalProfitCents,
  });

  factory ItemSummary.fromJson(Map<String, dynamic> json) {
    return ItemSummary(
      count: json['count'] as int,
      inUseCount: json['in_use_count'] as int,
      totalAmountCents: centsFromYuan(json['total_amount'] as num),
      dailyCostCents: centsFromYuan(json['daily_cost'] as num),
      totalProfitCents: centsFromYuan(json['total_profit'] as num),
    );
  }
}
