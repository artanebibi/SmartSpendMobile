import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

const Map<String, IconData> categoryIcon = {
  'Groceries':             Icons.shopping_cart_rounded,
  'Health':                Icons.local_pharmacy_rounded,
  'Home':                  Icons.home_rounded,
  'Restaurants & Dining':  Icons.restaurant_rounded,
  'Education':             Icons.school_rounded,
  'Travel':                Icons.flight_rounded,
  'Entertainment':         Icons.movie_rounded,
  'Other':                 Icons.category_rounded,
  'Bills & Subscriptions': Icons.receipt_long_rounded,
  'Transportation':        Icons.directions_bus_rounded,
  'Electronics':           Icons.devices_rounded,
  'Income':                Icons.account_balance_wallet_rounded,
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
        child: Icon(
          categoryIcon[category] ?? Icons.category_rounded,
          size: size * 0.50,
          color: AppColors.categoryIcon(category),
        ),
      ),
    );
  }
}
