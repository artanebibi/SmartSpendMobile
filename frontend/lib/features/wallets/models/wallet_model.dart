import 'package:flutter/material.dart';

class WalletMember {
  final String name;
  final Color color;
  const WalletMember({required this.name, required this.color});
  String get initials => name.isNotEmpty ? name[0].toUpperCase() : '?';
}

class WalletExpense {
  final String description;
  final double amount;
  final WalletMember payer;
  final DateTime date;
  final List<WalletMember> splitWith;
  const WalletExpense({
    required this.description,
    required this.amount,
    required this.payer,
    required this.date,
    required this.splitWith,
  });
}

class WalletBalance {
  final WalletMember from;
  final WalletMember to;
  final double amount;
  final String walletName;
  const WalletBalance({
    required this.from,
    required this.to,
    required this.amount,
    required this.walletName,
  });
}

class WalletModel {
  final String id;
  final String name;
  final List<WalletMember> members;
  final List<WalletExpense> expenses;
  final double? monthlyGoal;

  const WalletModel({
    required this.id,
    required this.name,
    required this.members,
    required this.expenses,
    this.monthlyGoal,
  });

  double get totalSpent => expenses.fold(0, (s, e) => s + e.amount);
}

// Static mock data matching the React POC
final kMockMe = const WalletMember(name: 'Alex', color: Color(0xFF3D7EFF));

final kMockWallets = [
  WalletModel(
    id: 'w1',
    name: 'Apartment',
    members: [
      kMockMe,
      const WalletMember(name: 'Sam', color: Color(0xFF10B981)),
      const WalletMember(name: 'Jordan', color: Color(0xFF8B5CF6)),
    ],
    monthlyGoal: 1500,
    expenses: [
      WalletExpense(
        description: 'Groceries',
        amount: 120,
        payer: kMockMe,
        date: DateTime.now().subtract(const Duration(days: 1)),
        splitWith: [
          kMockMe,
          const WalletMember(name: 'Sam', color: Color(0xFF10B981)),
          const WalletMember(name: 'Jordan', color: Color(0xFF8B5CF6)),
        ],
      ),
      WalletExpense(
        description: 'Electricity bill',
        amount: 340,
        payer: const WalletMember(name: 'Sam', color: Color(0xFF10B981)),
        date: DateTime.now().subtract(const Duration(days: 3)),
        splitWith: [
          kMockMe,
          const WalletMember(name: 'Sam', color: Color(0xFF10B981)),
          const WalletMember(name: 'Jordan', color: Color(0xFF8B5CF6)),
        ],
      ),
      WalletExpense(
        description: 'Internet',
        amount: 60,
        payer: const WalletMember(name: 'Jordan', color: Color(0xFF8B5CF6)),
        date: DateTime.now().subtract(const Duration(days: 5)),
        splitWith: [
          kMockMe,
          const WalletMember(name: 'Sam', color: Color(0xFF10B981)),
          const WalletMember(name: 'Jordan', color: Color(0xFF8B5CF6)),
        ],
      ),
      WalletExpense(
        description: 'Cleaning supplies',
        amount: 45,
        payer: kMockMe,
        date: DateTime.now().subtract(const Duration(days: 7)),
        splitWith: [
          kMockMe,
          const WalletMember(name: 'Sam', color: Color(0xFF10B981)),
        ],
      ),
    ],
  ),
  WalletModel(
    id: 'w2',
    name: 'Road Trip',
    members: [
      kMockMe,
      const WalletMember(name: 'Taylor', color: Color(0xFFF97316)),
    ],
    expenses: [
      WalletExpense(
        description: 'Gas',
        amount: 85,
        payer: kMockMe,
        date: DateTime.now().subtract(const Duration(days: 2)),
        splitWith: [
          kMockMe,
          const WalletMember(name: 'Taylor', color: Color(0xFFF97316)),
        ],
      ),
      WalletExpense(
        description: 'Hotel',
        amount: 220,
        payer: const WalletMember(name: 'Taylor', color: Color(0xFFF97316)),
        date: DateTime.now().subtract(const Duration(days: 2)),
        splitWith: [
          kMockMe,
          const WalletMember(name: 'Taylor', color: Color(0xFFF97316)),
        ],
      ),
    ],
  ),
];

// Compute balances: who owes whom
List<WalletBalance> computeBalances(List<WalletModel> wallets) {
  final balances = <WalletBalance>[];
  for (final wallet in wallets) {
    for (final expense in wallet.expenses) {
      final perPerson = expense.amount / expense.splitWith.length;
      for (final member in expense.splitWith) {
        if (member.name != expense.payer.name) {
          balances.add(WalletBalance(
            from: member,
            to: expense.payer,
            amount: perPerson,
            walletName: wallet.name,
          ));
        }
      }
    }
  }
  return balances;
}
