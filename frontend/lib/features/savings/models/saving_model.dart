import 'package:flutter/material.dart';

class SavingModel {
  final int id;
  final double currentAmount;
  final double amount;
  final DateTime from;
  final DateTime to;

  // Local-only display metadata (stored in SharedPreferences)
  final String name;
  final double targetAmount;
  final Color color;
  final DateTime? deadline;

  const SavingModel({
    required this.id,
    required this.currentAmount,
    required this.amount,
    required this.from,
    required this.to,
    this.name = 'Goal',
    this.targetAmount = 0,
    this.color = const Color(0xFF3D7EFF),
    this.deadline,
  });

  double get percentage => targetAmount > 0
      ? (amount / targetAmount * 100).clamp(0, 100)
      : 0;

  bool get isComplete => percentage >= 100;

  factory SavingModel.fromJson(Map<String, dynamic> j) => SavingModel(
        id: (j['id'] as num).toInt(),
        currentAmount: (j['current_amount'] as num).toDouble(),
        amount: (j['amount'] as num).toDouble(),
        from: DateTime.parse(j['from']).toLocal(),
        to: DateTime.parse(j['to']).toLocal(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'currentAmount': currentAmount,
        'amount': amount,
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
      };

  SavingModel copyWith({
    int? id,
    double? amount,
    String? name,
    double? targetAmount,
    Color? color,
    DateTime? deadline,
  }) =>
      SavingModel(
        id: id ?? this.id,
        currentAmount: currentAmount?? this.amount,
        amount: amount ?? this.amount,
        from: from,
        to: to,
        name: name ?? this.name,
        targetAmount: targetAmount ?? this.targetAmount,
        color: color ?? this.color,
        deadline: deadline ?? this.deadline,
      );
}
