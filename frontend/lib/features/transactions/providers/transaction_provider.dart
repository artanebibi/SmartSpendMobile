import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/transaction_model.dart';

class CategoryModel {
  final int id;
  final String name;
  const CategoryModel({required this.id, required this.name});
  factory CategoryModel.fromJson(Map<String, dynamic> j) =>
      CategoryModel(id: (j['id'] as num).toInt(), name: j['name'] ?? '');
}

class TransactionProvider extends ChangeNotifier {
  List<TransactionModel> _transactions = [];
  List<CategoryModel> _categories = [];
  bool _isLoading = false;
  String? _error;

  List<TransactionModel> get transactions => _transactions;
  List<CategoryModel> get categories => _categories;
  List<TransactionModel> get recent => _transactions.take(5).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;

  final _dio = ApiClient.instance;

  Future<void> load({DateTime? from, DateTime? to}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Categories are fetched independently — a failure here must NOT block
    // the transaction fetch, it just means we show 'Other' for all categories.
    try {
      await _loadCategories();
    } catch (e) {
      debugPrint('[TransactionProvider] _loadCategories failed: $e');
    }

    try {
      final params = <String, String>{};
      if (from != null) params['from'] = from.toUtc().toIso8601String();
      if (to != null) params['to'] = to.toUtc().toIso8601String();

      final res = await _dio.get(
        ApiEndpoints.transaction,
        queryParameters: params.isEmpty ? null : params,
      );

      debugPrint('[TransactionProvider] GET transactions → ${res.statusCode} body: ${res.data}');

      // Support both { data: [...] } and a bare list response
      final raw = res.data;
      final list = raw is List
          ? raw
          : (raw is Map ? (raw['data'] as List? ?? []) : <dynamic>[]);

      final parsed = <TransactionModel>[];
      for (final e in list) {
        try {
          final map = e as Map<String, dynamic>;
          final catId = (map['category_id'] as num?)?.toInt();
          final catName = _categories
              .firstWhere(
                (c) => c.id == catId,
                orElse: () => const CategoryModel(id: 0, name: 'Other'),
              )
              .name;
          parsed.add(TransactionModel.fromJson(map, categoryName: catName));
        } catch (parseErr) {
          debugPrint('[TransactionProvider] skipped malformed transaction: $parseErr | raw: $e');
        }
      }

      _transactions = parsed..sort((a, b) => b.dateMade.compareTo(a.dateMade));
    } catch (e) {
      _error = e.toString();
      debugPrint('[TransactionProvider] load() error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadCategories({bool force = false}) async {
    if (_categories.isNotEmpty && !force) return;
    try {
      final res = await _dio.get(ApiEndpoints.category);
      debugPrint('[TransactionProvider] GET categories → ${res.statusCode} body: ${res.data}');

      final raw = res.data;
      final list = raw is List
          ? raw
          : (raw is Map ? (raw['data'] as List? ?? []) : <dynamic>[]);

      _categories = list
          .whereType<Map<String, dynamic>>()
          .map((e) => CategoryModel.fromJson(e))
          .toList();

      notifyListeners();
    } catch (e) {
      debugPrint('[TransactionProvider] loadCategories error: $e');
    }
  }

  // kept as an internal alias so load() still compiles
  Future<void> _loadCategories() => loadCategories();

  Future<bool> add({
    required String title,
    required double price,
    required String type,
    required int? categoryId,
    required DateTime dateMade,
  }) async {
    try {
      await _dio.post(ApiEndpoints.transaction, data: {
        'title': title,
        'price': price,
        'date_made': dateMade.toUtc().toIso8601String(),
        'category_id': categoryId,
        'type': type,
      });
      await load();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> update(TransactionModel tx) async {
    try {
      await _dio.patch(ApiEndpoints.transactionById(tx.id), data: tx.toJson());
      await load();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> delete(int id) async {
    try {
      await _dio.delete(ApiEndpoints.transactionById(id));
      await load();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
