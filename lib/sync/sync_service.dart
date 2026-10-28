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

  static const Duration _probeInterval = Duration(seconds: 45);
  static const Duration _probeTimeout = Duration(seconds: 8);

  final Connectivity _connectivity = Connectivity();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  StreamSubscription<AuthAccount?>? _authSub;
  final List<StreamSubscription<BoxEvent>> _boxSubs = [];
  Timer? _debounced;
  Timer? _probeTimer;
  DateTime? _lastProbe;

  bool _online = false;

  bool _cloudVerified = false;

  bool _syncing = false;
  int _pendingCount = 0;
  String? _lastError;

  bool get isOnline => _online;

  bool get isCloudVerified => _cloudVerified;

  bool get isSyncing => _syncing;

  int get pendingCount => _pendingCount;

  String? get lastError => _lastError;

  String get statusLabel {
    if (_syncing) return 'در حال همگام‌سازی...';
    if (!_online) return 'آفلاین';
    if (!_cloudVerified) return 'در انتظار تایید اتصال به کلود';
    if (_pendingCount > 0) {
      return '${_fa(_pendingCount)} مورد در انتظار همگام‌سازی';
    }
    return 'همگام';
  }

  /// Call once after Hive + Firebase are ready.
  Future<void> start() async {
    await _refreshConnectivity();

    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      final wasOnline = _online;

      _online = results.any((result) => result != ConnectivityResult.none);

      // An interface that came back is not a server that came back, so the
      // previous confirmation no longer holds.
      if (_online != wasOnline) _cloudVerified = false;

      if (_online) {
        unawaited(probeCloud());
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

    _recountPending();

    _probeTimer = Timer.periodic(
      _probeInterval,
      (_) => unawaited(probeCloud()),
    );

    _authSub = AuthService.instance.authStateChanges.listen((account) async {
      if (account == null || !AuthService.instance.isCloudReady) return;

      // Pulling first is what makes pushing safe: reading the cloud tells a
      // local row which document belongs to it, and a row that uploads without
      // that binding can land on another row's document. Merging only ever
      // adds, so this also tops up a restore that stopped half way.
      await _restoreFromCloud();

      syncNow();
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
    _probeTimer?.cancel();
    _probeTimer = null;
    _connectivitySub = null;
    _authSub = null;
  }

  void scheduleSync() {
    _recountPending();
    notifyListeners();
    _debounced?.cancel();
    _debounced = Timer(_debounce, syncNow);
  }

  /// Whether Firestore can be reached right now. The logout flow needs this
  /// rather than a network interface alone: signing out wipes the device, and
  /// wiping before the rows are uploaded loses them.
  Future<bool> refreshOnline() async {
    await _refreshConnectivity();

    if (!_online) {
      _cloudVerified = false;
      notifyListeners();

      return false;
    }

    // A device-local account has no cloud to reach, so nothing can fail there.
    if (!AuthService.instance.isCloudReady) {
      notifyListeners();

      return true;
    }

    final verified = await probeCloud();
    notifyListeners();

    return verified;
  }

  /// Asks the server itself whether it answers. Connectivity only reports that
  /// a network interface is up, which stays true on a Wi-Fi with no internet,
  /// and that is why the chip used to insist on «همگام» while offline.
  Future<bool> probeCloud() async {
    _lastProbe = DateTime.now();

    if (!_online || !AuthService.instance.isCloudReady) {
      _cloudVerified = false;
      notifyListeners();

      return false;
    }

    final uid = AuthService.instance.uid!;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('data')
          .limit(1)
          .get(const GetOptions(source: Source.server))
          .timeout(_probeTimeout);

      _cloudVerified = true;
      _lastError = null;
    } on FirebaseException catch (e) {
      _cloudVerified = false;
      _lastError = e.code;
    } on Exception {
      _cloudVerified = false;
    }

    notifyListeners();

    return _cloudVerified;
  }

  void _probeCloudThrottled() {
    final last = _lastProbe;

    if (last != null && DateTime.now().difference(last) < _probeInterval) {
      return;
    }

    unawaited(probeCloud());
  }

  /// The explicit retry: an empty queue needs the server's answer, not a push.
  Future<void> refresh() async {
    _lastProbe = null;
    await syncNow();
  }

  /// Pushes everything still on the device and returns a Persian message when
  /// something failed to reach Firestore. Signing out wipes the ledger, so the
  /// caller must not wipe while this reports a problem.
  Future<String?> flushBeforeSignOut() async {
    _debounced?.cancel();

    for (var round = 0; round < 3; round++) {
      await _awaitIdle();
      await syncNow();

      if (_pendingCount > 0) continue;

      // A device-local account has no cloud to flush into.
      if (!AuthService.instance.isCloudReady) return null;

      // The queue is empty either because the rows arrived or because nothing
      // ever left the phone; only the server can tell those apart.
      if (await probeCloud()) return null;
    }

    final error = _lastError;

    if (_pendingCount == 0) {
      return error == null
          ? 'کلود پاسخ نداد، کمی بعد دوباره تلاش کنید.'
          : 'کلود پاسخ نداد ($error).';
    }

    return '${_fa(_pendingCount)} مورد هنوز در ابر ذخیره نشده است'
        '${error == null ? '.' : ' ($error).'}';
  }

  Future<void> _awaitIdle() async {
    while (_syncing) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }

  Future<void> syncNow() async {
    await _refreshConnectivity();

    final uid = AuthService.instance.isCloudReady
        ? AuthService.instance.uid
        : null;
    if (uid != null) await _requeueUnbound();

    _recountPending();

    if (uid == null || !_online || _syncing || _pendingCount == 0) {
      if (uid != null && _online && !_syncing && !_cloudVerified) {
        _probeCloudThrottled();
      }

      notifyListeners();
      return;
    }

    _syncing = true;
    _lastError = null;
    notifyListeners();

    try {
      for (final phase in <Future<void> Function(String)>[
        _pushDeletes,
        _pushCustomers,
        _pushPayments,
        _pushLoans,
      ]) {
        try {
          await phase(uid);
        } on FirebaseException catch (e) {
          _lastError ??= e.code;
          _cloudVerified = false;
        } catch (e) {
          _lastError ??= e.toString();
          _online = false;
          _cloudVerified = false;
        }
      }

      // Committing a batch is itself proof that the server was reached.
      if (_lastError == null) _cloudVerified = true;
    } finally {
      _syncing = false;
      _recountPending();
      notifyListeners();
    }
  }

  Future<void> _refreshConnectivity() async {
    final results = await _connectivity.checkConnectivity();

    final online = results.any((result) => result != ConnectivityResult.none);

    if (online != _online) _cloudVerified = false;

    _online = online;
  }

  void _recountPending() {
    _pendingCount =
        DatabaseHelper.customers.values.where((c) => !c.isSynced).length +
        DatabaseHelper.payments.values.where((p) => !p.isSynced).length +
        DatabaseHelper.loans.values.where((l) => !l.isSynced).length +
        DatabaseHelper.pendingDeletes.length;
  }

  DocumentReference<Map<String, dynamic>> _doc(String uid, String docId) {
    return FirebaseFirestore.instance.doc('users/$uid/data/$docId');
  }

  /// The document a local row owns, minting a fresh one the first time it is
  /// asked for. Every later write reuses that name, so renumbering on the
  /// device can never point two rows at the same document.
  static Future<String> _docIdFor(String boxName, Object localKey) async {
    final bindingKey = DatabaseHelper.deleteKey(boxName, localKey);

    final bound = DatabaseHelper.docIds.get(bindingKey);
    if (bound != null) return bound;

    final taken = DatabaseHelper.docIds.values.toSet();
    final stamp = DateTime.now().microsecondsSinceEpoch;

    var docId = '$boxName-$stamp';
    for (var n = 1; taken.contains(docId); n++) {
      docId = '$boxName-${stamp}_$n';
    }

    await DatabaseHelper.docIds.put(bindingKey, docId);

    return docId;
  }

  static Future<void> _bind(
    String boxName,
    Object localKey,
    String docId,
  ) async {
    final bindingKey = DatabaseHelper.deleteKey(boxName, localKey);

    if (DatabaseHelper.docIds.get(bindingKey) == docId) return;

    await DatabaseHelper.docIds.put(bindingKey, docId);
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

      // A row that never got a binding was uploaded by the build that named
      // documents after local keys, which is exactly `boxName-localKey`. The
      // guess is only safe while no live row owns that document: keys start
      // over from zero after a box is cleared, so the number an old tombstone
      // carries can belong to some other customer by now.
      final docId =
          DatabaseHelper.docIds.get(tombstone) ??
          _legacyDocId(boxName, localKey);

      if (docId == null) {
        // Its document was never in the cloud, so there is nothing to delete.
        await DatabaseHelper.pendingDeletes.delete(tombstone);

        continue;
      }

      await _doc(uid, docId).delete();
      await DatabaseHelper.docIds.delete(tombstone);
      await DatabaseHelper.pendingDeletes.delete(tombstone);
    }
  }

  /// `boxName-localKey`, or null when a live row is already bound to it.
  static String? _legacyDocId(String boxName, String localKey) {
    final candidate = '$boxName-$localKey';

    return DatabaseHelper.docIds.values.contains(candidate) ? null : candidate;
  }

  Future<void> _pushCustomers(String uid) async {
    final box = DatabaseHelper.customers;

    await _upload(
      uid: uid,
      boxName: DatabaseHelper.customersBox,
      targets: _unsyncedKeys(box),
      payloadFor: (key) => box.get(key)!.toMap(),
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

    await _upload(
      uid: uid,
      boxName: DatabaseHelper.paymentsBox,
      targets: _unsyncedKeys(box),
      payloadFor: (key) async => {
        ...box.get(key)!.toMap(),
        'customerDocId': await _docIdFor(
          DatabaseHelper.customersBox,
          box.get(key)!.customerKey,
        ),
      },
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

    await _upload(
      uid: uid,
      boxName: DatabaseHelper.loansBox,
      targets: _unsyncedKeys(box),
      payloadFor: (key) async => {
        ...box.get(key)!.toMap(),
        'customerDocId': await _docIdFor(
          DatabaseHelper.customersBox,
          box.get(key)!.customerKey,
        ),
      },
      onUploaded: (key) {
        final loan = box.get(key);
        if (loan != null) {
          loan.isSynced = true;
          box.put(key, loan);
        }
      },
    );
  }

  static List<dynamic> _unsyncedKeys<T>(Box<T> box) => box.keys
      .where((key) => (box.get(key) as dynamic)?.isSynced == false)
      .toList();

  Future<void> _upload({
    required String uid,
    required String boxName,
    required List<dynamic> targets,
    required FutureOr<Map<String, dynamic>> Function(dynamic key) payloadFor,
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
          _doc(uid, await _docIdFor(boxName, key)),
          await payloadFor(key),
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
  /// device.
  ///
  /// Every row is bound to the document it came from. The key a document was
  /// uploaded under belongs to the device that wrote it, so a restored row takes
  /// the next free key here and remembers which document is its own; that is what
  /// keeps a later edit from landing on the document of whichever row happened to
  /// carry the same number.
  static Future<RestoreReport> mergeCloudData(
    Map<String, Map<String, dynamic>> rows,
  ) async {
    final customerBox = DatabaseHelper.customers;
    final loanBox = DatabaseHelper.loans;
    final paymentBox = DatabaseHelper.payments;

    final cloudCustomers = <String, Map<String, dynamic>>{};
    final cloudLoans = <String, Map<String, dynamic>>{};
    final cloudPayments = <String, Map<String, dynamic>>{};

    for (final row in rows.entries) {
      switch (_boxNameOf(row.key)) {
        case DatabaseHelper.customersBox:
          cloudCustomers[row.key] = row.value;
        case DatabaseHelper.loansBox:
          cloudLoans[row.key] = row.value;
        case DatabaseHelper.paymentsBox:
          cloudPayments[row.key] = row.value;
        default:
          break;
      }
    }

    var customers = 0, loans = 0, payments = 0, skipped = 0, orphans = 0;

    // A loan or payment points at its customer by document id. Documents
    // written before that was stored carry the local key instead, which is the
    // number in the customer document's own name.
    final localKeyOfCustomerDoc = <String, int>{};
    final localKeyOfLegacyCustomer = <int, int>{};

    final knownCustomers = _CustomerIndex(customerBox);

    for (final entry in cloudCustomers.entries) {
      final remote = Customer.fromMap(entry.value);
      final alreadyLocal = knownCustomers.find(remote);

      final int localKey;

      if (alreadyLocal != null) {
        localKey = alreadyLocal;
        skipped++;
      } else {
        final restored = Customer(
          name: remote.name,
          nickname: remote.nickname,
          phone: remote.phone,
          createdAt: remote.createdAt,
          isSynced: true,
        );

        localKey = await customerBox.add(restored);

        knownCustomers.add(restored, localKey);
        customers++;
      }

      await _bind(DatabaseHelper.customersBox, localKey, entry.key);

      localKeyOfCustomerDoc[entry.key] = localKey;

      final legacyKey = _legacyKeyOf(entry.key);
      if (legacyKey != null) localKeyOfLegacyCustomer[legacyKey] = localKey;
    }

    final knownLoans = _LoanIndex(loanBox);

    for (final entry in cloudLoans.entries) {
      final remote = Loan.fromMap(entry.value);
      final parentKey = _customerKeyOf(
        entry.value,
        localKeyOfCustomerDoc,
        localKeyOfLegacyCustomer,
      );

      if (parentKey == null) {
        orphans++;
        continue;
      }

      final restored = Loan(
        customerKey: parentKey,
        title: remote.title,
        items: remote.items,
        dateTime: remote.dateTime,
        isSynced: true,
      );

      final alreadyLocal = knownLoans.find(restored);

      final int localKey;

      if (alreadyLocal != null) {
        localKey = alreadyLocal;
        skipped++;
      } else {
        localKey = await loanBox.add(restored);

        knownLoans.add(restored, localKey);
        loans++;
      }

      await _bind(DatabaseHelper.loansBox, localKey, entry.key);
    }

    final knownPayments = _PaymentIndex(paymentBox);

    for (final entry in cloudPayments.entries) {
      final remote = Payment.fromMap(entry.value);
      final parentKey = _customerKeyOf(
        entry.value,
        localKeyOfCustomerDoc,
        localKeyOfLegacyCustomer,
      );

      if (parentKey == null) {
        orphans++;
        continue;
      }

      final restored = Payment(
        customerKey: parentKey,
        amount: remote.amount,
        description: remote.description,
        dateTime: remote.dateTime,
        isSynced: true,
      );

      final alreadyLocal = knownPayments.find(restored);

      final int localKey;

      if (alreadyLocal != null) {
        localKey = alreadyLocal;
        skipped++;
      } else {
        localKey = await paymentBox.add(restored);

        knownPayments.add(restored, localKey);
        payments++;
      }

      await _bind(DatabaseHelper.paymentsBox, localKey, entry.key);
    }

    return RestoreReport(
      customers: customers,
      loans: loans,
      payments: payments,
      skipped: skipped,
      orphans: orphans,
      requeued: await _requeueUnbound(),
    );
  }

  /// Document ids look like `loans-37`; the part before the last dash names the
  /// box the row came from.
  static String? _boxNameOf(String docId) {
    final separator = docId.lastIndexOf('-');

    return separator <= 0 ? null : docId.substring(0, separator);
  }

  /// The key the uploading device handed out, which only documents named by the
  /// build that used that key as a document name still carry.
  static int? _legacyKeyOf(String docId) =>
      int.tryParse(docId.substring(docId.lastIndexOf('-') + 1));

  static int? _customerKeyOf(
    Map<String, dynamic> payload,
    Map<String, int> localKeyOfCustomerDoc,
    Map<int, int> localKeyOfLegacyCustomer,
  ) {
    final docId = payload['customerDocId'];

    if (docId is String) return localKeyOfCustomerDoc[docId];

    final legacy = payload['customerKey'];

    return legacy is num ? localKeyOfLegacyCustomer[legacy.toInt()] : null;
  }

  /// Rows an older build marked as synced although no document ever held them:
  /// they were written over another row's document and exist nowhere. Sending
  /// them again is what lets «همگام» mean the data really is in Firestore.
  static Future<int> _requeueUnbound() async {
    final bound = DatabaseHelper.docIds.keys.cast<String>().toSet();

    var requeued = 0;

    Future<void> requeue<T>(String boxName, Box<T> box) async {
      for (final key in box.keys) {
        final row = box.get(key);

        if (row == null || !(row as dynamic).isSynced) continue;
        if (bound.contains(DatabaseHelper.deleteKey(boxName, key))) continue;

        (row as dynamic).isSynced = false;

        await box.put(key, row);
        requeued++;
      }
    }

    await requeue(DatabaseHelper.customersBox, DatabaseHelper.customers);
    await requeue(DatabaseHelper.loansBox, DatabaseHelper.loans);
    await requeue(DatabaseHelper.paymentsBox, DatabaseHelper.payments);

    return requeued;
  }

  Future<void> _restoreFromCloud() async {
    if (_syncing) await _awaitIdle();

    final uid = AuthService.instance.uid!;

    _syncing = true;
    _lastError = null;
    notifyListeners();

    try {
      // From the server, not the local Firestore cache: a restore has to bring
      // what the cloud holds, and a cache read would succeed while offline.
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('data')
          .get(const GetOptions(source: Source.server));

      _cloudVerified = true;

      await mergeCloudData({
        for (final doc in snapshot.docs) doc.id: doc.data(),
      });
    } on FirebaseException catch (e) {
      _lastError = e.code;
      _cloudVerified = false;
    } catch (e) {
      _lastError = e.toString();
      _cloudVerified = false;
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

/// Rows are matched by content so a second restore of the same document does
/// not duplicate it. A customer saved before `createdAt` existed carries 0 and
/// is therefore compared on name, nickname and phone alone.
class _CustomerIndex {
  _CustomerIndex(Box<Customer> box) {
    for (final key in box.keys) {
      add(box.get(key), key as int);
    }
  }

  final _withTime = <String, int>{};
  final _withoutTime = <String, int>{};

  static String _fingerprint(Customer customer, {required bool withTime}) =>
      withTime
      ? '${customer.name}\u0000${customer.nickname}\u0000'
            '${customer.phone}\u0000${customer.createdAt}'
      : '${customer.name}\u0000${customer.nickname}\u0000${customer.phone}';

  void add(Customer? customer, int key) {
    if (customer == null) return;

    _withTime[_fingerprint(customer, withTime: true)] = key;
    _withoutTime[_fingerprint(customer, withTime: false)] = key;
  }

  int? find(Customer customer) => customer.createdAt == 0
      ? _withoutTime[_fingerprint(customer, withTime: false)]
      : _withTime[_fingerprint(customer, withTime: true)];
}

class _LoanIndex {
  _LoanIndex(Box<Loan> box) {
    for (final key in box.keys) {
      add(box.get(key), key as int);
    }
  }

  final _keys = <String, int>{};

  static String _fingerprint(Loan loan) => [
    loan.customerKey,
    loan.title,
    loan.dateTime.millisecondsSinceEpoch,
    for (final item in loan.items)
      '${item.name}:${item.unitPrice}:${item.quantity}',
  ].join('\u0000');

  void add(Loan? loan, int key) {
    if (loan == null) return;

    _keys[_fingerprint(loan)] = key;
  }

  int? find(Loan loan) => _keys[_fingerprint(loan)];
}

class _PaymentIndex {
  _PaymentIndex(Box<Payment> box) {
    for (final key in box.keys) {
      add(box.get(key), key as int);
    }
  }

  final _keys = <String, int>{};

  static String _fingerprint(Payment payment) => [
    payment.customerKey,
    payment.amount,
    payment.description,
    payment.dateTime.millisecondsSinceEpoch,
  ].join('\u0000');

  void add(Payment? payment, int key) {
    if (payment == null) return;

    _keys[_fingerprint(payment)] = key;
  }

  int? find(Payment payment) => _keys[_fingerprint(payment)];
}

class RestoreReport {
  const RestoreReport({
    required this.customers,
    required this.loans,
    required this.payments,
    required this.skipped,
    required this.orphans,
    required this.requeued,
  });

  final int customers;
  final int loans;
  final int payments;

  /// Rows that were already on the device under the same content.
  final int skipped;

  /// Loans and payments whose customer document is missing from the cloud.
  final int orphans;

  /// Rows that were marked as synced although no document held them.
  final int requeued;
}
