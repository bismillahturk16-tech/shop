class Customer {
  final String name;

  final String? nickname;

  final String? phone;

  /// Milliseconds since epoch; drives the order of the customer list.
  final int createdAt;

  bool isSynced;

  Customer({
    required this.name,
    this.nickname,
    this.phone,
    this.isSynced = false,
    int? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toMap() => {
    'name': name,
    'nickname': nickname,
    'phone': phone,
    'createdAt': createdAt,
  };

  /// Rows saved before this field existed restore as the oldest ones, so they
  /// keep the order they were pulled in instead of jumping to the top.
  factory Customer.fromMap(Map<String, dynamic> map) => Customer(
    name: map['name'] as String,
    nickname: map['nickname'] as String?,
    phone: map['phone'] as String?,
    createdAt: (map['createdAt'] as num?)?.toInt() ?? 0,
  );

  bool sameContent(Customer other) =>
      name == other.name &&
      nickname == other.nickname &&
      phone == other.phone;
}
