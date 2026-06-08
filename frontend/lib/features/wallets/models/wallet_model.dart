import 'package:flutter/material.dart';

// ─── Member colour palette ─────────────────────────────────────────────────

const _kMemberColors = [
  Color(0xFF3D7EFF),
  Color(0xFF10B981),
  Color(0xFF8B5CF6),
  Color(0xFFF97316),
  Color(0xFFEC4899),
  Color(0xFF0EA5E9),
];

Color memberColorAt(int index) => _kMemberColors[index % _kMemberColors.length];

// ─── WalletMember ──────────────────────────────────────────────────────────

class WalletMember {
  final String userId;
  final String name;
  final String role;
  final Color color;

  const WalletMember({
    required this.userId,
    required this.name,
    this.role = 'member',
    required this.color,
  });

  String get initials => name.isNotEmpty ? name[0].toUpperCase() : '?';

  /// Builds from the balances endpoint's member entry + a colour slot.
  factory WalletMember.fromBalanceJson(Map<String, dynamic> j, int colorIndex) =>
      WalletMember(
        userId: j['user_id']?.toString() ?? '',
        name: j['name'] ?? '',
        color: memberColorAt(colorIndex),
      );

  /// Builds a stub from a detail member entry (no name; name resolved later).
  factory WalletMember.fromDetailJson(Map<String, dynamic> j, int colorIndex) =>
      WalletMember(
        userId: j['user_id']?.toString() ?? '',
        name: '',
        role: j['role'] ?? 'member',
        color: memberColorAt(colorIndex),
      );
}

// ─── SplitEntry ────────────────────────────────────────────────────────────

class SplitEntry {
  final String userId;
  final double share;

  const SplitEntry({required this.userId, required this.share});

  factory SplitEntry.fromJson(Map<String, dynamic> j) => SplitEntry(
        userId: j['user_id']?.toString() ?? '',
        share: (j['share'] as num?)?.toDouble() ?? 0,
      );
}

// ─── WalletTransaction (API-backed) ────────────────────────────────────────

class WalletTransaction {
  final int id;           // wallet_transaction.id (join table PK)
  final int transactionId; // transaction.id (the actual expense record)
  final String title;
  final double price;
  final DateTime date;
  final String payerUserId;
  final List<SplitEntry> splits;

  const WalletTransaction({
    required this.id,
    required this.transactionId,
    required this.title,
    required this.price,
    required this.date,
    required this.payerUserId,
    required this.splits,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> j) {
    final tx = (j['transaction'] as Map<String, dynamic>?) ?? {};
    final rawSplits = (j['splits'] as List<dynamic>?) ?? [];
    return WalletTransaction(
      id: (j['id'] as num?)?.toInt() ?? 0,
      transactionId: (j['transaction_id'] as num?)?.toInt() ?? 0,
      title: tx['title'] as String? ?? '',
      price: (tx['price'] as num?)?.toDouble() ?? 0,
      date: DateTime.tryParse(tx['date_made'] as String? ?? '') ?? DateTime.now(),
      payerUserId: tx['owner_id']?.toString() ?? '',
      splits: rawSplits
          .whereType<Map<String, dynamic>>()
          .map(SplitEntry.fromJson)
          .toList(),
    );
  }
}

// ─── Balance / Settlement ──────────────────────────────────────────────────

class MemberBalance {
  final String userId;
  final String name;
  final double netBalance;

  const MemberBalance({
    required this.userId,
    required this.name,
    required this.netBalance,
  });

  factory MemberBalance.fromJson(Map<String, dynamic> j) => MemberBalance(
        userId: j['user_id']?.toString() ?? '',
        name: j['name'] as String? ?? '',
        netBalance: (j['net_balance'] as num?)?.toDouble() ?? 0,
      );
}

class SuggestedSettlement {
  final String fromUserId;
  final String toUserId;
  final double amount;

  const SuggestedSettlement({
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
  });

