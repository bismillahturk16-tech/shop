import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:for_shop/services/local_auth_store.dart';

void main() {
  test('local accounts sign up, sign in and reject wrong passwords', () async {
    final dir = Directory.systemTemp.createTempSync('local_auth_test');
    Hive.init(dir.path);

    final box = await Hive.openBox<dynamic>(LocalAuthStore.boxName);
    LocalAuthStore.attach();
    box.deleteAll(box.keys.toList());

    final store = LocalAuthStore.instance;

    expect(
      await store.create(email: ' Ali@Shop.ir ', password: '123456'),
      isNull,
    );
    expect(store.current?.email, 'Ali@Shop.ir');
    expect(store.current!.id, startsWith('local-'));

    expect(
      await store.verify(email: 'ali@shop.ir', password: '123456'),
      isNull,
    );
    expect(
      await store.verify(email: 'ali@shop.ir', password: 'wrong'),
      isNotNull,
    );
    expect(
      await store.create(email: 'ali@shop.ir', password: '654321'),
      isNotNull,
    );

    final stored = Map<String, dynamic>.from(box.get('accounts') as Map);
    final entry = Map<String, dynamic>.from(
      (stored['ali@shop.ir'] as Map).cast<String, dynamic>(),
    );

    expect(entry['hash'], isNot('123456'));
    expect(entry['hash'].length, 64);

    await store.clearCurrent();
    expect(store.current, isNull);

    await Hive.close();
    dir.deleteSync(recursive: true);
  });
}
