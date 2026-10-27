import 'package:flutter/material.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color bgPrimary;
  final Color bgSecondary;
  final Color bgCard;
  final Color bgCardLight;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color incomeGreen;
  final Color expenseRed;
  final Color accentPurple;
  final Color accentPink;
  final Color divider;
  final Color navBar;
  final Color navItem;
  final Color navActive;
  final Color addBtnBg;
  final Color addBtnIcon;

  const AppColors({
    required this.bgPrimary,
    required this.bgSecondary,
    required this.bgCard,
    required this.bgCardLight,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.incomeGreen,
    required this.expenseRed,
    required this.accentPurple,
    required this.accentPink,
    required this.divider,
    required this.navBar,
    required this.navItem,
    required this.navActive,
    required this.addBtnBg,
    required this.addBtnIcon,
  });

  static const dark = AppColors(
    bgPrimary: Color(0xFF1A1A2E),
    bgSecondary: Color(0xFF252542),
    bgCard: Color(0xFF2D2D44),
    bgCardLight: Color(0xFF353550),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFB8B8C8),
    textTertiary: Color(0xFF8888A0),
    incomeGreen: Color(0xFF4ADE80),
    expenseRed: Color(0xFFF87171),
    accentPurple: Color(0xFFA78BFA),
    accentPink: Color(0xFFEC4899),
    divider: Color(0xFF3D3D5A),
    navBar: Color(0xFF1E1E35),
    navItem: Color(0xFF8888A0),
    navActive: Color(0xFFFFFFFF),
    addBtnBg: Color(0xFF6366F1),
    addBtnIcon: Color(0xFFFFFFFF),
  );

  static const light = AppColors(
    bgPrimary: Color(0xFFF4F5FB),
    bgSecondary: Color(0xFFFFFFFF),
    bgCard: Color(0xFFFFFFFF),
    bgCardLight: Color(0xFFEEF0F8),
    textPrimary: Color(0xFF1A1A2E),
    textSecondary: Color(0xFF5A5A72),
    textTertiary: Color(0xFF8B8BA3),
    incomeGreen: Color(0xFF16A34A),
    expenseRed: Color(0xFFDC2626),
    accentPurple: Color(0xFF7C3AED),
    accentPink: Color(0xFFDB2777),
    divider: Color(0xFFE4E6F0),
    navBar: Color(0xFFFFFFFF),
    navItem: Color(0xFF8B8BA3),
    navActive: Color(0xFF4338CA),
    addBtnBg: Color(0xFF6366F1),
    addBtnIcon: Color(0xFFFFFFFF),
  );

  static AppColors of(BuildContext context) {
    return Theme.of(context).extension<AppColors>() ?? dark;
  }

  @override
  AppColors copyWith({
    Color? bgPrimary,
    Color? bgSecondary,
    Color? bgCard,
    Color? bgCardLight,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? incomeGreen,
    Color? expenseRed,
    Color? accentPurple,
    Color? accentPink,
    Color? divider,
    Color? navBar,
    Color? navItem,
    Color? navActive,
    Color? addBtnBg,
    Color? addBtnIcon,
  }) {
    return AppColors(
      bgPrimary: bgPrimary ?? this.bgPrimary,
      bgSecondary: bgSecondary ?? this.bgSecondary,
      bgCard: bgCard ?? this.bgCard,
      bgCardLight: bgCardLight ?? this.bgCardLight,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      incomeGreen: incomeGreen ?? this.incomeGreen,
      expenseRed: expenseRed ?? this.expenseRed,
      accentPurple: accentPurple ?? this.accentPurple,
      accentPink: accentPink ?? this.accentPink,
      divider: divider ?? this.divider,
      navBar: navBar ?? this.navBar,
      navItem: navItem ?? this.navItem,
      navActive: navActive ?? this.navActive,
      addBtnBg: addBtnBg ?? this.addBtnBg,
      addBtnIcon: addBtnIcon ?? this.addBtnIcon,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      bgPrimary: Color.lerp(bgPrimary, other.bgPrimary, t)!,
      bgSecondary: Color.lerp(bgSecondary, other.bgSecondary, t)!,
      bgCard: Color.lerp(bgCard, other.bgCard, t)!,
      bgCardLight: Color.lerp(bgCardLight, other.bgCardLight, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      incomeGreen: Color.lerp(incomeGreen, other.incomeGreen, t)!,
      expenseRed: Color.lerp(expenseRed, other.expenseRed, t)!,
      accentPurple: Color.lerp(accentPurple, other.accentPurple, t)!,
      accentPink: Color.lerp(accentPink, other.accentPink, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      navBar: Color.lerp(navBar, other.navBar, t)!,
      navItem: Color.lerp(navItem, other.navItem, t)!,
      navActive: Color.lerp(navActive, other.navActive, t)!,
      addBtnBg: Color.lerp(addBtnBg, other.addBtnBg, t)!,
      addBtnIcon: Color.lerp(addBtnIcon, other.addBtnIcon, t)!,
    );
  }
}

ThemeData buildAppTheme(AppColors colors, Brightness brightness) {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: colors.addBtnBg,
      brightness: brightness,
    ),
    scaffoldBackgroundColor: colors.bgPrimary,
    useMaterial3: true,
    extensions: [colors],
  );
}
