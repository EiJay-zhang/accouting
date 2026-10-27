import 'package:flutter/material.dart';

class ReportPalette {
  static const income = Color(0xFF7BC99A);
  static const expense = Color(0xFFE59898);
  static const incomeInk = Color(0xFF2F7A52);
  static const expenseInk = Color(0xFFC25555);
  static const label = Color(0xFF3A3558);

  static const categories = <Color>[
    Color(0xFF8B93F2),
    Color(0xFFB4A0E8),
    Color(0xFFE7A0B8),
    Color(0xFF7EB6E6),
    Color(0xFFE7C07A),
    Color(0xFF7EC8B8),
    Color(0xFFF0B08A),
    Color(0xFFA8B4E8),
  ];

  static Color category(int id) => categories[id.abs() % categories.length];
}
