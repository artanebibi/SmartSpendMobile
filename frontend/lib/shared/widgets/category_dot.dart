import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

const Map<String, String> categoryEmoji = {
  'Groceries':             '🛒',
  'Health':                '💊',
  'Home':                  '🏠',
  'Restaurants & Dining':  '🍔',
  'Education':             '📚',
  'Travel':                '✈️',
  'Entertainment':         '🎬',
  'Other':                 '✨',
  'Bills & Subscriptions': '💳',
  'Transportation':        '🚌',
  'Electronics':           '📱',
  'Income':                '💸'
};

class CategoryDot extends StatelessWidget {
  const CategoryDot({
    super.key,
    required this.category,
    this.size = 40,
  });

  final String category;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.categoryBg(category),
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: Center(
        child: Text(
          categoryEmoji[category] ?? '✨',
          style: TextStyle(fontSize: size * 0.45),
        ),
      ),
    );
  }
}
