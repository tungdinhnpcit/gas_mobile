// lib/features/lo_trinh/data/models/lo_trinh_model.dart
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_constants.dart';

class LoTrinhDiemModel {
  final double lat;
  final double lng;
  final double? doChinhXac;
  final double? tocDo;
  final DateTime thoiGian;

  const LoTrinhDiemModel({
    required this.lat,
    required this.lng,
    this.doChinhXac,
    this.tocDo,
    required this.thoiGian,
  });

  LatLng get latLng => LatLng(lat, lng);

  /// Parse điểm từ JSON server.
  factory LoTrinhDiemModel.fromJson(Map<String, dynamic> j) => LoTrinhDiemModel(
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        doChinhXac: (j['doChinhXac'] as num?)?.toDouble(),
        tocDo: (j['tocDo'] as num?)?.toDouble(),
        thoiGian: DateTime.parse(j['thoiGian'] as String).toLocal(),
      );

  /// Chuyển sang JSON gửi server (thời gian UTC).
  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        'doChinhXac': doChinhXac,
        'tocDo': tocDo,
        'thoiGian': thoiGian.toUtc().toIso8601String(),
      };
}

/// Ảnh chụp trong lộ trình (kèm vị trí GPS lúc chụp nếu có).
class AnhLoTrinhModel {
  final int id;
  final String url; // đường dẫn tương đối /uploads/lo-trinh/...
  final double? lat;
  final double? lng;
  final String? ghiChu;
  final DateTime chupLuc;

  const AnhLoTrinhModel({
    required this.id,
    required this.url,
    this.lat,
    this.lng,
    this.ghiChu,
    required this.chupLuc,
  });

  /// URL đầy đủ của ảnh (static files serve từ server root).
  String get fullUrl => '${AppConstants.staticBaseUrl}$url';

  /// Toạ độ lúc chụp (null nếu không lấy được vị trí).
  LatLng? get latLng => lat != null && lng != null ? LatLng(lat!, lng!) : null;

  /// Parse ảnh từ JSON server.
  factory AnhLoTrinhModel.fromJson(Map<String, dynamic> j) => AnhLoTrinhModel(
        id: j['id'] as int,
        url: j['url'] as String,
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        ghiChu: j['ghiChu'] as String?,
        chupLuc: DateTime.parse(j['chupLuc'] as String).toLocal(),
      );
}

class LoTrinhModel {
  final int id;
  final int userId; // tài khoản ghi lộ trình (chủ sở hữu)
  final int? nhanVienId; // null nếu tài khoản chưa liên kết nhân viên
  final String? tenNhanVien; // tên nhân viên, hoặc tên tài khoản nếu chưa liên kết
  final String? ten;
  final String? ghiChu;
  final DateTime batDauLuc;
  final DateTime? ketThucLuc;
  final String trangThai;
  final double tongQuangDuongM;
  final List<LoTrinhDiemModel> diem;
  final List<AnhLoTrinhModel> anh;

  const LoTrinhModel({
    required this.id,
    required this.userId,
    this.nhanVienId,
    this.tenNhanVien,
    this.ten,
    this.ghiChu,
    required this.batDauLuc,
    this.ketThucLuc,
    required this.trangThai,
    required this.tongQuangDuongM,
    this.diem = const [],
    this.anh = const [],
  });

  bool get dangGhi => trangThai == 'dang-ghi';

  /// Thời lượng lộ trình (đến hiện tại nếu đang ghi).
  Duration get thoiLuong => (ketThucLuc ?? DateTime.now()).difference(batDauLuc);

  /// Parse lộ trình từ JSON server.
  factory LoTrinhModel.fromJson(Map<String, dynamic> j) => LoTrinhModel(
        id: j['id'] as int,
        userId: (j['userId'] as int?) ?? 0,
        nhanVienId: j['nhanVienId'] as int?,
        tenNhanVien: j['tenNhanVien'] as String?,
        ten: j['ten'] as String?,
        ghiChu: j['ghiChu'] as String?,
        batDauLuc: DateTime.parse(j['batDauLuc'] as String).toLocal(),
        ketThucLuc: j['ketThucLuc'] == null ? null : DateTime.parse(j['ketThucLuc'] as String).toLocal(),
        trangThai: j['trangThai'] as String? ?? 'dang-ghi',
        tongQuangDuongM: (j['tongQuangDuongM'] as num?)?.toDouble() ?? 0,
        diem: (j['diem'] as List? ?? [])
            .map((e) => LoTrinhDiemModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        anh: (j['anh'] as List? ?? [])
            .map((e) => AnhLoTrinhModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Định dạng quãng đường: < 1km hiển thị mét, còn lại km 1 chữ số thập phân.
String fmtQuangDuong(double m) =>
    m < 1000 ? '${m.round()} m' : '${(m / 1000).toStringAsFixed(1)} km';

/// Định dạng thời lượng dạng "1 giờ 05 phút".
String fmtThoiLuong(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h giờ $m phút' : '${d.inMinutes} phút';
}
