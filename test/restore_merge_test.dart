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

  test('a second restore adds nothing because rows are deduplicated', () async {
    final before = DatabaseHelper.customers.length;
    final report = await SyncService.mergeCloudData(cloudRows());

    expect(report.customers, 0);
    expect(report.loans, 0);
    expect(report.payments, 0);
    expect(DatabaseHelper.customers.length, before);
  });

  test('loans whose customer is missing are skipped', () async {
    final report = await SyncService.mergeCloudData({
      'loans-77': {
        'customerKey': 4242,
        'title': 'بی‌صاحب',
        'dateTime': 1700000002000,
        'items': <Map<String, dynamic>>[],
      },
    });

    expect(report.loans, 0);
    expect(report.skipped, 1);
  });

  tearDownAll(() async {
    await Hive.close();
    dir.deleteSync(recursive: true);
  });
}
