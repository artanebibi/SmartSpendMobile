import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/wallet_model.dart';

class WalletProvider extends ChangeNotifier {
  final _dio = ApiClient.instance;

  List<WalletModel> _wallets = [];
  // walletId → BalanceResult cached from last API call
  final Map<int, BalanceResult> _balances = {};

  bool _loading = false;
  String? _error;

  // Set by screens after auth resolves so balance perspective is correct.
  String _currentUserId = '';

  // ─── Getters ──────────────────────────────────────────────────────────────

  List<WalletModel> get wallets => _wallets;
  bool get loading => _loading;
  String? get error => _error;

  WalletModel? findById(int id) =>
      _wallets.where((w) => w.id == id).firstOrNull;

  void setCurrentUser(String userId) {
    debugPrint('[Wallet] setCurrentUser called: "$userId" (was "$_currentUserId")');
    if (_currentUserId == userId) return;
    _currentUserId = userId;
    notifyListeners();
  }

  // ─── Net balances (current-user perspective) ──────────────────────────────

  /// Returns one [NetEntry] per outstanding suggested settlement that involves
  /// the current user, keyed by "<walletId>_<counterpartyUserId>".
  Map<String, NetEntry> get myNetBalances {
    debugPrint('[Wallet] myNetBalances called: currentUser="$_currentUserId" isEmpty=${_currentUserId.isEmpty} balances=${_balances.length}');
    if (_currentUserId.isEmpty) return {};
    final result = <String, NetEntry>{};

    for (final entry in _balances.entries) {
      final walletId = entry.key;
      final bal = entry.value;
      final walletName =
          _wallets.where((w) => w.id == walletId).firstOrNull?.name ?? '';

      for (final s in bal.suggestedSettlements) {
        final isDebtor = s.fromUserId == _currentUserId;
        final isCreditor = s.toUserId == _currentUserId;
        if (!isDebtor && !isCreditor) continue;

        final counterpartyId =
            isDebtor ? s.toUserId : s.fromUserId;
        final key = '${walletId}_$counterpartyId';

        // Resolve a display name from the balances member list
        final balanceMember = bal.members
            .where((m) => m.userId == counterpartyId)
            .firstOrNull;
        final name = balanceMember?.name ?? counterpartyId;

        // Assign a stable colour by index in that wallet's member list
        final colorIndex = bal.members.indexWhere((m) => m.userId == counterpartyId);
        final member = WalletMember(
          userId: counterpartyId,
          name: name,
          color: memberColorAt(colorIndex >= 0 ? colorIndex : 0),
        );

        result[key] = NetEntry(
          member: member,
          amount: isDebtor ? -s.amount : s.amount,
          walletNames: {walletName},
          walletId: walletId,
          fromUserId: s.fromUserId,
          toUserId: s.toUserId,
        );
      }
    }
    return result;
  }

  double get totalOwed => myNetBalances.values
      .where((e) => e.amount < 0)
      .fold(0.0, (s, e) => s + e.amount.abs());

  double get totalOwedToMe => myNetBalances.values
      .where((e) => e.amount > 0)
      .fold(0.0, (s, e) => s + e.amount);

  // ─── Load wallet list ─────────────────────────────────────────────────────

