// lib/core/services/background_polling_service.dart
// Service xử lý polling thông báo mỗi 15 phút cho điện thoại không có GMS (Vivo TQ, v.v.)
import 'dart:convert'; // Chuyển JSON string ↔ object
import 'dart:io'; // HttpClient, HttpHeaders

import 'package:flutter/foundation.dart'; // debugPrint
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // Hiển thị local notification
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // Đọc JWT token từ storage an toàn
import 'package:shared_preferences/shared_preferences.dart'; // Lưu baseline count so sánh
import 'package:workmanager/workmanager.dart'; // Periodic background task

import '../constants/app_constants.dart'; // Notification channel ID, API base URL
import '../../features/vi_tri/services/chia_se_vi_tri_service.dart' show viTriTaskName, capNhatViTriNen; // task chia sẻ vị trí nền
import '../../features/thong_bao/data/repositories/thong_bao_repository.dart'; // Gọi API so-chua-doc từ trong app (dùng ApiClient/Dio, khác isolate polling)

// Mã định danh task duy nhất — Workmanager dùng để track task
const _taskKey = 'notification_polling';
// Tên task mà callbackDispatcher sẽ handle
const _taskName = 'pollNewNotifications';
// Key trong SharedPreferences lưu số thông báo chưa đọc lần cuối biết
const _prefKeyLastCount = 'last_notification_count';

/// Top-level callback — bắt buộc ngoài class, có @pragma để tránh tree-shaking.
/// Workmanager gọi hàm này trong một Flutter engine riêng biệt (isolate khác).
/// @pragma('vm:entry-point') = giữ hàm này trong release build (không bị xóa khi minify)
@pragma('vm:entry-point')
void callbackDispatcher() {
  // Workmanager.executeTask: chạy async task mỗi khi trigger periodic job
  Workmanager().executeTask((task, inputData) async {
    try {
      // Task chia sẻ vị trí dự phòng (app bị kill) — tách khỏi polling thông báo
      if (task == viTriTaskName) {
        await capNhatViTriNen();
        return true;
      }
      // Gọi hàm polling chính — kiểm tra thông báo mới
      await _doPoll();
    } catch (e) {
      // Log lỗi nhưng không throw (tránh retry vô hạn)
      debugPrint('[Polling] Lỗi khi poll thông báo: $e');
    }
    // Trả true = task chạy thành công (không retry)
    // Trả false = retry lần sau theo backoffPolicy
    return Future.value(true);
  });
}

/// Hàm polling chính — gọi API backend để lấy số thông báo chưa đọc
/// So sánh với baseline cũ: nếu tăng → hiển thị local notification
Future<void> _doPoll() async {
  // Khởi tạo secure storage (không thể dùng Dio vì khác isolate)
  const storage = FlutterSecureStorage();

  // Đọc JWT token từ secure storage (được lưu lúc login)
  final token = await storage.read(key: 'jwt_token');

  // Đọc user ID từ secure storage (được lưu lúc login)
  final userIdStr = await storage.read(key: 'user_id');

  // Nếu không có token hoặc user ID → không có session → return (không poll)
  if (token == null || userIdStr == null || userIdStr.isEmpty) return;

  // Parse string user ID thành int
  final userId = int.tryParse(userIdStr);

  // Nếu parse thất bại hoặc user ID invalid → return
  if (userId == null || userId <= 0) return;

  // Khởi tạo HTTP client (không dùng Dio vì chạy trong isolate riêng)
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 10); // Timeout 10s

  try {
    // Build API URL: /api/thong-bao/so-chua-doc?userId=123
    final uri = Uri.parse(
      '${AppConstants.resolvedApiUrl}/api/thong-bao/so-chua-doc?userId=$userId',
    );

    // Tạo GET request
    final req = await client.getUrl(uri);

    // Thêm Authorization header (Bearer token)
    req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');

    // Thêm Content-Type header
    req.headers.set(HttpHeaders.contentTypeHeader, 'application/json');

    // Gửi request và nhận response
    final resp = await req.close();

    // Kiểm tra status code — nếu không phải 200 → return (không xử lý)
    if (resp.statusCode != 200) return;

    // Chuyển response stream → string (UTF-8 decoding)
    final body = await resp.transform(utf8.decoder).join();

    // Parse JSON string thành Map
    final data = jsonDecode(body) as Map<String, dynamic>;

    // Lấy số thông báo chưa đọc từ JSON response (default 0 nếu không có)
    final soChuaDoc = (data['soChuaDoc'] as num?)?.toInt() ?? 0;

    // Đọc SharedPreferences để lấy baseline (số thông báo lần poll cuối)
    final prefs = await SharedPreferences.getInstance();
    final lastCount = prefs.getInt(_prefKeyLastCount) ?? 0;

    // So sánh: nếu số thông báo tăng → có thông báo mới
    if (soChuaDoc > lastCount) {
      // Hiển thị local notification với số lượng thông báo mới (soChuaDoc - lastCount)
      await _showLocalNotification(soChuaDoc - lastCount);
    }

    // Cập nhật baseline trong SharedPreferences cho lần poll tiếp theo
    // Cách này tránh hiển thị notification lặp lại cho cùng thông báo
    await prefs.setInt(_prefKeyLastCount, soChuaDoc);

    // Log thông tin poll (debug)
    debugPrint('[Polling] soChuaDoc=$soChuaDoc, lastCount=$lastCount');
  } finally {
    // Đóng HTTP client dù có lỗi hay không
    client.close();
  }
}

