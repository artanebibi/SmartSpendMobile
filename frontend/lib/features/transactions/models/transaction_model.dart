class TransactionModel {
  final int id;
  final String title;
  final double price;
  final DateTime dateMade;
  final int? categoryId;
  final String categoryName;
  final String type; // 'Expense' | 'Income'

  const TransactionModel({
    required this.id,
    required this.title,
    required this.price,
    required this.dateMade,
    this.categoryId,
    required this.categoryName,
    required this.type,
  });

  bool get isExpense => type == 'Expense';
  bool get isIncome => type == 'Income';

  factory TransactionModel.fromJson(
    Map<String, dynamic> j, {
    required String categoryName,
  }) =>
      TransactionModel(
        id: (j['id'] as num?)?.toInt() ?? 0,
        title: j['title']?.toString() ?? '',
        price: (j['price'] as num?)?.toDouble() ?? (j['amount'] as num?)?.toDouble() ?? 0.0,
        dateMade: j['date_made'] != null
            ? DateTime.tryParse(j['date_made'].toString())?.toLocal() ?? DateTime.now()
            : DateTime.now(),
        categoryId: (j['category_id'] as num?)?.toInt(),
        categoryName: categoryName,
        type: j['type']?.toString() ?? 'Expense',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'price': price,
        'date_made': dateMade.toUtc().toIso8601String(),
        'category_id': categoryId,
        'type': type,
      };
}
