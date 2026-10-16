import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:for_shop/models/customer.dart';
import 'package:for_shop/models/customer_adapter.dart';
import 'package:for_shop/models/loan.dart';
import 'package:for_shop/models/loan_adapter.dart';
import 'package:for_shop/models/payment.dart';
import 'package:for_shop/models/payment_adapter.dart';

void main() {
  test('isSynced round-trips through the adapters', () async {
    final dir = Directory.systemTemp.createTempSync('hive_sync_test');
    Hive.init(dir.path);
    Hive.registerAdapter(CustomerAdapter());
    Hive.registerAdapter(PaymentAdapter());
    Hive.registerAdapter(LoanItemAdapter());
    Hive.registerAdapter(LoanAdapter());

    final customers = await Hive.openBox<Customer>('customers');
    final payments = await Hive.openBox<Payment>('payments');
    final loans = await Hive.openBox<Loan>('loans');

    final customerKey = await customers.add(
      Customer(name: 'علی', phone: '۰۹۱۲'),
    );
    final paymentKey = await payments.add(
      Payment(
        customerKey: customerKey,
        amount: 250000,
        dateTime: DateTime(2026, 10, 12),
      ),
    );
    final loanKey = await loans.add(
      Loan(
        customerKey: customerKey,
        title: 'قرض',
        items: [LoanItem(name: 'برنج', unitPrice: 50000, quantity: 2)],
        dateTime: DateTime(2026, 10, 12),
      ),
    );

    expect(customers.get(customerKey)!.isSynced, false);
    expect(payments.get(paymentKey)!.isSynced, false);
    expect(loans.get(loanKey)!.isSynced, false);

    final customer = customers.get(customerKey)!;
    customer.isSynced = true;
    await customers.put(customerKey, customer);
    await customers.close();
    await payments.close();
    await loans.close();

    final reopened = await Hive.openBox<Customer>('customers');
    expect(reopened.get(customerKey)!.isSynced, true);
    expect(reopened.get(customerKey)!.name, 'علی');
    expect(reopened.get(customerKey)!.phone, '۰۹۱۲');
    expect(reopened.values.where((c) => !c.isSynced).isEmpty, true);

    await Hive.close();
    dir.deleteSync(recursive: true);
  });
}
