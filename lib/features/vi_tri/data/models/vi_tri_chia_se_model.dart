// lib/features/vi_tri/data/models/vi_tri_chia_se_model.dart
import 'package:latlong2/latlong.dart';

/// Vị trí mới nhất của một điện thoại đang chia sẻ vị trí.
class ViTriChiaSeModel {
  final int id;
  final int userId;
  final String username;
  final String? hoTen;
  final String? avatarUrl;
  final String? deviceInfo;
  final double lat;
  final double lng;
  final double? doChinhXac;
  final double? tocDo;
  final int? pin;
  final DateTime thoiGianCapNhat; // giờ địa phương
  final bool dangChiaSe;

  const ViTriChiaSeModel({
    required this.id,
    required this.userId,
    required this.username,
    this.hoTen,
    this.avatarUrl,
    this.deviceInfo,
    required this.lat,
    required this.lng,
    this.doChinhXac,
    this.tocDo,
    this.pin,
    required this.thoiGianCapNhat,
    required this.dangChiaSe,
  });

  /// Parse JSON từ API /api/vi-tri.
  factory ViTriChiaSeModel.fromJson(Map<String, dynamic> j) => ViTriChiaSeModel(
        id: j['id'] as int,
        userId: j['userId'] as int,
        username: j['username'] as String? ?? '',
        hoTen: j['hoTen'] as String?,
        avatarUrl: j['avatarUrl'] as String?,
        deviceInfo: j['deviceInfo'] as String?,
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        doChinhXac: (j['doChinhXac'] as num?)?.toDouble(),
        tocDo: (j['tocDo'] as num?)?.toDouble(),
        pin: j['pin'] as int?,
        thoiGianCapNhat: DateTime.parse(j['thoiGianCapNhat'] as String).toLocal(),
        dangChiaSe: j['dangChiaSe'] as bool? ?? true,
      );

  LatLng get latLng => LatLng(lat, lng);

  String get tenHienThi => (hoTen?.isNotEmpty == true) ? hoTen! : username;

  /// Quá 10 phút chưa cập nhật → coi như mất tín hiệu (máy tắt GPS / mất mạng / bị kill).
  bool get isCu => DateTime.now().difference(thoiGianCapNhat).inMinutes > 10;

  /// Chuỗi "x phút trước" để hiển thị.
  String get capNhatLuc {
    final d = DateTime.now().difference(thoiGianCapNhat);
    if (d.inMinutes < 1) return 'vừa xong';
    if (d.inMinutes < 60) return '${d.inMinutes} phút trước';
    if (d.inHours < 24) return '${d.inHours} giờ trước';
    return '${d.inDays} ngày trước';
  }
}
