import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:hive/hive.dart';

class StoredAccount {
  const StoredAccount({required this.id, required this.email});

  final String id;
  final String email;
}

/// Email/password accounts kept on the device, used until Firebase is
/// configured. Only a salted SHA-256 hash is stored, never the password.
class LocalAuthStore {
  LocalAuthStore._(this._box);

  static const String boxName = 'auth_local';

  static LocalAuthStore? _instance;

  static LocalAuthStore get instance => _instance!;

  static void attach() =>
      _instance = LocalAuthStore._(Hive.box<dynamic>(boxName));

  final Box<dynamic> _box;
  final Random _random = Random.secure();

  String _normalize(String email) => email.trim().toLowerCase();

  Map<String, dynamic> get _accounts {
    final raw = _box.get('accounts');

    return raw is Map
        ? Map<String, dynamic>.from(raw.cast<String, dynamic>())
        : <String, dynamic>{};
  }

  StoredAccount? get current {
    final email = _box.get('currentEmail') as String?;

    if (email == null) return null;

    return accountFor(email);
  }

  StoredAccount? accountFor(String email) {
    final entry = _accounts[_normalize(email)];

    if (entry is! Map) return null;

    return StoredAccount(
      id: entry['id'] as String,
      email: entry['email'] as String,
    );
  }

  bool hasAccount(String email) => accountFor(email) != null;

  /// Returns null on success, otherwise a Persian message.
  Future<String?> create({
    required String email,
    required String password,
  }) async {
    final key = _normalize(email);

    if (hasAccount(key)) return 'این ایمیل قبلاً ثبت شده است.';

    final saltHex = _randomHex();
    final accounts = _accounts;

    accounts[key] = {
      'id': 'local-${_randomHex()}',
      'email': email.trim(),
      'salt': saltHex,
      'hash': _hash(password, saltHex),
    };

    await _box.put('accounts', accounts);
    await _box.put('currentEmail', key);

    return null;
  }

  /// Returns null when the credentials are correct.
  Future<String?> verify({
    required String email,
    required String password,
  }) async {
    final entry = _accounts[_normalize(email)];

    if (entry is! Map) return 'با این ایمیل حسابی ثبت نشده است.';

    if (_hash(password, entry['salt'] as String) != entry['hash']) {
      return 'ایمیل یا رمز عبور نادرست است.';
    }

    await _box.put('currentEmail', _normalize(email));

    return null;
  }

  Future<void> useAccount(String email) =>
      _box.put('currentEmail', _normalize(email));

  Future<void> clearCurrent() => _box.delete('currentEmail');

  String _hash(String password, String saltHex) {
    return sha256.convert(utf8.encode('$saltHex:$password')).toString();
  }

  String _randomHex() {
    return List<String>.generate(
      16,
      (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}
