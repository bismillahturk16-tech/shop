import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:for_shop/db/database_helper.dart';
import 'package:for_shop/models/customer.dart';
import 'package:for_shop/models/loan.dart';
import 'package:for_shop/models/payment.dart';
import 'package:for_shop/services/auth_service.dart';

class SyncService extends ChangeNotifier {
  SyncService._();

  static final SyncService instance = SyncService._();

  static const int _batchLimit = 400;
  static const Duration _debounce = Duration(seconds: 2);

  final Connectivity _connectivity = Connectivity();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  StreamSubscription<AuthAccount?>? _authSub;
  final List<StreamSubscription<BoxEvent>> _boxSubs = [];
  Timer? _debounced;

  bool _online = false;
  bool _syncing = false;
  int _pendingCount = 0;
  String? _lastError;

  bool get isOnline => _online;

  bool get isSyncing => _syncing;

  int get pendingCount => _pendingCount;

  String? get lastError => _lastError;

  String get statusLabel {
    if (_syncing) return 'در حال همگام‌سازی...';
    if (!_online) return 'آفلاین';
    if (_pendingCount > 0) return '$_pendingCount مورد در انتظار همگام‌سازی';
    return 'همگام';
  }

  /// Call once after Hive + Firebase are ready.
  Future<void> start() async {
    await _refreshConnectivity();

    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      _online = results.any((result) => result != ConnectivityResult.none);

      if (_online) {
        syncNow();
      }

      notifyListeners();
    });

    _boxSubs.add(
      DatabaseHelper.customers.watch().listen((_) => scheduleSync()),
    );
    _boxSubs.add(DatabaseHelper.payments.watch().listen((_) => scheduleSync()));
    _boxSubs.add(DatabaseHelper.loans.watch().listen((_) => scheduleSync()));
    _boxSubs.add(
      DatabaseHelper.pendingDeletes.watch().listen((_) => scheduleSync()),
    );

    _trackGuestData();
    _recountPending();

    // Rows written before an account existed have no other trigger: signing in
    // is the first moment they can reach the cloud.
    _authSub = AuthService.instance.authStateChanges.listen((account) {
      if (account != null) scheduleSync();
    });

    if (_online) syncNow();
  }

  Future<void> stop() async {
    await _connectivitySub?.cancel();
    await _authSub?.cancel();
    for (final subscription in _boxSubs) {
      await subscription.cancel();
    }
    _boxSubs.clear();
    _debounced?.cancel();
    _connectivitySub = null;
    _authSub = null;
  }

  void scheduleSync() {
    _trackGuestData();
    _recountPending();
    notifyListeners();
    _debounced?.cancel();
    _debounced = Timer(_debounce, syncNow);
  }

  /// Rows written while no account is signed in are the only ones a later
  /// sign-in is allowed to merge with the cloud.
  void _trackGuestData() {
    if (AuthService.instance.account != null) return;
    if (!DatabaseHelper.hasLocalData) return;

    DatabaseHelper.markGuestData();
  }

  /// Signing out wipes the device, so the logout flow needs to know that the
  /// unsynced rows can still be uploaded.
  Future<bool> refreshOnline() async {
    await _refreshConnectivity();
    notifyListeners();

    return _online;
  }

  Future<void> syncNow() async {
    await _refreshConnectivity();

    final uid = AuthService.instance.isCloudReady
        ? AuthService.instance.uid
        : null;

    _recountPending();

    if (uid == null || !_online || _syncing || _pendingCount == 0) {
      notifyListeners();
      return;
    }

    _syncing = true;
    _lastError = null;
    notifyListeners();

    try {
      await _pushDeletes(uid);
      await _pushCustomers(uid);
      await _pushPayments(uid);
      await _pushLoans(uid);
    } on FirebaseException catch (e) {
      _lastError = e.code;
    } catch (e) {
      _lastError = e.toString();
      _online = false;
    } finally {
      _syncing = false;
      _recountPending();
      notifyListeners();
    }
  }

  Future<void> _refreshConnectivity() async {
    final results = await _connectivity.checkConnectivity();

    _online = results.any((result) => result != ConnectivityResult.none);
  }

  void _recountPending() {
    _pendingCount =
        DatabaseHelper.customers.values.where((c) => !c.isSynced).length +
        DatabaseHelper.payments.values.where((p) => !p.isSynced).length +
        DatabaseHelper.loans.values.where((l) => !l.isSynced).length +
        DatabaseHelper.pendingDeletes.length;
  }

  DocumentReference<Map<String, dynamic>> _doc(
    String uid,
    String boxName,
    Object localKey,
  ) {
    return FirebaseFirestore.instance.doc('users/$uid/data/$boxName-$localKey');
  }

  Future<void> _pushDeletes(String uid) async {
    final tombstones = DatabaseHelper.pendingDeletes.keys
        .cast<String>()
        .toList();

    if (tombstones.isEmpty) return;

    for (final tombstone in tombstones) {
      final separator = tombstone.lastIndexOf(':');
      final boxName = tombstone.substring(0, separator);
      final localKey = tombstone.substring(separator + 1);

      await _doc(uid, boxName, localKey).delete();
      await DatabaseHelper.pendingDeletes.delete(tombstone);
    }
  }

  Future<void> _pushCustomers(String uid) async {
    final box = DatabaseHelper.customers;
    final targets = box.keys
        .where((key) => box.get(key)?.isSynced == false)
        .toList();

    await _upload(
      uid: uid,
      boxName: 'customers',
      payloadFor: (key) => box.get(key)!.toMap(),
      targets: targets,
      onUploaded: (key) {
        final customer = box.get(key);
        if (customer != null) {
          customer.isSynced = true;
          box.put(key, customer);
        }
      },
    );
  }

  Future<void> _pushPayments(String uid) async {
    final box = DatabaseHelper.payments;
    final targets = box.keys
        .where((key) => box.get(key)?.isSynced == false)
        .toList();

    await _upload(
      uid: uid,
      boxName: 'payments',
      payloadFor: (key) => box.get(key)!.toMap(),
      targets: targets,
      onUploaded: (key) {
        final payment = box.get(key);
        if (payment != null) {
          payment.isSynced = true;
          box.put(key, payment);
        }
      },
    );
  }

  Future<void> _pushLoans(String uid) async {
    final box = DatabaseHelper.loans;
    final targets = box.keys
        .where((key) => box.get(key)?.isSynced == false)
        .toList();

    await _upload(
      uid: uid,
      boxName: 'loans',
      payloadFor: (key) => box.get(key)!.toMap(),
      targets: targets,
      onUploaded: (key) {
        final loan = box.get(key);
        if (loan != null) {
          loan.isSynced = true;
          box.put(key, loan);
        }
      },
    );
  }

  Future<void> _upload({
    required String uid,
    required String boxName,
    required List<dynamic> targets,
    required Map<String, dynamic> Function(dynamic key) payloadFor,
    required void Function(dynamic key) onUploaded,
  }) async {
    if (targets.isEmpty) return;

    for (var start = 0; start < targets.length; start += _batchLimit) {
      final chunk = targets.sublist(
        start,
        (start + _batchLimit).clamp(0, targets.length),
      );

      final batch = FirebaseFirestore.instance.batch();

      for (final key in chunk) {
        batch.set(
          _doc(uid, boxName, '$key'),
          payloadFor(key),
          SetOptions(merge: true),
        );
      }

      await batch.commit();

      for (final key in chunk) {
        onUploaded(key);
      }
    }
  }

  /// Pulls `users/{uid}/data/*` into Hive, merging with what is already on the
  /// device. Hive keys differ per device, so customer references inside loans
  /// and payments are remapped through [RestoreReport.customerKeys].
  static Future<RestoreReport> mergeCloudData(
    Map<String, Map<String, dynamic>> rows,
  ) async {
    final customerBox = DatabaseHelper.customers;
    final loanBox = DatabaseHelper.loans;
    final paymentBox = DatabaseHelper.payments;

    final customerKeys = <int, int>{};
    var customers = 0, loans = 0, payments = 0, skipped = 0;

    for (final row in rows.entries) {
      final parsed = _splitDocId(row.key);

      if (parsed.$1 != 'customers') continue;

      final remote = Customer.fromMap(row.value);
      final existing = _findCustomer(remote);

      if (existing != null) {
        customerKeys[parsed.$2] = existing;
        skipped++;
        continue;
      }

      final newKey = await customerBox.add(
        Customer(
          name: remote.name,
          nickname: remote.nickname,
          phone: remote.phone,
          isSynced: true,
        ),
      );

      customerKeys[parsed.$2] = newKey;
      customers++;
    }

    for (final row in rows.entries) {
      final parsed = _splitDocId(row.key);

      if (parsed.$1 != 'loans') continue;

      final remote = Loan.fromMap(row.value);
      final mappedKey = customerKeys[remote.customerKey];

      if (mappedKey == null) {
        skipped++;
        continue;
      }

      final merged = Loan(
        customerKey: mappedKey,
        title: remote.title,
        items: remote.items,
        dateTime: remote.dateTime,
        isSynced: true,
      );

      if (_findLoan(merged) != null) {
        skipped++;
        continue;
      }

      await loanBox.add(merged);
      loans++;
    }

    for (final row in rows.entries) {
      final parsed = _splitDocId(row.key);

      if (parsed.$1 != 'payments') continue;

      final remote = Payment.fromMap(row.value);
      final mappedKey = customerKeys[remote.customerKey];

      if (mappedKey == null) {
        skipped++;
        continue;
      }

      final merged = Payment(
        customerKey: mappedKey,
        amount: remote.amount,
        description: remote.description,
        dateTime: remote.dateTime,
        isSynced: true,
      );

      if (_findPayment(merged) != null) {
        skipped++;
        continue;
      }

      await paymentBox.add(merged);
      payments++;
    }

    return RestoreReport(
      customers: customers,
      loans: loans,
      payments: payments,
      skipped: skipped,
      customerKeys: customerKeys,
    );
  }

  static (String, int) _splitDocId(String docId) {
    final separator = docId.indexOf('-');

    return (
      docId.substring(0, separator),
      int.tryParse(docId.substring(separator + 1)) ?? -1,
    );
  }

  static int? _findCustomer(Customer candidate) {
    final box = DatabaseHelper.customers;

    for (final key in box.keys) {
      final local = box.get(key);

      if (local != null && local.sameContent(candidate)) return key as int;
    }

    return null;
  }

  static int? _findLoan(Loan candidate) {
    final box = DatabaseHelper.loans;

    for (final key in box.keys) {
      final local = box.get(key);

      if (local != null && local.sameContent(candidate)) return key as int;
    }

    return null;
  }

  static int? _findPayment(Payment candidate) {
    final box = DatabaseHelper.payments;

    for (final key in box.keys) {
      final local = box.get(key);

      if (local != null && local.sameContent(candidate)) return key as int;
    }

    return null;
  }

  /// Returns a Persian message describing what was restored.
  Future<String> restoreFromCloud() async {
    if (!AuthService.instance.isCloudReady) {
      return 'برای بازیابی باید با حساب خود وارد شوید.';
    }

    if (DatabaseHelper.hasLocalData && !DatabaseHelper.hasGuestData) {
      return 'داده‌های روی این گوشی متعلق به همین حساب است و ادغام لازم نیست.';
    }

    if (_syncing) return 'یک عملیات دیگر در حال انجام است؛ کمی بعد تلاش کنید.';

    final uid = AuthService.instance.uid!;

    _syncing = true;
    _lastError = null;
    notifyListeners();

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('data')
          .get();

      final rows = <String, Map<String, dynamic>>{
        for (final doc in snapshot.docs) doc.id: doc.data(),
      };

      final report = await mergeCloudData(rows);

      final parts = <String>[
        if (report.customers > 0) '${_fa(report.customers)} مشتری',
        if (report.loans > 0) '${_fa(report.loans)} قرض',
        if (report.payments > 0) '${_fa(report.payments)} پرداخت',
      ];

      if (parts.isEmpty) {
        return report.skipped == 0
            ? 'داده‌ای در کلَود پیدا نشد.'
            : 'همه داده‌ها از قبل روی این تلفن بود.';
      }

      return 'بازیابی شد: ${parts.join('، ')}.';
    } on FirebaseException catch (e) {
      _lastError = e.code;

      return 'بازیابی انجام نشد (${e.code}).';
    } catch (e) {
      _lastError = e.toString();

      return 'بازیابی انجام نشد.';
    } finally {
      _syncing = false;
      _recountPending();
      notifyListeners();
    }
  }

  static String _fa(int value) =>
      value.toString().replaceAllMapped(RegExp(r'[0-9]'), (m) {
        const digits = '۰۱۲۳۴۵۶۷۸۹';

        return digits[int.parse(m[0]!)];
      });
}

class RestoreReport {
  const RestoreReport({
    required this.customers,
    required this.loans,
    required this.payments,
    required this.skipped,
    required this.customerKeys,
  });

  final int customers;
  final int loans;
  final int payments;
  final int skipped;

  final Map<int, int> customerKeys;
}
