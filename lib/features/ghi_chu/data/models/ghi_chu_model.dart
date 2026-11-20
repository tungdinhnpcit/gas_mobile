// lib/features/ghi_chu/data/models/ghi_chu_model.dart
import '../../../../core/constants/app_constants.dart';

/// Ảnh đính kèm ghi chú — [url] là đường dẫn tương đối '/uploads/ghi-chu/...'.
class GhiChuAnhModel {
  final int id;
  final String url;
  final DateTime? uploadedAt;
  final String? thumbUrl; // ảnh thu nhỏ server sinh khi upload; null = ảnh cũ chưa có thumb

  const GhiChuAnhModel({required this.id, required this.url, this.uploadedAt, this.thumbUrl});

  /// URL đầy đủ của ảnh (static files serve từ server root).
  String get fullUrl => '${AppConstants.staticBaseUrl}$url';

  /// URL ảnh thu nhỏ để hiển thị trong danh sách/lưới; chưa có thumb thì dùng ảnh gốc.
  String get thumbFullUrl => '${AppConstants.staticBaseUrl}${thumbUrl ?? url}';

  factory GhiChuAnhModel.fromJson(Map<String, dynamic> json) => GhiChuAnhModel(
        id: json['id'] as int,
        url: (json['url'] as String?) ?? '',
        thumbUrl: json['thumbUrl'] as String?,
        uploadedAt: json['uploadedAt'] != null ? DateTime.tryParse(json['uploadedAt'] as String) : null,
      );
}

/// Ghi chú bảo mật cá nhân — mật khẩu được backend mã hoá khi lưu, giải mã khi trả về API.
class GhiChuModel {
  final int? id;          // null khi tạo mới
  final String tieuDe;
  final String taiKhoan;
  final String matKhau;   // plaintext trong bộ nhớ (BE đã giải mã trước khi trả về)
  final String ghiChu;
  final int? phanLoaiId;
  final String? tenPhanLoai;
  final String? mauPhanLoai;
  final List<GhiChuAnhModel> anh;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool laChuSoHuu;      // false = ghi chú được người khác chia sẻ (chỉ xem)
  final String? tenChuSoHuu;
  final double? viDo;         // vĩ độ — null = chưa gắn vị trí
  final double? kinhDo;       // kinh độ

  /// Có đủ tọa độ để hiển thị/chỉ đường.
  bool get coToaDo => viDo != null && kinhDo != null;

  const GhiChuModel({
    this.laChuSoHuu = true,
    this.tenChuSoHuu,
    this.id,
    required this.tieuDe,
    this.taiKhoan = '',
    this.matKhau = '',
    this.ghiChu = '',
    this.phanLoaiId,
    this.tenPhanLoai,
    this.mauPhanLoai,
    this.anh = const [],
    this.createdAt,
    this.updatedAt,
    this.viDo,
    this.kinhDo,
  });

  factory GhiChuModel.fromJson(Map<String, dynamic> json) => GhiChuModel(
        id: json['id'] as int?,
        tieuDe: (json['tieuDe'] as String?) ?? '',
        taiKhoan: (json['taiKhoan'] as String?) ?? '',
        matKhau: (json['matKhau'] as String?) ?? '',
        ghiChu: (json['ghiChu'] as String?) ?? '',
        phanLoaiId: json['phanLoaiId'] as int?,
        tenPhanLoai: json['tenPhanLoai'] as String?,
        mauPhanLoai: json['mauPhanLoai'] as String?,
        anh: ((json['anh'] as List?) ?? const [])
            .map((e) => GhiChuAnhModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) : null,
        updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'] as String) : null,
        laChuSoHuu: (json['laChuSoHuu'] as bool?) ?? true,
        tenChuSoHuu: json['tenChuSoHuu'] as String?,
        viDo: (json['viDo'] as num?)?.toDouble(),
        kinhDo: (json['kinhDo'] as num?)?.toDouble(),
      );

  /// Tạo bản sao; [clearPhanLoai] = true để gỡ phân loại, [clearToaDo] = true để gỡ tọa độ (copyWith không phân biệt null với "không đổi").
  GhiChuModel copyWith({
    int? id,
    String? tieuDe,
    String? taiKhoan,
    String? matKhau,
    String? ghiChu,
    int? phanLoaiId,
    bool clearPhanLoai = false,
    List<GhiChuAnhModel>? anh,
    double? viDo,
    double? kinhDo,
    bool clearToaDo = false,
  }) =>
      GhiChuModel(
        id: id ?? this.id,
        tieuDe: tieuDe ?? this.tieuDe,
        taiKhoan: taiKhoan ?? this.taiKhoan,
        matKhau: matKhau ?? this.matKhau,
        ghiChu: ghiChu ?? this.ghiChu,
        phanLoaiId: clearPhanLoai ? null : (phanLoaiId ?? this.phanLoaiId),
        tenPhanLoai: clearPhanLoai ? null : tenPhanLoai,
        mauPhanLoai: clearPhanLoai ? null : mauPhanLoai,
        anh: anh ?? this.anh,
        createdAt: createdAt,
        updatedAt: updatedAt,
        laChuSoHuu: laChuSoHuu,
        tenChuSoHuu: tenChuSoHuu,
        viDo: clearToaDo ? null : (viDo ?? this.viDo),
        kinhDo: clearToaDo ? null : (kinhDo ?? this.kinhDo),
      );
}

/// Tài khoản có thể nhận chia sẻ (dùng cho autocomplete) hoặc đã được chia sẻ ([createdAt] != null).
class GhiChuNguoiDungModel {
  final int userId;
  final String username;
  final String? fullName;
  final DateTime? createdAt;

  const GhiChuNguoiDungModel({required this.userId, required this.username, this.fullName, this.createdAt});

  /// Tên hiển thị: "Họ tên (username)" hoặc username nếu không có họ tên.
  String get hienThi =>
      (fullName == null || fullName!.trim().isEmpty) ? username : '$fullName ($username)';

  factory GhiChuNguoiDungModel.fromJson(Map<String, dynamic> json) => GhiChuNguoiDungModel(
        userId: json['userId'] as int,
        username: (json['username'] as String?) ?? '',
        fullName: json['fullName'] as String?,
        createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) : null,
      );
}
