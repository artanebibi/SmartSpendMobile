import 'package:flutter/foundation.dart';
import '../models/wallet_model.dart';

class WalletProvider extends ChangeNotifier {
  List<WalletModel> _wallets = List.from(kMockWallets);
  final Set<String> _settled = {};

  List<WalletModel> get wallets => _wallets;

  WalletModel? findById(String id) =>
      _wallets.where((w) => w.id == id).firstOrNull;

  // ─── Net balances for the current user (kMockMe) ─────────────────────────
  // Positive value → other person owes me
  // Negative value → I owe that person
  Map<String, _NetEntry> get myNetBalances {
    final net = <String, _NetEntry>{};

    for (final wallet in _wallets) {
      for (final expense in wallet.expenses) {
        final perPerson = expense.amount / expense.splitWith.length;

        if (expense.payer.name == kMockMe.name) {
          for (final m in expense.splitWith) {
            if (m.name == kMockMe.name) continue;
            final key = m.name;
            final cur = net[key] ??
                _NetEntry(member: m, amount: 0, wallets: {});
            net[key] = _NetEntry(
              member: cur.member,
              amount: cur.amount + perPerson,
              wallets: {...cur.wallets, wallet.name},
            );
          }
        } else if (expense.splitWith.any((m) => m.name == kMockMe.name)) {
          final key = expense.payer.name;
          final cur = net[key] ??
              _NetEntry(member: expense.payer, amount: 0, wallets: {});
          net[key] = _NetEntry(
            member: cur.member,
            amount: cur.amount - perPerson,
            wallets: {...cur.wallets, wallet.name},
          );
        }
      }
    }

    // Remove settled
    for (final k in _settled) {
      net.remove(k);
    }
    return net;
  }

  // Total I owe (sum of negative net entries)
  double get totalOwed {
    return myNetBalances.values
        .where((e) => e.amount < 0)
        .fold(0.0, (s, e) => s + e.amount.abs());
  }

  // Total owed to me
  double get totalOwedToMe {
    return myNetBalances.values
        .where((e) => e.amount > 0)
        .fold(0.0, (s, e) => s + e.amount);
  }

  // ─── Mutations ────────────────────────────────────────────────────────────

  void addWallet({
    required String name,
    double? monthlyGoal,
    required List<WalletMember> members,
  }) {
    final id = 'w${DateTime.now().millisecondsSinceEpoch}';
    _wallets = [
      ..._wallets,
      WalletModel(
          id: id, name: name, members: members, expenses: [],
          monthlyGoal: monthlyGoal),
    ];
    notifyListeners();
  }

  void addExpense({
    required String walletId,
    required WalletExpense expense,
  }) {
    _wallets = _wallets.map((w) {
      if (w.id != walletId) return w;
      return WalletModel(
        id: w.id,
        name: w.name,
        members: w.members,
        expenses: [...w.expenses, expense],
        monthlyGoal: w.monthlyGoal,
      );
    }).toList();
    notifyListeners();
  }

  void settleWith(String memberName) {
    _settled.add(memberName);
    notifyListeners();
  }

  void markAllSettled() {
    _settled.addAll(myNetBalances.keys);
    notifyListeners();
  }
}

class _NetEntry {
  final WalletMember member;
  final double amount;
  final Set<String> wallets;
  const _NetEntry(
      {required this.member, required this.amount, required this.wallets});
}
