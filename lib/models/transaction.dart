import 'package:flutter/material.dart';

enum TransactionType { income, expense }

class TransactionCategory {
  final int id;
  final String name;
  final String icon;
  final Color color;

  const TransactionCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });

  factory TransactionCategory.fromJson(Map<String, dynamic> json) {
    return TransactionCategory(
      id: json['id'] as int,
      name: json['name'] as String,
      icon: json['icon'] as String,
      color: _colorFromHex(json['color'] as String),
    );
  }

  static Color _colorFromHex(String hex) {
    final value = hex.replaceFirst('#', '');
    return Color(int.parse('FF$value', radix: 16));
  }
}

class Transaction {
  final int id;
  final String title;
  final TransactionCategory category;
  final double amount;
  final TransactionType type;
  final DateTime date;

  const Transaction({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.type,
    required this.date,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as int,
      title: json['title'] as String,
      category: TransactionCategory.fromJson(
        json['category'] as Map<String, dynamic>,
      ),
      amount: (json['amount'] as num).toDouble(),
      type: json['type'] == 'income'
          ? TransactionType.income
          : TransactionType.expense,
      date: DateTime.parse(json['date'] as String),
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
