// lib/core/router/app_routes.dart
class AppRoutes {
  static const String login          = '/login';
  static const String home           = '/';
  static const String chuyenXeList   = '/chuyen-xe';
  static const String loTrinh        = '/lo-trinh';
  static const String loTrinhGhi     = '/lo-trinh/ghi';
  static String loTrinhDetail(int id) => '/lo-trinh/$id';
  static const String thongBaoList   = '/thong-bao';
  static const String lichTuan       = '/lich-tuan';
  static const String chamCong       = '/cham-cong';
  static const String nhanVienList   = '/nhan-vien';
  static const String xeList         = '/xe';
  static const String matHangList    = '/mat-hang';
  static const String nhaCungCapList = '/nha-cung-cap';
  static const String ghiChuList = '/ghi-chu';
  static const String ghiChuForm = '/ghi-chu/form';
  static const String ghiChuPhanLoai = '/ghi-chu/phan-loai'; // mở từ chip ở màn ghi chú (root navigator, chọn để lọc)
  static const String loaiGhiChu = '/loai-ghi-chu';          // chức năng riêng từ menu (ShellRoute, thêm/sửa/xoá)
  static const String thanSoHoc = '/than-so-hoc';

  static String chuyenXeDetail(String id)   => '/chuyen-xe/$id';
  static String thongBaoDetail(String id)   => '/thong-bao/$id';
  static String nhanVienDetail(int id)      => '/nhan-vien/$id';
  static String xeDetail(int id)            => '/xe/$id';
  static String matHangDetail(int id)       => '/mat-hang/$id';
  static String nhaCungCapDetail(int id)    => '/nha-cung-cap/$id';

  static const String khachHangList        = '/khach-hang';
  static String khachHangDetail(int id)    => '/khach-hang/$id';

  /// Chi tiết khách hàng kèm ngày mua cuối (dùng từ danh sách "lâu chưa mua").
  /// Truyền ngayMua qua query param để màn chi tiết hiển thị "Mua cuối".
  static String khachHangChiTietChuaMua(int id, DateTime? ngayMua) => ngayMua != null
      ? '/khach-hang/$id?ngayMua=${Uri.encodeComponent(ngayMua.toIso8601String())}'
      : '/khach-hang/$id';

  static const String tongQuan             = '/tong-quan';
  static String thongKeChuyenXe({DateTime? tuNgay, DateTime? denNgay}) {
    final q = <String, String>{};
    if (tuNgay  != null) q['tuNgay']  = tuNgay.toIso8601String().substring(0, 10);
    if (denNgay != null) q['denNgay'] = denNgay.toIso8601String().substring(0, 10);
    final qs = q.isEmpty ? '' : '?${q.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    return '/tong-quan/chuyen-xe$qs';
  }

  static const String daiLyChuaMua        = '/dai-ly-chua-mua';
  static String daiLyChiTiet(
    String id, {
    DateTime? tuNgay,
    DateTime? denNgay,
  }) {
    final q = <String, String>{};
    if (tuNgay != null) q['tuNgay'] = tuNgay.toIso8601String().substring(0, 10);
    if (denNgay != null) q['denNgay'] = denNgay.toIso8601String().substring(0, 10);
    final qs = q.isEmpty ? '' : '?${q.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    return '/dai-ly-chi-tiet/$id$qs';
  }

  static const String caiDat             = '/cai-dat';
  static const String thongTinTaiKhoan   = '/thong-tin-tai-khoan';
  static const String doiMatKhau         = '/doi-mat-khau';

  // Mobile driver — nhập bán hàng
  static const String batDauChuyen       = '/bat-dau-chuyen';
  static const String banHangTheoNgay    = '/ban-hang/theo-ngay';
  static String nhapBanHang(int chuyenXeId) => '/ban-hang/$chuyenXeId/nhap';
  static String suaBanHangKhachHang(int chuyenXeId, int khachHangId) => '/ban-hang/$chuyenXeId/khach-hang/$khachHangId/sua';
  static const String taoKhachHang       = '/khach-hang/tao-moi';
  static const String timKiemKhachHang   = '/tim-kiem-khach-hang';
  static const String timKiemPhuXe       = '/tim-kiem-phu-xe';
  static const String timKiemMatHang     = '/tim-kiem-mat-hang';
  static const String timKiemNhaCungCap  = '/tim-kiem-nha-cung-cap';
  static const String chonNoCu           = '/chon-no-cu';
  static const String dongBo             = '/cai-dat/dong-bo';

  // Kế toán — kiểm kê xuất hàng (Luồng B: phiếu độc lập → chọn chuyến → đối chiếu)
  static const String kiemKeList         = '/kiem-ke';
  static const String kiemKeDocLapNhap   = '/kiem-ke/nhap';
  static String kiemKeDocLapSua(int kiemKeId) => '/kiem-ke/$kiemKeId/sua';
  static String kiemKeNhapSoMangVe(int kiemKeId) => '/kiem-ke/$kiemKeId/nhap-so-mang-ve';
  static String kiemKeChonChuyen(int kiemKeId) => '/kiem-ke/$kiemKeId/chon-chuyen';
  static String kiemKeDoiChieu(int chuyenXeId) => '/kiem-ke/$chuyenXeId/doi-chieu';

  // Luồng A cũ (kiểm kê gắn sẵn theo chuyến) — không còn lối vào từ menu, giữ lại nội bộ.
  static const String kiemKeTaoChuyen    = '/kiem-ke/tao-moi';
  static String kiemKeNhap(int chuyenXeId) => '/kiem-ke/$chuyenXeId/nhap-cu';
}