/// Hiển thị local notification khi có thông báo mới từ polling
/// newCount = số thông báo mới tìm được trong poll này
Future<void> _showLocalNotification(int newCount) async {
  // Khởi tạo Flutter Local Notifications plugin
  final plugin = FlutterLocalNotificationsPlugin();

  // Cấu hình Android: chọn icon notification (từ drawable)
  const androidInit = AndroidInitializationSettings('@drawable/ic_notification');

  // Khởi tạo plugin với cấu hình Android (iOS không cần vì FCM tự xử)
  await plugin.initialize(const InitializationSettings(android: androidInit));

  // Hiển thị notification lên thanh thông báo hệ thống
  await plugin.show(
    9001, // Notification ID (unique ID để update/replace notification)
    'Thông báo mới', // Tiêu đề notification
    'Bạn có $newCount thông báo chưa đọc', // Nội dung notification
    const NotificationDetails(
      // Cấu hình Android notification
      android: AndroidNotificationDetails(
        AppConstants.notificationChannelId, // 'quan_ly_gas_channel' — phải khớp AndroidManifest.xml
        AppConstants.notificationChannelName, // 'QuanLyGas Thông Báo' — tên hiển thị trên cài đặt
        channelDescription: AppConstants.notificationChannelDesc, // Mô tả chi tiết
        importance: Importance.high, // Mức độ quan trọng cao (ẩn không được)
        priority: Priority.high, // Ưu tiên cao (hiển thị ngay lập tức)
      ),
    ),
  );
}

/// Service quản lý background polling notification
/// Dùng Workmanager để chạy task mỗi 15 phút (kể cả khi app bị kill)
class BackgroundPollingService {
  /// Khởi tạo Workmanager — gọi một lần duy nhất trong main() sau Firebase.initializeApp
  /// Tạo lập Flutter engine cho background task (isolate riêng)
  static Future<void> init() async {
    // Khởi tạo Workmanager với callback dispatcher
    await Workmanager().initialize(
      callbackDispatcher, // Function sẽ xử lý các periodic job
    );
  }

  /// Đăng ký periodic task mỗi 15 phút — gọi khi user login thành công
  /// Task sẽ chạy lặp lại mỗi 15 phút cho tới khi user logout
  static Future<void> registerPeriodicTask() async {
    await Workmanager().registerPeriodicTask(
      _taskKey, // 'notification_polling' — ID task duy nhất
      _taskName, // 'pollNewNotifications' — tên callback task
      frequency: const Duration(minutes: 15), // Chạy mỗi 15 phút
      constraints: Constraints(
        // Task chỉ chạy khi có kết nối mạng (không tiêu tốn data khi offline)
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      // replace = nếu task đã tồn tại → thay thế (không tạo duplicate)
      backoffPolicy: BackoffPolicy.linear,
      // linear = retry với backoff tuyến tính (5m, 10m, 15m, ...)
      backoffPolicyDelay: const Duration(minutes: 5),
      // Nếu task fail → retry sau 5 phút
    );
    debugPrint('[Polling] Đã đăng ký periodic task mỗi 15 phút');
  }

  /// Huỷ tất cả task và xoá baseline count — gọi khi user logout
  /// Tránh polling vô lý sau khi logout
  static Future<void> cancelAll() async {
    // Huỷ Workmanager task
    await Workmanager().cancelAll();

    // Xoá SharedPreferences baseline (số thông báo lần cuối)
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyLastCount);

    debugPrint('[Polling] Đã huỷ periodic task');
  }

  /// Cập nhật baseline count trong SharedPreferences — gọi từ trong app
  /// Dùng để sync với UI khi user đã đọc thông báo trên app
  /// Tránh polling hiển thị re-notification cho thông báo đã đọc
  static Future<void> updateLastKnownCount(int count) async {
    final prefs = await SharedPreferences.getInstance();
    // Lưu số lượng thông báo mới nhất đã biết
    // Polling lần tiếp theo sẽ so sánh với giá trị này
    await prefs.setInt(_prefKeyLastCount, count);
  }

  /// Đọc baseline count từ SharedPreferences — dùng khi kiểm tra thông báo chưa đọc
  static Future<int> getLastKnownCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefKeyLastCount) ?? 0;
  }

  /// Gọi API so-chua-doc, so với baseline đã lưu, nếu tăng thì hiển thị local notification banner
  /// và cập nhật baseline mới. Dùng chung cho post-login (_runPostLoginTasks) và mỗi khi vào Home.
  static Future<void> checkAndNotifyIfIncreased(int userId) async {
    final newCount = await ThongBaoRepository().getSoChuaDoc(userId);
    final lastCount = await getLastKnownCount();
    if (newCount > lastCount) {
      await _showLocalNotification(newCount - lastCount);
    }
    await updateLastKnownCount(newCount);
  }
}