  factory SuggestedSettlement.fromJson(Map<String, dynamic> j) =>
      SuggestedSettlement(
        fromUserId: j['from_user_id']?.toString() ?? '',
        toUserId: j['to_user_id']?.toString() ?? '',
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
      );
}

class BalanceResult {
  final List<MemberBalance> members;
  final List<SuggestedSettlement> suggestedSettlements;

  const BalanceResult({
    required this.members,
    required this.suggestedSettlements,
  });

  factory BalanceResult.fromJson(Map<String, dynamic> j) => BalanceResult(
        members: ((j['members'] as List<dynamic>?) ?? [])
            .whereType<Map<String, dynamic>>()
            .map(MemberBalance.fromJson)
            .toList(),
        suggestedSettlements:
            ((j['suggested_settlements'] as List<dynamic>?) ?? [])
                .whereType<Map<String, dynamic>>()
                .map(SuggestedSettlement.fromJson)
                .toList(),
      );
}

// ─── NetEntry (settle-screen display model) ────────────────────────────────

/// Represents a single outstanding balance between the current user and one
/// counterparty, scoped to a specific wallet.
class NetEntry {
  final WalletMember member; // the counterparty
  final double amount;       // positive → they owe me; negative → I owe them
  final Set<String> walletNames;
  final int walletId;
  final String fromUserId;   // the debtor
  final String toUserId;     // the creditor

  const NetEntry({
    required this.member,
    required this.amount,
    required this.walletNames,
    required this.walletId,
    required this.fromUserId,
    required this.toUserId,
  });
}

// ─── WalletModel ──────────────────────────────────────────────────────────

class WalletModel {
  final int id;
  final String name;
  final String inviteCode;
  final String createdBy;
  final DateTime createdAt;

  // Populated from GET /api/wallet list
  final double totalSpent;
  final int memberCount;

  // Populated from GET /api/wallet/:id detail
  final List<WalletMember> members;
  final List<WalletTransaction> transactions;

  const WalletModel({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.createdBy,
    required this.createdAt,
    this.totalSpent = 0,
    this.memberCount = 0,
    this.members = const [],
    this.transactions = const [],
  });

  /// Builds from the GET /api/wallet list payload.
  factory WalletModel.fromListJson(Map<String, dynamic> j) => WalletModel(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: j['name'] as String? ?? '',
        inviteCode: j['invite_code'] as String? ?? '',
        createdBy: j['created_by']?.toString() ?? '',
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ??
            DateTime.now(),
        totalSpent: (j['total_spent'] as num?)?.toDouble() ?? 0,
        memberCount: (j['member_count'] as num?)?.toInt() ?? 0,
      );

  /// Builds from the GET /api/wallet/:id detail payload.
  /// [members] should already have names resolved from the balances endpoint.
  factory WalletModel.fromDetailJson(
    Map<String, dynamic> j,
    List<WalletMember> resolvedMembers,
  ) {
    final rawTx = (j['transactions'] as List<dynamic>?) ?? [];
    return WalletModel(
      id: (j['id'] as num?)?.toInt() ?? 0,
      name: j['name'] as String? ?? '',
      inviteCode: j['invite_code'] as String? ?? '',
      createdBy: j['created_by']?.toString() ?? '',
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ??
          DateTime.now(),
      memberCount: resolvedMembers.length,
      members: resolvedMembers,
      transactions: rawTx
          .whereType<Map<String, dynamic>>()
          .map(WalletTransaction.fromJson)
          .toList(),
    );
  }

  WalletModel copyWith({
    double? totalSpent,
    int? memberCount,
    List<WalletMember>? members,
    List<WalletTransaction>? transactions,
  }) =>
      WalletModel(
        id: id,
        name: name,
        inviteCode: inviteCode,
        createdBy: createdBy,
        createdAt: createdAt,
        totalSpent: totalSpent ?? this.totalSpent,
        memberCount: memberCount ?? this.memberCount,
        members: members ?? this.members,
        transactions: transactions ?? this.transactions,
      );
}
