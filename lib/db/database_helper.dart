import 'package:hive_flutter/hive_flutter.dart';

import 'package:for_shop/models/customer.dart';
import 'package:for_shop/models/customer_adapter.dart';
import 'package:for_shop/models/payment.dart';
import 'package:for_shop/models/payment_adapter.dart';
import 'package:for_shop/models/loan.dart';
import 'package:for_shop/models/loan_adapter.dart';

class DatabaseHelper {
  static const String customersBox = 'customers';
  static const String paymentsBox = 'payments';
  static const String loansBox = 'loans';

  /// Keys like `customers:4` -> deletion time in milliseconds.
  static const String pendingDeletesBox = 'pending_deletes';

  /// Keys like `customers:4` -> the Firestore document that row owns. A Hive
  /// key starts over at zero once a box is cleared, so it can never double as a
  /// document name; this box is what keeps the two in step.
  static const String docMapBox = 'cloud_doc_ids';

  static const String metaBox = 'app_meta';

  /// Device-local accounts used while Firebase is not configured yet.
  static const String authBox = 'auth_local';

  /// Bump when a hand-written adapter changes shape: the data boxes are
  /// rebuilt once from the cloud instead of being read with a stale layout.
  static const int _schemaVersion = 3;

  static Future<void> init() async {
    await Hive.initFlutter();

    final meta = await Hive.openBox<dynamic>(metaBox);

    if (meta.get('schemaVersion') != _schemaVersion) {
      await Hive.deleteBoxFromDisk(customersBox);
      await Hive.deleteBoxFromDisk(paymentsBox);
      await Hive.deleteBoxFromDisk(loansBox);
      await Hive.deleteBoxFromDisk(pendingDeletesBox);
      await Hive.deleteBoxFromDisk(docMapBox);
      await meta.put('schemaVersion', _schemaVersion);
    }

    Hive.registerAdapter(CustomerAdapter());
    Hive.registerAdapter(PaymentAdapter());
    Hive.registerAdapter(LoanItemAdapter());
    Hive.registerAdapter(LoanAdapter());

    await Hive.openBox<Customer>(customersBox);
    await Hive.openBox<Payment>(paymentsBox);
    await Hive.openBox<Loan>(loansBox);
    await Hive.openBox<int>(pendingDeletesBox);
    await Hive.openBox<String>(docMapBox);
    await Hive.openBox<dynamic>(authBox);
  }

  static Box<Customer> get customers => Hive.box<Customer>(customersBox);

  static Box<Payment> get payments => Hive.box<Payment>(paymentsBox);

  static Box<Loan> get loans => Hive.box<Loan>(loansBox);

  static Box<int> get pendingDeletes => Hive.box<int>(pendingDeletesBox);

  static Box<String> get docIds => Hive.box<String>(docMapBox);

  /// Signing out leaves nothing on the device, so an account can never merge
  /// with the data of the one that was used before it.
  static Future<void> wipeLocalData() async {
    await customers.clear();
    await payments.clear();
    await loans.clear();
    await pendingDeletes.clear();
    await docIds.clear();
  }

  static String deleteKey(String boxName, Object localKey) =>
      '$boxName:$localKey';

  static Future<void> markDeleted(String boxName, Object localKey) {
    return pendingDeletes.put(
      deleteKey(boxName, localKey),
      DateTime.now().millisecondsSinceEpoch,
    );
  }
}
