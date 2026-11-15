// lib/features/vi_tri/services/chia_se_vi_tri_service.dart
import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/storage_keys.dart';
import '../../../core/network/hmac_interceptor.dart';
import '../../auth/data/biometric_service.dart';
import '../data/repositories/vi_tri_repository.dart';

/// Tên task Workmanager dự phòng (cập nhật vị trí 15 phút/lần khi app bị kill).
const viTriTaskName = 'capNhatViTri';
const viTriTaskKey = 'vi_tri_chia_se';
const _prefKeyBat = 'chia_se_vi_tri';

/// Chia sẻ vị trí nền: stream vị trí của geolocator chạy kèm foreground service Android
/// (thông báo cố định) nên vẫn chạy khi tắt màn hình; gửi vị trí mới nhất lên server mỗi 2 phút.
/// Khi đang ghi lộ trình, geolocator chỉ giữ được 1 stream → service nhường stream và
/// nhận vị trí từ lộ trình qua [nhanViTri].
class ChiaSeViTriService {
  ChiaSeViTriService._();
  static final instance = ChiaSeViTriService._();

  static const chuKy = Duration(minutes: 2);
  static const _guiToiThieu = Duration(seconds: 110); // tránh gửi dồn khi stream + timer cùng kích

  final _repo = ViTriRepository();

  /// Trạng thái bật/tắt để UI Cài đặt lắng nghe.
  final dangBat = ValueNotifier<bool>(false);

  /// Thời điểm gửi vị trí thành công gần nhất.
  final lanGuiCuoi = ValueNotifier<DateTime?>(null);

  StreamSubscription<Position>? _sub;
  Timer? _timer;
  Position? _viTriMoi;
  DateTime? _guiLuc;
  bool _dangGui = false;
  bool _nhuongStream = false; // true = lộ trình đang giữ stream geolocator
  String? _deviceId;
  String? _deviceInfo;

