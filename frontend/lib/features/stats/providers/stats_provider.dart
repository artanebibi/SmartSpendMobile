import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

class PieSlice {
  final String category;
  final double percentage;
  final double amount;
  const PieSlice({
    required this.category,
    required this.percentage,
    required this.amount,
  });
}

class MonthlyBar {
  final String month;
  final double expense;
  final double income;
  const MonthlyBar({
    required this.month,
    required this.expense,
    required this.income,
  });
}

class StatsProvider extends ChangeNotifier {
  List<PieSlice> _pieData = [];
  List<MonthlyBar> _monthlyData = [];
  double _totalIncome = 0;
  double _totalExpenses = 0;
  double _averageExpense = 0;
  double _averageIncome = 0;
  bool _isLoading = false;
  String? _error;

  List<PieSlice> get pieData => _pieData;
  List<MonthlyBar> get monthlyData => _monthlyData;
  double get totalIncome => _totalIncome;
  double get totalExpenses => _totalExpenses;
  double get netSavings => _totalIncome - _totalExpenses;
  double get averageExpense => _averageExpense;
  double get averageIncome => _averageIncome;
  bool get isLoading => _isLoading;
  String? get error => _error;

  final _dio = ApiClient.instance;

  Future<void> load({required DateTime from, required DateTime to}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final params = {
      'from': from.toUtc().toIso8601String(),
      'to': to.toUtc().toIso8601String(),
    };

    // Each endpoint is fetched independently — one failure does NOT wipe the rest.
    await Future.wait([
      _loadPie(params),
      _loadMonthly(params),
      _loadAverage(params),
    ]);

    _isLoading = false;
    notifyListeners();
  }

  // ─── Pie / totals ─────────────────────────────────────────────────────────────
  // Response shape: { data: [{ statistics: { "CategoryName": percentage, ... },
  //                            total_expenses: N, total_income: N }] }

  Future<void> _loadPie(Map<String, String> params) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.statisticsPie,
        queryParameters: params,
      );
      debugPrint('[StatsProvider] pie → ${res.statusCode} body: ${res.data}');

      final raw = res.data;
      final list = raw is List
          ? raw
          : (raw is Map ? (raw['data'] as List? ?? []) : <dynamic>[]);

      if (list.isEmpty) return;

      final first = Map<String, dynamic>.from(list[0] as Map);

      _totalIncome = (first['total_income'] as num?)?.toDouble() ?? 0;
      _totalExpenses = (first['total_expenses'] as num?)?.toDouble() ?? 0;

      // statistics is a Map<String, dynamic> where:
      //   key   = category name  (e.g. "Groceries")
      //   value = percentage      (e.g. 4.15)
      final statsRaw = first['statistics'];
      if (statsRaw is Map) {
        _pieData = statsRaw.entries.map((e) {
          final pct = (e.value as num?)?.toDouble() ?? 0;
          return PieSlice(
            category: e.key.toString(),
            percentage: pct,
            amount: _totalExpenses * pct / 100,
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('[StatsProvider] _loadPie error: $e');
      _error = e.toString();
    }
  }

  // ─── Monthly ─────────────────────────────────────────────────────────────────
  // Response shape: { data: [{ statistics: { "5": 5540, ... },
  //                            total_expenses: N, total_income: N }] }
  // Key is a month number (1–12), value is the total amount for that month.

  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _monthLabel(String key) {
    final n = int.tryParse(key);
    if (n != null && n >= 1 && n <= 12) return _monthNames[n - 1];
    return key;
  }

  Future<void> _loadMonthly(Map<String, String> params) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.statisticsMonthly,
        queryParameters: params,
      );
      debugPrint('[StatsProvider] monthly → ${res.statusCode} body: ${res.data}');

      final raw = res.data;
      final list = raw is List
          ? raw
          : (raw is Map ? (raw['data'] as List? ?? []) : <dynamic>[]);

      if (list.isEmpty) return;

      final first = Map<String, dynamic>.from(list[0] as Map);

      // statistics is a Map<String, dynamic> where:
      //   key   = month number as string (e.g. "5" for May)
      //   value = total expense amount for that month
      final statsRaw = first['statistics'];
      if (statsRaw is Map) {
        final entries = statsRaw.entries.toList()
          ..sort((a, b) {
            final ai = int.tryParse(a.key.toString()) ?? 0;
            final bi = int.tryParse(b.key.toString()) ?? 0;
            return ai.compareTo(bi);
          });

        _monthlyData = entries.map((e) {
          return MonthlyBar(
            month: _monthLabel(e.key.toString()),
            expense: (e.value as num?)?.toDouble() ?? 0,
            income: 0, // backend monthly endpoint only tracks expenses
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('[StatsProvider] _loadMonthly error: $e');
      _error = e.toString();
    }
  }

  // ─── Average ─────────────────────────────────────────────────────────────────

  Future<void> _loadAverage(Map<String, String> params) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.statisticsAverage,
        queryParameters: params,
      );
      debugPrint('[StatsProvider] average → ${res.statusCode} body: ${res.data}');

      final raw = res.data;
      final list = raw is List
          ? raw
          : (raw is Map ? (raw['data'] as List? ?? []) : <dynamic>[]);

      if (list.isEmpty) return;

      final first = list[0] as Map<String, dynamic>? ?? {};
      _averageExpense = (first['average_expense'] as num?)?.toDouble() ?? 0;
      _averageIncome = (first['average_income'] as num?)?.toDouble() ?? 0;
    } catch (e) {
      debugPrint('[StatsProvider] _loadAverage error: $e');
      _error = e.toString();
    }
  }
}
