// lib/features/ghi_chu/data/models/ghi_chu_model.dart

/// Ảnh đính kèm ghi chú — [url] là đường dẫn tương đối '/uploads/ghi-chu/...'.
class GhiChuAnhModel {
  final int id;
  final String url;
  final DateTime? uploadedAt;

  const GhiChuAnhModel({required this.id, required this.url, this.uploadedAt});

  factory GhiChuAnhModel.fromJson(Map<String, dynamic> json) => GhiChuAnhModel(
        id: json['id'] as int,
        url: (json['url'] as String?) ?? '',
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
      );

  /// Tạo bản sao; [clearPhanLoai] = true để gỡ phân loại (copyWith không phân biệt null với "không đổi").
  GhiChuModel copyWith({
    int? id,
    String? tieuDe,
    String? taiKhoan,
    String? matKhau,
    String? ghiChu,
    int? phanLoaiId,
    bool clearPhanLoai = false,
    List<GhiChuAnhModel>? anh,
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
