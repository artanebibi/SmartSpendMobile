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

    try {
      await _loadCategories();

      final params = <String, String>{};
      if (from != null) params['from'] = from.toUtc().toIso8601String();
      if (to != null) params['to'] = to.toUtc().toIso8601String();

      final res = await _dio.get(
        ApiEndpoints.transaction,
        queryParameters: params.isEmpty ? null : params,
      );

      final list = (res.data['data'] as List? ?? []);
      _transactions = list.map((e) {
        final catId = (e['category_id'] as num?)?.toInt();
        final catName = _categories
            .firstWhere(
              (c) => c.id == catId,
              orElse: () => const CategoryModel(id: 0, name: 'Other'),
            )
            .name;
        return TransactionModel.fromJson(
          e as Map<String, dynamic>,
          categoryName: catName,
        );
      }).toList()
          ..sort((a, b) => b.dateMade.compareTo(a.dateMade));
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadCategories() async {
    if (_categories.isNotEmpty) return;
    try {
      final res = await _dio.get(ApiEndpoints.category);
      _categories = (res.data['data'] as List? ?? [])
          .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {}
  }

  Future<bool> add({
    required String title,
    required double price,
    required String type,
    required int? categoryId,
    required DateTime dateMade,
  }) async {
    try {
      await _dio.post(ApiEndpoints.transaction, data: {
        'id': 0,
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
      _transactions.removeWhere((t) => t.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