  /// Đọc cờ đã lưu và chạy lại nếu đang bật — gọi sau khi đăng nhập / mở app.
  Future<void> khoiPhuc() async {
    if (dangBat.value) return;
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_prefKeyBat) ?? false)) return;
    final p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied || p == LocationPermission.deniedForever) return;
    await _khoiDong();
  }

  /// Bật chia sẻ vị trí; trả thông báo lỗi (null = OK).
  Future<String?> batDau() async {
    if (!await Geolocator.isLocationServiceEnabled()) return 'Vui lòng bật GPS (định vị) trên điện thoại';
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.denied) return 'Bạn chưa cấp quyền vị trí';
    if (p == LocationPermission.deniedForever) {
      return 'Quyền vị trí đã bị chặn, vui lòng mở Cài đặt ứng dụng để cấp lại';
    }
    if (p == LocationPermission.whileInUse) {
      // Hỏi nâng lên "Luôn cho phép" để task nền lấy được vị trí khi app bị kill
      await Geolocator.requestPermission();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyBat, true);
    await _khoiDong();
    return null;
  }

  /// Tắt chia sẻ: dừng stream, huỷ task nền, báo server (lỗi mạng bỏ qua).
  Future<void> dung({bool baoServer = true}) async {
    final prefs = await SharedPreferences.getInstance();
    final dangBatTruoc = prefs.getBool(_prefKeyBat) ?? false;
    await prefs.setBool(_prefKeyBat, false);
    await _dungStream();
    _timer?.cancel();
    _timer = null;
    dangBat.value = false;
    try {
      await Workmanager().cancelByUniqueName(viTriTaskKey);
    } catch (_) {}
    if (baoServer && dangBatTruoc) {
      try {
        await _repo.tat(await _layDeviceId());
      } catch (e) {
        debugPrint('[VI_TRI] báo tắt lỗi: $e');
      }
    }
  }

  /// Lộ trình bắt đầu ghi → nhường stream geolocator cho lộ trình.
  Future<void> nhuongStream() async {
    _nhuongStream = true;
    await _dungStream();
  }

  /// Lộ trình kết thúc → mở lại stream riêng nếu đang chia sẻ.
  Future<void> layLaiStream() async {
    _nhuongStream = false;
    if (dangBat.value) await _batDauStream();
  }

  /// Nhận vị trí từ stream của lộ trình khi đang nhường stream.
  void nhanViTri(Position p) {
    if (!dangBat.value) return;
    _viTriMoi = p;
    _thuGui();
  }

  /// Bật timer gửi định kỳ, stream vị trí, task nền dự phòng và gửi ngay 1 lần.
  Future<void> _khoiDong() async {
    dangBat.value = true;
    _timer?.cancel();
    _timer = Timer.periodic(chuKy, (_) => _thuGui(batBuoc: true));
    if (!_nhuongStream) await _batDauStream();
    try {
      await Workmanager().registerPeriodicTask(
        viTriTaskKey,
        viTriTaskName,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    } catch (e) {
      debugPrint('[VI_TRI] đăng ký task nền lỗi: $e');
    }
    // Gửi ngay 1 lần để người xem thấy máy xuất hiện liền
    try {
      _viTriMoi = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      await _thuGui(batBuoc: true);
    } catch (e) {
      debugPrint('[VI_TRI] lấy vị trí đầu lỗi: $e');
    }
  }

  Future<void> _batDauStream() async {
    await _dungStream();
    final LocationSettings settings;
    if (defaultTargetPlatform == TargetPlatform.android) {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        intervalDuration: chuKy,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Đang chia sẻ vị trí',
          notificationText: 'Vị trí của bạn được cập nhật định kỳ cho công ty',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      settings = AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50,
        allowBackgroundLocationUpdates: true,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
      );
    } else {
      settings = const LocationSettings(accuracy: LocationAccuracy.high);
    }
    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
      (p) {
        _viTriMoi = p;
        _thuGui();
      },
      onError: (e) => debugPrint('[VI_TRI] stream lỗi: $e'),
    );
  }

  Future<void> _dungStream() async {
    await _sub?.cancel();
    _sub = null;
  }

  /// Gửi vị trí mới nhất nếu đã đủ chu kỳ (timer gọi với [batBuoc]). Lỗi mạng → lần sau gửi lại.
  Future<void> _thuGui({bool batBuoc = false}) async {
    final p = _viTriMoi;
    if (p == null || _dangGui || !dangBat.value) return;
    final now = DateTime.now();
    final khoangCach = batBuoc ? const Duration(seconds: 60) : _guiToiThieu;
    if (_guiLuc != null && now.difference(_guiLuc!) < khoangCach) return;
    _dangGui = true;
    try {
      await _repo.capNhat(
        deviceId: await _layDeviceId(),
        deviceInfo: await _layDeviceInfo(),
        lat: p.latitude,
        lng: p.longitude,
        doChinhXac: p.accuracy,
        tocDo: p.speed >= 0 ? p.speed : null,
      );
      _guiLuc = now;
      lanGuiCuoi.value = now;
    } catch (e) {
      debugPrint('[VI_TRI] gửi vị trí lỗi: $e');
    } finally {
      _dangGui = false;
    }
  }

  Future<String> _layDeviceId() async => _deviceId ??= await BiometricService().getOrCreateDeviceId();

  Future<String?> _layDeviceInfo() async => _deviceInfo ??= await moTaThietBi();
}

/// Mô tả ngắn thiết bị, ví dụ "samsung SM-A515F".
Future<String?> moTaThietBi() async {
  try {
    final info = DeviceInfoPlugin();
    if (defaultTargetPlatform == TargetPlatform.android) {
      final a = await info.androidInfo;
      return '${a.manufacturer} ${a.model}';
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final i = await info.iosInfo;
      return '${i.name} ${i.model}';
    }
  } catch (_) {}
  return null;
}

/// Task Workmanager (isolate riêng, app có thể đã bị kill): lấy vị trí hiện tại và gửi lên server.
/// Không dùng ApiClient (singleton của isolate chính) — tự tạo Dio kèm HMAC.
Future<void> capNhatViTriNen() async {
  final prefs = await SharedPreferences.getInstance();
  if (!(prefs.getBool(_prefKeyBat) ?? false)) return;
  const storage = FlutterSecureStorage();
  final token = await storage.read(key: 'jwt_token');
  final deviceId = await storage.read(key: StorageKeys.deviceId);
  if (token == null || token.isEmpty || deviceId == null) return;

  final p = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 30),
    ),
  );
  final dio = Dio(BaseOptions(
    baseUrl: AppConstants.resolvedApiUrl,
    connectTimeout: const Duration(seconds: 10),
    headers: {'Authorization': 'Bearer $token'},
  ))
    ..interceptors.add(HmacInterceptor());
  await dio.post('/api/vi-tri/cap-nhat', data: {
    'deviceId': deviceId,
    'deviceInfo': await moTaThietBi(),
    'lat': p.latitude,
    'lng': p.longitude,
    'doChinhXac': p.accuracy,
    'tocDo': p.speed >= 0 ? p.speed : null,
  });
  debugPrint('[VI_TRI] task nền đã gửi vị trí');
}
