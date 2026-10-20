class Payment {
  final int customerKey;
  final double amount;
  final String? description;
  final DateTime dateTime;

  bool isSynced;

  Payment({
    required this.customerKey,
    required this.amount,
    this.description,
    required this.dateTime,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() => {
    'customerKey': customerKey,
    'amount': amount,
    'description': description,
    'dateTime': dateTime.millisecondsSinceEpoch,
  };

  factory Payment.fromMap(Map<String, dynamic> map) => Payment(
    customerKey: (map['customerKey'] as num).toInt(),
    amount: (map['amount'] as num).toDouble(),
    description: map['description'] as String?,
    dateTime: DateTime.fromMillisecondsSinceEpoch(
      (map['dateTime'] as num).toInt(),
    ),
  );
}
