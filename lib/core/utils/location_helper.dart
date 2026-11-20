// lib/core/utils/location_helper.dart
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

/// Lỗi lấy vị trí có message tiếng Việt để hiển thị thẳng cho người dùng.
/// [moCaiDat] = true khi người dùng cần vào Cài đặt (tắt GPS / từ chối quyền vĩnh viễn).
class LocationException implements Exception {
  final String message;
  final bool moCaiDat;
  const LocationException(this.message, {this.moCaiDat = false});

  @override
  String toString() => message;
}

/// Tiện ích dùng chung: lấy tọa độ GPS hiện tại và mở Google Maps chỉ đường.
class LocationHelper {
  LocationHelper._();

  /// Lấy vị trí hiện tại: kiểm tra GPS bật → xin quyền → đọc tọa độ (độ chính xác cao, timeout 15s).
  /// Ném [LocationException] với thông báo rõ ràng khi không lấy được.
  static Future<Position> layViTriHienTai() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException('Định vị (GPS) đang tắt, vui lòng bật để lấy tọa độ', moCaiDat: true);
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw const LocationException('Chưa cấp quyền truy cập vị trí');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException('Quyền vị trí đã bị từ chối, vui lòng cấp lại trong Cài đặt', moCaiDat: true);
    }
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (_) {
      // Hết thời gian chờ fix GPS → dùng vị trí gần nhất đã biết nếu có
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;
      throw const LocationException('Không lấy được vị trí, vui lòng thử lại ở nơi thoáng');
    }
  }

  /// Mở trang cài đặt phù hợp (GPS tắt → cài đặt vị trí; bị từ chối quyền → cài đặt app).
  static Future<void> moCaiDat() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }

  /// Mở Google Maps chỉ đường từ vị trí hiện tại tới ([lat], [lng]).
  /// URL universal: mở app Google Maps nếu đã cài, không thì mở trình duyệt. Trả false nếu không mở được.
  static Future<bool> moChiDuong(double lat, double lng) {
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
