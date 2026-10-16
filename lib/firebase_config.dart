import 'package:firebase_core/firebase_core.dart';

class FirebaseConfig {
  const FirebaseConfig._();

  static const String projectId = 'for-shop-655e1';
  static const String appId = '1:1099465078749:android:e8614c9729557ff116e834';
  static const String apiKey = 'AIzaSyDff6bZEleDsSRLUCMS3d_QTFGZ4Tx-zEA';
  static const String messagingSenderId = '1099465078749';

  static bool get isFilled =>
      projectId.isNotEmpty &&
      appId.isNotEmpty &&
      apiKey.isNotEmpty &&
      messagingSenderId.isNotEmpty;

  static FirebaseOptions get android => FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: messagingSenderId,
    projectId: projectId,
  );
}