  Future<void> loadWallets() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _dio.get(ApiEndpoints.wallet);
      final list = (res.data['data'] as List?) ?? [];
      _wallets = list
          .whereType<Map<String, dynamic>>()
          .map(WalletModel.fromListJson)
          .toList();
    } on DioException catch (e) {
      _error = e.response?.data?['error']?.toString() ?? e.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ─── Load wallet detail (members + transactions) ──────────────────────────

  /// Fetches the detail for [walletId] and the balances in parallel, then
  /// merges member names from the balance response into the member list.
  Future<WalletModel?> loadWalletDetail(int walletId) async {
    try {
      final results = await Future.wait([
        _dio.get(ApiEndpoints.walletById(walletId)),
        _dio.get(ApiEndpoints.walletBalances(walletId)),
      ]);

      final detailData =
          results[0].data['data'] as Map<String, dynamic>? ?? {};
      final balData =
          results[1].data['data'] as Map<String, dynamic>? ?? {};

      final bal = BalanceResult.fromJson(balData);
      _balances[walletId] = bal;
      debugPrint('[Wallet] balances for $walletId: members=${bal.members.length} settlements=${bal.suggestedSettlements.length}');
      for (final s in bal.suggestedSettlements) {
        debugPrint('[Wallet]   settlement: ${s.fromUserId} → ${s.toUserId} \$${s.amount}');
      }

      // Build a userId → name map from balance data
      final nameMap = {
        for (final m in bal.members) m.userId: m.name,
      };

      // Resolve member details: role from detail, name from balances
      final rawMembers =
          (detailData['members'] as List<dynamic>?) ?? [];
      final resolvedMembers = rawMembers
          .whereType<Map<String, dynamic>>()
          .toList()
          .asMap()
          .entries
          .map((e) {
        final uid = e.value['user_id']?.toString() ?? '';
        return WalletMember(
          userId: uid,
          name: nameMap[uid] ?? uid,
          role: e.value['role'] as String? ?? 'member',
          color: memberColorAt(e.key),
        );
      }).toList();

      final detail =
          WalletModel.fromDetailJson(detailData, resolvedMembers);

      // Update in-place inside _wallets list so list screen stays in sync
      final idx = _wallets.indexWhere((w) => w.id == walletId);
      if (idx >= 0) {
        _wallets[idx] = _wallets[idx].copyWith(
          members: resolvedMembers,
          transactions: detail.transactions,
        );
      } else {
        _wallets.add(detail);
      }

      notifyListeners();
      return detail;
    } on DioException catch (e) {
      _error = e.response?.data?['error']?.toString() ?? e.message;
      notifyListeners();
      return null;
    }
  }

  // ─── Load balances only ───────────────────────────────────────────────────

  Future<BalanceResult?> loadBalances(int walletId) async {
    try {
      final res = await _dio.get(ApiEndpoints.walletBalances(walletId));
      final bal = BalanceResult.fromJson(
          res.data['data'] as Map<String, dynamic>? ?? {});
      _balances[walletId] = bal;
      notifyListeners();
      return bal;
    } on DioException catch (e) {
      _error = e.response?.data?['error']?.toString() ?? e.message;
      notifyListeners();
      return null;
    }
  }

  // ─── Create wallet ────────────────────────────────────────────────────────

  Future<WalletModel?> createWallet(String name) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.wallet,
        data: {'name': name},
      );
      final w = WalletModel.fromListJson(
          res.data['data'] as Map<String, dynamic>);
      _wallets = [..._wallets, w];
      notifyListeners();
      return w;
    } on DioException catch (e) {
      _error = e.response?.data?['error']?.toString() ?? e.message;
      notifyListeners();
      return null;
    }
  }

  // ─── Join wallet ──────────────────────────────────────────────────────────

  Future<WalletModel?> joinWallet(int walletId, String inviteCode) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.walletJoin(walletId),
        data: {'invite_code': inviteCode},
      );
      final w = WalletModel.fromListJson(
          res.data['data'] as Map<String, dynamic>);
      _wallets = [..._wallets, w];
      notifyListeners();
      return w;
    } on DioException catch (e) {
      _error = e.response?.data?['error']?.toString() ?? e.message;
      notifyListeners();
      return null;
    }
  }

  // ─── Join wallet by invite code only ─────────────────────────────────────

  Future<WalletModel?> joinWalletByCode(String inviteCode) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.walletJoinByCode,
        data: {'invite_code': inviteCode},
      );
      final w = WalletModel.fromListJson(
          res.data['data'] as Map<String, dynamic>);
      _wallets = [..._wallets, w];
      notifyListeners();
      return w;
    } on DioException catch (e) {
      _error = e.response?.data?['error']?.toString() ?? e.message;
      notifyListeners();
      return null;
    }
  }

  // ─── Leave wallet ─────────────────────────────────────────────────────────

  Future<bool> leaveWallet(int walletId) async {
    try {
      await _dio.delete(ApiEndpoints.walletLeave(walletId));
      _wallets = _wallets.where((w) => w.id != walletId).toList();
      _balances.remove(walletId);
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _error = e.response?.data?['error']?.toString() ?? e.message;
      notifyListeners();
      return false;
    }
  }

  // ─── Delete wallet ────────────────────────────────────────────────────────

  Future<bool> deleteWallet(int walletId) async {
    try {
      await _dio.delete(ApiEndpoints.walletById(walletId));
      _wallets = _wallets.where((w) => w.id != walletId).toList();
      _balances.remove(walletId);
      notifyListeners();
      return true;
    } on DioException catch (e) {
      _error = e.response?.data?['error']?.toString() ?? e.message;
      notifyListeners();
      return false;
    }
  }

  // ─── Record settlement ────────────────────────────────────────────────────

  Future<bool> settleWith(NetEntry entry) async {
    try {
      await _dio.post(
        ApiEndpoints.walletSettle(entry.walletId),
        data: {
          'from_user_id': entry.fromUserId,
          'to_user_id': entry.toUserId,
          'amount': entry.amount.abs(),
        },
      );
      // Refresh balances so the settle screen updates automatically
      await loadBalances(entry.walletId);
      return true;
    } on DioException catch (e) {
      _error = e.response?.data?['error']?.toString() ?? e.message;
      notifyListeners();
      return false;
    }
  }

  // ─── Link an existing expense transaction to a wallet ────────────────────

  Future<bool> linkExpense({
    required int walletId,
    required int transactionId,
    required List<Map<String, dynamic>> splits,
  }) async {
    try {
      await _dio.post(
        ApiEndpoints.walletExpense(walletId),
        data: {
          'transaction_id': transactionId,
          'split_with': splits,
        },
      );
      await loadWalletDetail(walletId);
      return true;
    } on DioException catch (e) {
      _error = e.response?.data?['error']?.toString() ?? e.message;
      notifyListeners();
      return false;
    }
  }
}
