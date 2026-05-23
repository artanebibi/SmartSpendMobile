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
    String categoryName = 'Other',
  }) =>
      TransactionModel(
        id: (j['id'] as num).toInt(),
        title: j['title'] ?? '',
        price: (j['price'] as num).toDouble(),
        dateMade: DateTime.parse(j['date_made']).toLocal(),
        categoryId: (j['category_id'] as num?)?.toInt(),
        categoryName: categoryName,
        type: j['type'] ?? 'Expense',
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
