// lib/features/thu_vien_anh/data/thu_vien_anh_model.dart

/// 1 ảnh trong thư viện ảnh tổng hợp (key = "{loai}:{id}").
class AnhItemModel {
  final String key;
  final String loai;
  final String url;
  final DateTime ngay;
  final String tieuDe;
  final String? moTa;
  final int? chuyenXeId;

  const AnhItemModel({
    required this.key,
    required this.loai,
    required this.url,
    required this.ngay,
    required this.tieuDe,
    this.moTa,
    this.chuyenXeId,
  });

  /// Parse JSON từ API; ngày backend trả UTC không có 'Z' → ép UTC rồi đổi giờ máy
  factory AnhItemModel.fromJson(Map<String, dynamic> j) {
    final raw = j['ngay'] as String;
    final hasTz = raw.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(raw);
    return AnhItemModel(
      key: j['key'] as String,
      loai: j['loai'] as String,
      url: j['url'] as String,
      ngay: DateTime.parse(hasTz ? raw : '${raw}Z').toLocal(),
      tieuDe: j['tieuDe'] as String? ?? '',
      moTa: j['moTa'] as String?,
      chuyenXeId: j['chuyenXeId'] as int?,
    );
  }

  /// Nhãn hiển thị theo loại ảnh
  String get loaiLabel => switch (loai) {
        'giao-hang' => 'Giao hàng',
        'xac-nhan-anh' => 'Biên lai',
        'xac-nhan-ky' => 'Chữ ký',
        'ban-ke' => 'Bản kê',
        'lo-trinh' => 'Lộ trình',
        'ghi-chu' => 'Ghi chú',
        _ => loai,
      };
}

/// Kết quả 1 trang danh sách ảnh.
class ThuVienAnhPage {
  final List<AnhItemModel> items;
  final int totalCount;
  final bool isQuanTri;
  const ThuVienAnhPage(this.items, this.totalCount, this.isQuanTri);
}
