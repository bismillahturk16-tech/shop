import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:for_shop/db/database_helper.dart';
import 'package:for_shop/firebase_config.dart';
import 'package:for_shop/services/local_auth_store.dart';

class AuthAccount {
  const AuthAccount({
    required this.id,
    required this.email,
    required this.isRemote,
  });

  final String id;
  final String email;

  /// True when the account lives in Firebase Auth, false for a device-local
  /// account created while Firebase is not configured yet.
  final bool isRemote;
}

/// Single auth entry point for the UI. It talks to Firebase Auth when the app
/// is configured, and to a Hive-backed local account store otherwise, so the
/// login and signup screens behave the same in both modes.
class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final StreamController<AuthAccount?> _accounts =
      StreamController<AuthAccount?>.broadcast();

  FirebaseApp? _app;
  AuthAccount? _current;

  bool get isEnabled => _app != null;

  AuthAccount? get account => _current;

  String? get uid => _current?.id;

  /// Cloud sync needs both Firebase and a Firebase-signed account.
  bool get isCloudReady => isEnabled && _current?.isRemote == true;

  Stream<AuthAccount?> get authStateChanges async* {
    yield _current;
    yield* _accounts.stream;
  }

  Future<void> configure() async {
    await _initFirebase();

    LocalAuthStore.attach();

    if (_app != null) {
      final remote = FirebaseAuth.instance.currentUser;

      _publish(
        remote == null
            ? null
            : AuthAccount(
                id: remote.uid,
                email: remote.email ?? '',
                isRemote: true,
              ),
      );

      FirebaseAuth.instance.authStateChanges().listen((user) {
        _publish(
          user == null
              ? null
              : AuthAccount(
                  id: user.uid,
                  email: user.email ?? '',
                  isRemote: true,
                ),
        );
      });

      return;
    }

    final local = LocalAuthStore.instance.current;

    _publish(
      local == null
          ? null
          : AuthAccount(id: local.id, email: local.email, isRemote: false),
    );
  }

  Future<void> _initFirebase() async {
    if (_app != null) return;

    try {
      _app = Firebase.apps.isNotEmpty
          ? Firebase.app()
          : await Firebase.initializeApp();
    } on Exception {
      _app = null;
    }

    if (_app == null && FirebaseConfig.isFilled) {
      // No google-services.json: initialize from the values in
      // lib/firebase_config.dart instead.
      try {
        _app = await Firebase.initializeApp(options: FirebaseConfig.android);
      } on Exception {
        _app = null;
      }
    }
  }

  /// Returns null on success, otherwise a Persian message to show the user.
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    if (!isEnabled) {
      final error = await LocalAuthStore.instance.verify(
        email: email,
        password: password,
      );

      if (error != null) return error;

      final account = LocalAuthStore.instance.accountFor(email)!;

      _publish(
        AuthAccount(id: account.id, email: account.email, isRemote: false),
      );

      return null;
    }

    try {
      final result = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = result.user;

      if (user == null) return 'ورود انجام نشد.';

      _publish(
        AuthAccount(id: user.uid, email: user.email ?? '', isRemote: true),
      );

      return null;
    } on FirebaseAuthException catch (e) {
      return _message(e);
    }
  }

  Future<String?> signUp({
    required String email,
    required String password,
  }) async {
    if (!isEnabled) {
      final error = await LocalAuthStore.instance.create(
        email: email,
        password: password,
      );

      if (error != null) return error;

      final account = LocalAuthStore.instance.accountFor(email)!;

      _publish(
        AuthAccount(id: account.id, email: account.email, isRemote: false),
      );

      return null;
    }

    try {
      final result = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = result.user;

      if (user == null) return 'حساب ساخته نشد.';

      _publish(
        AuthAccount(id: user.uid, email: user.email ?? '', isRemote: true),
      );

      return null;
    } on FirebaseAuthException catch (e) {
      return _message(e);
    }
  }

  Future<void> signOut() async {
    if (isEnabled) await FirebaseAuth.instance.signOut();

    await LocalAuthStore.instance.clearCurrent();

    // Nothing of this account may survive on the device: the next email signs
    // in to a clean ledger.
    await DatabaseHelper.wipeLocalData();

    _publish(null);
  }

  /// Asked only before deleting a customer; the password is never stored.
  Future<String?> confirmPassword(String password) async {
    final current = _current;

    if (current == null) return 'وارد حساب خود نشده‌اید.';

    if (!current.isRemote) {
      return LocalAuthStore.instance.verify(
        email: current.email,
        password: password,
      );
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return 'نشست شما تمام شده است، دوباره وارد شوید.';

    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: user.email!, password: password),
      );

      return null;
    } on FirebaseAuthException catch (e) {
      return _message(e);
    }
  }

  void _publish(AuthAccount? account) {
    _current = account;
    if (!_accounts.isClosed) _accounts.add(account);
  }

  String _message(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'ایمیل معتبر نیست.';
      case 'user-disabled':
        return 'این حساب غیرفعال شده است.';
      case 'user-not-found':
        return 'با این ایمیل حسابی ثبت نشده است.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'ایمیل یا رمز عبور نادرست است.';
      case 'email-already-in-use':
        return 'این ایمیل قبلاً ثبت شده است.';
      case 'weak-password':
        return 'رمز عبور باید حداقل ۶ نویسه باشد.';
      case 'network-request-failed':
        return 'برای این کار به اینترنت نیاز است.';
      case 'requires-recent-login':
        return 'برای امنیت، دوباره وارد حساب شوید.';
      case 'too-many-requests':
        return 'چند تلاش ناموفق پشت سر هم؛ کمی بعد دوباره تلاش کنید.';
      default:
        return 'خطا: ${error.message ?? error.code}';
    }
  }
}
