class Customer {
  final String name;

  final String? nickname;

  final String? phone;

  bool isSynced;

  Customer({
    required this.name,
    this.nickname,
    this.phone,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'nickname': nickname,
    'phone': phone,
  };

  factory Customer.fromMap(Map<String, dynamic> map) => Customer(
    name: map['name'] as String,
    nickname: map['nickname'] as String?,
    phone: map['phone'] as String?,
  );

  bool sameContent(Customer other) =>
      name == other.name &&
      nickname == other.nickname &&
      phone == other.phone;
}
