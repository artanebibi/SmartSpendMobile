import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const primary = Color(0xFF3D7EFF);
  static const secondary = Color(0xFF5A3ED0);
  static const success = Color(0xFF10B981);
  static const error = Color(0xFFEF4444);
  static const orange = Color(0xFFF97316);
  static const pink = Color(0xFFEC4899);
  static const purple = Color(0xFF8B5CF6);
  static const indigo = Color(0xFF6366F1);
  static const cyan = Color(0xFF0EA5E9);
  static const amber = Color(0xFFF59E0B);
  static const darkText = Color(0xFF1A1A2E);
  static const lightBg = Color(0xFFF5F7FA);
  static const cardBg = Colors.white;
  static const border = Color(0xFFE5E7EB);
  static const muted = Color(0xFF6B7280);
  static const secondaryBg = Color(0xFFEEF3FF);

  static const balanceGradient = LinearGradient(
    colors: [Color(0xFF3D7EFF), Color(0xFF5A3ED0)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // Category bg / icon color pairs
  static const Map<String, Map<String, Color>> category = {
    'Food': {'bg': Color(0xFFFFF7ED), 'icon': Color(0xFFF97316)},
    'Salary': {'bg': Color(0xFFECFDF5), 'icon': Color(0xFF10B981)},
    'Income': {'bg': Color(0xFFECFDF5), 'icon': Color(0xFF10B981)},
    'Transport': {'bg': Color(0xFFEDE9FE), 'icon': Color(0xFF8B5CF6)},
    'Shopping': {'bg': Color(0xFFFDF2F8), 'icon': Color(0xFFEC4899)},
    'Entertainment': {'bg': Color(0xFFEFF6FF), 'icon': Color(0xFF3D7EFF)},
    'Health': {'bg': Color(0xFFFEF2F2), 'icon': Color(0xFFEF4444)},
    'Groceries': {'bg': Color(0xFFFFF7ED), 'icon': Color(0xFFF97316)},
    'Rent': {'bg': Color(0xFFEEF2FF), 'icon': Color(0xFF6366F1)},
    'Investment': {'bg': Color(0xFFF0F9FF), 'icon': Color(0xFF0EA5E9)},
    'Freelance': {'bg': Color(0xFFECFDF5), 'icon': Color(0xFF10B981)},
    'Education': {'bg': Color(0xFFFFF7ED), 'icon': Color(0xFFF97316)},
    'Other': {'bg': Color(0xFFF5F7FA), 'icon': Color(0xFF6B7280)},
  };

  static Color categoryBg(String name) =>
      category[name]?['bg'] ?? const Color(0xFFF5F7FA);

  static Color categoryIcon(String name) =>
      category[name]?['icon'] ?? const Color(0xFF6B7280);
}
