import 'package:flutter/material.dart';

import 'package:for_shop/db/database_helper.dart';
import 'package:for_shop/screens/home_screen.dart';
import 'package:for_shop/screens/login_screen.dart';
import 'package:for_shop/services/auth_service.dart';
import 'package:for_shop/sync/sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await DatabaseHelper.init();
  await AuthService.instance.configure();

  runApp(const ForShop());
}

class ForShop extends StatefulWidget {
  const ForShop({super.key});

  @override
  State<ForShop> createState() => _ForShopState();
}

class _ForShopState extends State<ForShop> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      SyncService.instance.start();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SyncService.instance.stop();
    super.dispose();
  }

  /// Coming back to the foreground retries whatever stayed unsynced.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SyncService.instance.scheduleSync();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'دفترچه قرضه',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF513680)),
      ),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.ltr,
        child: child ?? const SizedBox.shrink(),
      ),
      home: const AuthGate(),
    );
  }
}

/// Hive stays available whether or not the user signs in; the account only
/// unlocks the cloud backup.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _continueOffline = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthAccount?>(
      stream: AuthService.instance.authStateChanges,
      builder: (context, snapshot) {
        final signedIn = snapshot.data != null;

        if (signedIn || _continueOffline) {
          return const HomeScreen();
        }

        return LoginScreen(
          onContinueOffline: () {
            setState(() => _continueOffline = true);
          },
        );
      },
    );
  }
}
