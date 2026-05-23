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
    notifyListeners();

    final fromStr = from.toUtc().toIso8601String();
    final toStr = to.toUtc().toIso8601String();
    final params = {'from': fromStr, 'to': toStr};

    try {
      final results = await Future.wait([
        _dio.get(ApiEndpoints.statisticsPie, queryParameters: params),
        _dio.get(ApiEndpoints.statisticsMonthly, queryParameters: params),
        _dio.get(ApiEndpoints.statisticsTotalSpent, queryParameters: params),
        _dio.get(ApiEndpoints.statisticsAverage, queryParameters: params),
      ]);

      // Pie
      final pieList = (results[0].data['data'] as List? ?? []);
      if (pieList.isNotEmpty) {
        final pieStats =
            pieList[0]['statistics'] as List? ?? [];
        _pieData = pieStats
            .map((e) => PieSlice(
                  category: e['category'] ?? '',
                  percentage: (e['percentage'] as num).toDouble(),
                  amount: (e['amount'] as num).toDouble(),
                ))
            .toList();
        _totalIncome =
            (pieList[0]['total_income'] as num?)?.toDouble() ?? 0;
        _totalExpenses =
            (pieList[0]['total_expenses'] as num?)?.toDouble() ?? 0;
      }

      // Monthly
      final monthlyList = (results[1].data['data'] as List? ?? []);
      if (monthlyList.isNotEmpty) {
        final stats = monthlyList[0]['statistics'] as List? ?? [];
        // Build a map month -> expense
        final expMap = <String, double>{};
        for (final s in stats) {
          expMap[s['month'] as String] = (s['amount'] as num).toDouble();
        }
        _monthlyData = expMap.entries
            .map((e) => MonthlyBar(
                  month: e.key,
                  expense: e.value,
                  income: 0, // monthly endpoint only has one series
                ))
            .toList();
      }

      // Average
      final avgList = (results[3].data['data'] as List? ?? []);
      if (avgList.isNotEmpty) {
        _averageExpense =
            (avgList[0]['average_expense'] as num?)?.toDouble() ?? 0;
        _averageIncome =
            (avgList[0]['average_income'] as num?)?.toDouble() ?? 0;
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }
}
