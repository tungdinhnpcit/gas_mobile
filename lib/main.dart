// lib/main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/config/device_config.dart';
import 'core/constants/app_constants.dart';
import 'core/network/mtls_client.dart';
import 'core/services/background_polling_service.dart';
import 'core/services/notification_service.dart';
import 'firebase_options.dart';

/// Runs in a separate isolate — must be a top-level function.
/// @pragma ensures it survives tree-shaking in release builds.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.showLocalNotification(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Tự động chọn API URL: emulator → BE local, máy thật → production
  AppConstants.resolvedApiUrl = await DeviceConfig.resolveApiUrl(
    localUrl: AppConstants.localApiUrl,
    prodUrl:  AppConstants.prodApiUrl,
  );
  debugPrint('[CONFIG] API URL = ${AppConstants.resolvedApiUrl}');

  // Nạp client certificate (mTLS) trước khi bất kỳ Dio nào được tạo — xem
  // core/network/mtls_client.dart + core/network/api_client.dart
  await preloadMtlsContext();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('vi');

  // Khởi tạo background polling (cho điện thoại không có GMS)
  await BackgroundPollingService.init();

  // Register background handler before runApp
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(
    const ProviderScope(
      child: QuanLyGasApp(),
    ),
  );
}
