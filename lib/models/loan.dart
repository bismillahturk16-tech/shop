class Loan {
  final int customerKey;
  final String title;
  final List<LoanItem> items;
  final DateTime dateTime;

  bool isSynced;

  Loan({
    required this.customerKey,
    required this.title,
    required this.items,
    required this.dateTime,
    this.isSynced = false,
  });

  double get totalAmount {
    return items.fold(0.0, (total, item) => total + item.lineTotal);
  }

  int get itemCount => items.length;

  Map<String, dynamic> toMap() => {
    'customerKey': customerKey,
    'title': title,
    'dateTime': dateTime.millisecondsSinceEpoch,
    'items': items.map((item) => item.toMap()).toList(),
  };

  factory Loan.fromMap(Map<String, dynamic> map) => Loan(
    customerKey: (map['customerKey'] as num).toInt(),
    title: map['title'] as String,
    dateTime: DateTime.fromMillisecondsSinceEpoch(
      (map['dateTime'] as num).toInt(),
    ),
    items: [
      for (final raw in (map['items'] as List? ?? const []))
        LoanItem.fromMap(Map<String, dynamic>.from(raw as Map)),
    ],
  );
}

class LoanItem {
  final String name;
  final double unitPrice;
  final double quantity;

  LoanItem({
    required this.name,
    required this.unitPrice,
    required this.quantity,
  });

  double get lineTotal => unitPrice * quantity;

  Map<String, dynamic> toMap() => {
    'name': name,
    'unitPrice': unitPrice,
    'quantity': quantity,
  };

  /// Rows stored before the unit price existed carried a flat `amount`, which is
  /// read back as the price of a single unit.
  factory LoanItem.fromMap(Map<String, dynamic> map) => LoanItem(
    name: (map['name'] as String?) ?? '',
    unitPrice:
        (map['unitPrice'] as num?)?.toDouble() ??
        (map['amount'] as num?)?.toDouble() ??
        0,
    quantity: (map['quantity'] as num?)?.toDouble() ?? 1,
  );
}
