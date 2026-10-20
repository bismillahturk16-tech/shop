import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:for_shop/db/database_helper.dart';
import 'package:for_shop/models/customer.dart';
import 'package:for_shop/models/customer_adapter.dart';
import 'package:for_shop/models/loan.dart';
import 'package:for_shop/models/loan_adapter.dart';
import 'package:for_shop/models/payment.dart';
import 'package:for_shop/models/payment_adapter.dart';
import 'package:for_shop/sync/sync_service.dart';

Map<String, Map<String, dynamic>> cloudRows() => {
  'customers-0': {'name': 'Ali', 'nickname': null, 'phone': '0912'},
  'customers-1': {'name': 'Reza', 'nickname': 'RZ', 'phone': null},
  'loans-5': {
    'customerKey': 0,
    'title': 'قرض',
    'dateTime': 1700000000000,
    'items': [
      {'name': 'برنج', 'amount': 100000},
    ],
  },
  'payments-9': {
    'customerKey': 1,
    'amount': 50000,
    'description': null,
    'dateTime': 1700000001000,
  },
};

Future<void> clearBoxes() async {
  await DatabaseHelper.customers.clear();
  await DatabaseHelper.loans.clear();
  await DatabaseHelper.payments.clear();
  await DatabaseHelper.docIds.clear();
}

String? documentOf(String boxName, Object localKey) =>
    DatabaseHelper.docIds.get(DatabaseHelper.deleteKey(boxName, localKey));

void main() {
  late Directory dir;

  setUpAll(() async {
    dir = Directory.systemTemp.createTempSync('restore_test');
    Hive.init(dir.path);
    Hive.registerAdapter(CustomerAdapter());
    Hive.registerAdapter(PaymentAdapter());
    Hive.registerAdapter(LoanItemAdapter());
    Hive.registerAdapter(LoanAdapter());

    await Hive.openBox<Customer>(DatabaseHelper.customersBox);
    await Hive.openBox<Payment>(DatabaseHelper.paymentsBox);
    await Hive.openBox<Loan>(DatabaseHelper.loansBox);
    await Hive.openBox<int>(DatabaseHelper.pendingDeletesBox);
    await Hive.openBox<String>(DatabaseHelper.docMapBox);
  });

  test('restore merges cloud rows and remaps customer keys', () async {
    final report = await SyncService.mergeCloudData(cloudRows());

    expect(report.customers, 2);
    expect(report.loans, 1);
    expect(report.payments, 1);

    final aliKey = DatabaseHelper.customers.keys.first;
    final loan = DatabaseHelper.loans.values.first;
    final payment = DatabaseHelper.payments.values.first;

    expect(loan.customerKey, aliKey);
    expect(loan.isSynced, true);
    expect(loan.items.single.unitPrice, 100000);
    expect(loan.items.single.quantity, 1);
    expect(payment.customerKey, aliKey + 1);
    expect(payment.isSynced, true);
    expect(DatabaseHelper.customers.values.every((c) => c.isSynced), true);
  });

  test('every restored row owns exactly one cloud document', () async {
    final loanKey = DatabaseHelper.loans.keys.first;
    final paymentKey = DatabaseHelper.payments.keys.first;

    expect(documentOf('customers', 0), 'customers-0');
    expect(documentOf('customers', 1), 'customers-1');
    expect(documentOf('loans', loanKey), 'loans-5');
    expect(documentOf('payments', paymentKey), 'payments-9');

    expect(
      DatabaseHelper.docIds.values.toSet(),
      hasLength(DatabaseHelper.docIds.length),
    );
  });

  test('a second restore adds nothing because rows are deduplicated', () async {
    final before = DatabaseHelper.customers.length;
    final report = await SyncService.mergeCloudData(cloudRows());

    expect(report.customers, 0);
    expect(report.loans, 0);
    expect(report.payments, 0);
    expect(report.requeued, 0);
    expect(DatabaseHelper.customers.length, before);
  });

  test(
    'a restored row keeps its document even when the numbering differs',
    () async {
      // Hive starts counting at zero again once a box is cleared, so a document
      // named after the key of the device that wrote it can land on an unrelated
      // row here. The binding, not the key, decides where an edit is pushed.
      final gapped = <String, Map<String, dynamic>>{
        'customers-0': {'name': 'A', 'nickname': null, 'phone': null},
        'customers-1': {'name': 'B', 'nickname': null, 'phone': null},
        'customers-3': {'name': 'C', 'nickname': null, 'phone': null},
      };

      await clearBoxes();

      final report = await SyncService.mergeCloudData(gapped);

      expect(report.customers, 3);
      expect(report.requeued, 0);
      expect(
        DatabaseHelper.docIds.values.toSet(),
        containsAll(<String>['customers-0', 'customers-1', 'customers-3']),
      );

      final fresh = await DatabaseHelper.customers.add(
        Customer(name: 'New in town'),
      );

      // A row that never reached Firestore has no document yet, so it cannot be
      // written over the one of a row that has.
      expect(documentOf('customers', fresh), isNull);
    },
  );

  test('customers sharing a name and phone stay separate', () async {
    await clearBoxes();

    final report = await SyncService.mergeCloudData({
      'customers-1': {
        'name': 'Ali',
        'nickname': null,
        'phone': '0912',
        'createdAt': 1700000000000,
      },
      'customers-2': {
        'name': 'Ali',
        'nickname': null,
        'phone': '0912',
        'createdAt': 1700000500000,
      },
    });

    expect(report.customers, 2);
    expect(DatabaseHelper.customers.length, 2);
  });

  test('a loan naming its customer document follows it to a new key', () async {
    await clearBoxes();

    final report = await SyncService.mergeCloudData({
      'customers-1730000000000000': {
        'name': 'Sara',
        'nickname': null,
        'phone': null,
        'createdAt': 1700000000000,
      },
      'loans-1730000000000999': {
        'customerKey': 42,
        'customerDocId': 'customers-1730000000000000',
        'title': 'خرید',
        'dateTime': 1700000002000,
        'items': <Map<String, dynamic>>[],
      },
    });

    expect(report.loans, 1);

    final saraKey = DatabaseHelper.customers.keys.first;

    expect(saraKey, isNot(42));
    expect(DatabaseHelper.loans.values.single.customerKey, saraKey);
    expect(
      documentOf('loans', DatabaseHelper.loans.keys.first),
      'loans-1730000000000999',
    );
  });

  test(
    'a row marked synced without a document goes back into the queue',
    () async {
      await clearBoxes();

      // Written by the build that could push two rows onto the same document: the
      // flag says it is safe, Firestore has never heard of it.
      final ghost = await DatabaseHelper.customers.add(
        Customer(name: 'Gone missing', isSynced: true),
      );

      final report = await SyncService.mergeCloudData({});

      expect(report.requeued, 1);
      expect(DatabaseHelper.customers.get(ghost)!.isSynced, false);
    },
  );

  test('loans whose customer is missing are reported as orphans', () async {
    await clearBoxes();

    final report = await SyncService.mergeCloudData({
      'loans-77': {
        'customerKey': 4242,
        'title': 'بی‌صاحب',
        'dateTime': 1700000002000,
        'items': <Map<String, dynamic>>[],
      },
    });

    expect(report.loans, 0);
    expect(report.orphans, 1);
  });

  tearDownAll(() async {
    await Hive.close();
    dir.deleteSync(recursive: true);
  });
}
