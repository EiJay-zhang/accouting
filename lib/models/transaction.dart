import 'package:flutter/material.dart';

import '../utils/money.dart';

enum TransactionType { income, expense }

class TransactionCategory {
  final int id;
  final String name;
  final String icon;
  final String colorHex;
  final TransactionType type;

  const TransactionCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.colorHex,
    required this.type,
  });

  Color get color => colorFromHex(colorHex);

  factory TransactionCategory.fromJson(Map<String, dynamic> json) {
    return TransactionCategory(
      id: json['id'] as int,
      name: json['name'] as String,
      icon: json['icon'] as String,
      colorHex: json['color'] as String,
      type: json['type'] == 'income'
          ? TransactionType.income
          : TransactionType.expense,
    );
  }

  static Color colorFromHex(String hex) {
    final value = hex.replaceFirst('#', '');
    return Color(int.parse('FF$value', radix: 16));
  }
}

class CategoryTag {
  final int id;
  final int categoryId;
  final String name;
  final int sortOrder;

  const CategoryTag({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.sortOrder,
  });

  factory CategoryTag.fromJson(Map<String, dynamic> json) {
    return CategoryTag(
      id: json['id'] as int,
      categoryId: json['category_id'] as int,
      name: json['name'] as String,
      sortOrder: json['sort_order'] as int,
    );
  }
}

class Transaction {
  final int id;
  final String title;
  final TransactionCategory category;
  final int amountCents;
  final TransactionType type;
  final DateTime date;
  final List<CategoryTag> tags;

  const Transaction({
    required this.id,
    required this.title,
    required this.category,
    required this.amountCents,
    required this.type,
    required this.date,
    this.tags = const [],
  });

  double get amount => amountCents / 100;

  factory Transaction.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'];
    final tags = rawTags is List
        ? rawTags
            .whereType<Map>()
            .map((item) => CategoryTag.fromJson(Map<String, dynamic>.from(item)))
            .toList()
        : const <CategoryTag>[];
    return Transaction(
      id: json['id'] as int,
      title: json['title'] as String,
      category: TransactionCategory.fromJson(
        json['category'] as Map<String, dynamic>,
      ),
      amountCents: centsFromYuan(json['amount'] as num),
      type: json['type'] == 'income'
          ? TransactionType.income
          : TransactionType.expense,
      date: DateTime.parse(json['date'] as String),
      tags: tags,
    );
  }
}

class TransactionGroup {
  final DateTime date;
  final List<Transaction> transactions;
  final double incomeTotal;
  final double expenseTotal;

  const TransactionGroup({
    required this.date,
    required this.transactions,
    required this.incomeTotal,
    required this.expenseTotal,
  });
}
