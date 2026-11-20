// lib/core/services/notification_service.dart
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

import '../constants/app_constants.dart';
import '../constants/notification_types.dart';
import '../router/app_routes.dart';
import 'session_replaced_handler.dart';
import '../../features/lich_tuan/domain/entities/lich_tuan_entity.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Set externally after GoRouter is created
  static void Function(String route)? _navigateTo;

  static void setNavigateCallback(void Function(String route) callback) {
    _navigateTo = callback;
  }

  static Future<void> initialize() async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));

    const androidSettings =
        AndroidInitializationSettings('@drawable/ic_notification');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotifications.initialize(
      const InitializationSettings(
          android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onLocalNotificationTapped,
    );

    await _createAndroidChannel();

    // Request permission (iOS + Android 13+)
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Foreground: show heads-up notification manually (FCM does not show it)
    FirebaseMessaging.onMessage.listen((message) {
      // Đăng nhập trên máy khác → đăng xuất máy này ngay (app đang mở)
      if (message.data['loai'] == NotificationTypes.sessionReplaced) {
        SessionReplacedHandler.xuLy();
        return;
      }
      showLocalNotification(message);
    });

    // Background → tap: app resumed from background
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleNotificationNavigation(message.data);
    });

    // Terminated → tap: app cold-started by notification tap
    final initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleNotificationNavigation(initialMessage.data);
      });
    }
  }

  static Future<void> showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          AppConstants.notificationChannelId,
          AppConstants.notificationChannelName,
          channelDescription: AppConstants.notificationChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  static void _onLocalNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      final data = jsonDecode(response.payload!) as Map<String, dynamic>;
      _handleNotificationNavigation(data);
    }
  }

  static void _handleNotificationNavigation(Map<String, dynamic> data) {
    final loai = data['loai'] as String?;
    final id = data['id'] as String?;
    final hasId = id != null && id.isNotEmpty;

    switch (loai) {
      case NotificationTypes.chuyenMoi:
      case NotificationTypes.capNhatChuyen:
      case NotificationTypes.duyetChuyenXe:
        if (hasId) {
          _navigateTo?.call(AppRoutes.chuyenXeDetail(id));
        } else {
          _navigateTo?.call(AppRoutes.chuyenXeList);
        }
        break;
      case NotificationTypes.thongBao:
        if (hasId) {
          _navigateTo?.call(AppRoutes.thongBaoDetail(id));
        } else {
          _navigateTo?.call(AppRoutes.thongBaoList);
        }
        break;
      case NotificationTypes.lichTuan:
        _navigateTo?.call(AppRoutes.lichTuan);
        break;
      default:
        _navigateTo?.call(AppRoutes.home);
    }
  }

  /// Schedule local notification 1 day before each lịch tuần event at 07:00
  static Future<void> scheduleWeeklyScheduleReminders(
    List<LichTuanEntity> lichList,
  ) async {
    await _localNotifications.cancelAll();
    final now = tz.TZDateTime.now(tz.local);

    for (final lich in lichList) {
      final eventDate = tz.TZDateTime.from(lich.ngayGioBDBase, tz.local);
      final reminderTime = tz.TZDateTime(
        tz.local,
        eventDate.year,
        eventDate.month,
        eventDate.day - 1,
        7,
        0,
        0,
      );
      if (reminderTime.isAfter(now)) {
        await _localNotifications.zonedSchedule(
          lich.lichtuanId,
          'Nhắc lịch ngày mai',
          '${lich.gio} - ${lich.noiDung} tại ${lich.diaDiem}',
          reminderTime,
          NotificationDetails(
            android: AndroidNotificationDetails(
              AppConstants.notificationChannelId,
              AppConstants.notificationChannelName,
              channelDescription: AppConstants.notificationChannelDesc,
              importance: Importance.high,
              priority: Priority.high,
              styleInformation: BigTextStyleInformation(
                '${lich.gio} - ${lich.noiDung} tại ${lich.diaDiem}',
              ),
            ),
            iOS: const DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: jsonEncode({
            'loai': NotificationTypes.lichTuan,
            'id': lich.lichtuanId.toString(),
          }),
        );
      }
    }
  }

  static Future<void> _createAndroidChannel() async {
    const channel = AndroidNotificationChannel(
      AppConstants.notificationChannelId,
      AppConstants.notificationChannelName,
      description: AppConstants.notificationChannelDesc,
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static Future<String?> getFcmToken() =>
      FirebaseMessaging.instance.getToken();

  static Stream<String> get onTokenRefresh =>
      FirebaseMessaging.instance.onTokenRefresh;

  /// Hiển thị local notification với title/body tùy chỉnh (không từ RemoteMessage).
  /// Dùng cho background task kiểm tra thông báo chưa đọc.
  static Future<void> showSimpleNotification({
    required String title,
    required String body,
    int id = 9002,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'quan_ly_gas_channel',
      'Quản lý Gas',
      channelDescription: 'Kênh thông báo chính',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    await _localNotifications.show(
      id,
      title,
      body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }
}
