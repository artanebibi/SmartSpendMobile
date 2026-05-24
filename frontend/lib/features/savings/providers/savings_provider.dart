import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/saving_model.dart';

class Contribution {
  final double amount;
  final DateTime date;
  const Contribution({required this.amount, required this.date});

  factory Contribution.fromJson(Map<String, dynamic> j) => Contribution(
        amount: (j['amount'] as num).toDouble(),
        date: DateTime.parse(j['date']),
      );

  Map<String, dynamic> toJson() =>
      {'amount': amount, 'date': date.toIso8601String()};
}

class SavingsProvider extends ChangeNotifier {
  List<SavingModel> _savings = [];
  bool _isLoading = false;
  String? _error;

  List<SavingModel> get savings => _savings;
  bool get isLoading => _isLoading;
  String? get error => _error;

  double get totalSaved => _savings.fold(0, (s, g) => s + g.amount);
  double get totalTarget => _savings.fold(0, (s, g) => s + g.targetAmount);

  final _dio = ApiClient.instance;
  static const _metaKey = 'savings_meta';

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await _dio.get(ApiEndpoints.saving);
      final list = (res.data['data'] as List? ?? []);
      final meta = await _loadMeta();

      _savings = list.map((e) {
        final s = SavingModel.fromJson(e as Map<String, dynamic>);
        final m = meta[s.id.toString()];
        if (m == null) return s;
        return s.copyWith(
          name: m['name'],
          targetAmount: (m['target'] as num?)?.toDouble(),
          color: Color(m['color'] as int? ?? 0xFF3D7EFF),
          deadline:
              m['deadline'] != null ? DateTime.parse(m['deadline']) : null,
        );
      }).toList();
    } catch (e) {
      _error = e.toString();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> create({
    required String name,
    required double targetAmount,
    required Color color,
    DateTime? deadline,
  }) async {
    try {
      final now = DateTime.now();
      await _dio.post(ApiEndpoints.saving, data: {
        'amount': 0,
        'from': now.toUtc().toIso8601String(),
        'to': (deadline ?? now.add(const Duration(days: 365)))
            .toUtc()
            .toIso8601String(),
      });
      await load();
      // Attach metadata to the newest (most-recent from) saving
      if (_savings.isNotEmpty) {
        final newest =
            _savings.reduce((a, b) => a.from.isAfter(b.from) ? a : b);
        await _saveMeta(newest.id, name, targetAmount, color, deadline, []);
        await load();
      }
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> addContribution(int id, double additional) async {
    final idx = _savings.indexWhere((s) => s.id == id);
    if (idx == -1) return false;
    final current = _savings[idx];
    try {
      await _dio.patch(ApiEndpoints.savingById(id), data: {
        'id': id,
        'amount': current.amount + additional,
        'from': current.from.toUtc().toIso8601String(),
        'to': current.to.toUtc().toIso8601String(),
      });
      // Record contribution locally
      final meta = await _loadMeta();
      final m = Map<String, dynamic>.from(
          (meta[id.toString()] as Map?)?.cast<String, dynamic>() ?? {});
      final contribs = (m['contributions'] as List? ?? [])
          .map((c) => Contribution.fromJson(c as Map<String, dynamic>))
          .toList();
      contribs.add(Contribution(amount: additional, date: DateTime.now()));
      m['contributions'] = contribs.map((c) => c.toJson()).toList();
      meta[id.toString()] = m;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_metaKey, jsonEncode(meta));

      await load();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<List<Contribution>> getContributions(int id) async {
    final meta = await _loadMeta();
    final m = meta[id.toString()];
    if (m == null) return [];
    final list = m['contributions'] as List? ?? [];
    return list
        .map((c) => Contribution.fromJson(c as Map<String, dynamic>))
        .toList()
        .reversed
        .toList();
  }

  Future<bool> delete(int id) async {
    try {
      await _dio.delete(ApiEndpoints.savingById(id));
      _savings.removeWhere((s) => s.id == id);
      await _deleteMeta(id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ─── Local metadata ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _loadMeta() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_metaKey);
    if (raw == null) return {};
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  Future<void> _saveMeta(
    int id,
    String name,
    double target,
    Color color,
    DateTime? deadline,
    List<Contribution> contributions,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final meta = await _loadMeta();
    final existing = meta[id.toString()] as Map?;
    meta[id.toString()] = {
      'name': name,
      'target': target,
      'color': color.toARGB32(),
      'deadline': deadline?.toIso8601String(),
      'contributions': existing?['contributions'] ??
          contributions.map((c) => c.toJson()).toList(),
    };
    await prefs.setString(_metaKey, jsonEncode(meta));
  }

  Future<void> _deleteMeta(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final meta = await _loadMeta();
    meta.remove(id.toString());
    await prefs.setString(_metaKey, jsonEncode(meta));
  }
}
