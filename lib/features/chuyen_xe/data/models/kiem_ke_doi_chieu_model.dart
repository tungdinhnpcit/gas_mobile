// lib/features/chuyen_xe/data/models/kiem_ke_doi_chieu_model.dart

// ---------- Đối chiếu số mang về: kế toán nhập vs lái xe (suy ra từ bán hàng) ----------

/// Một dòng đối chiếu theo mặt hàng + nhà cung cấp.
class KiemKeDoiChieuRow {
  final int? nhaCungCapId;
  final String? maNhaCungCap;
  final String? tenNhaCungCap;
  final int matHangId;
  final String? tenMatHang;
  final int soBinhXuat;
  final int? soBinhKeToan;
  final int soBinhLaiXe;
  final int chenhLechBinh;
  final int? soVoKeToan;
  final int soVoLaiXe;
  final int chenhLechVo;
  final bool coChenhLech;

  const KiemKeDoiChieuRow({
    this.nhaCungCapId,
    this.maNhaCungCap,
    this.tenNhaCungCap,
    required this.matHangId,
    this.tenMatHang,
    required this.soBinhXuat,
    this.soBinhKeToan,
    required this.soBinhLaiXe,
    required this.chenhLechBinh,
    this.soVoKeToan,
    required this.soVoLaiXe,
    required this.chenhLechVo,
    required this.coChenhLech,
  });

  factory KiemKeDoiChieuRow.fromJson(Map<String, dynamic> j) => KiemKeDoiChieuRow(
        nhaCungCapId:  j['nhaCungCapId'] as int?,
        maNhaCungCap:  j['maNhaCungCap'] as String?,
        tenNhaCungCap: j['tenNhaCungCap'] as String?,
        matHangId:     j['matHangId'] as int? ?? 0,
        tenMatHang:    j['tenMatHang'] as String?,
        soBinhXuat:    j['soBinhXuat'] as int? ?? 0,
        soBinhKeToan:  j['soBinhKeToan'] as int?,
        soBinhLaiXe:   j['soBinhLaiXe'] as int? ?? 0,
        chenhLechBinh: j['chenhLechBinh'] as int? ?? 0,
        soVoKeToan:    j['soVoKeToan'] as int?,
        soVoLaiXe:     j['soVoLaiXe'] as int? ?? 0,
        chenhLechVo:   j['chenhLechVo'] as int? ?? 0,
        coChenhLech:   j['coChenhLech'] as bool? ?? false,
      );

  /// Nhãn "MA - Tên".
  String get nhaCungCapLabel =>
      [maNhaCungCap, tenNhaCungCap].where((s) => s != null && s.isNotEmpty).join(' - ');
}

/// Tổng hợp số vỏ mang về theo từng nhà cung cấp (hãng).
class KiemKeDoiChieuVoNCC {
  final int? nhaCungCapId;
  final String? maNhaCungCap;
  final String? tenNhaCungCap;
  final int soVoKeToan;
  final int soVoLaiXe;
  final int chenhLech;

  const KiemKeDoiChieuVoNCC({
    this.nhaCungCapId,
    this.maNhaCungCap,
    this.tenNhaCungCap,
    required this.soVoKeToan,
    required this.soVoLaiXe,
    required this.chenhLech,
  });

  factory KiemKeDoiChieuVoNCC.fromJson(Map<String, dynamic> j) => KiemKeDoiChieuVoNCC(
        nhaCungCapId:  j['nhaCungCapId'] as int?,
        maNhaCungCap:  j['maNhaCungCap'] as String?,
        tenNhaCungCap: j['tenNhaCungCap'] as String?,
        soVoKeToan:    j['soVoKeToan'] as int? ?? 0,
        soVoLaiXe:     j['soVoLaiXe'] as int? ?? 0,
        chenhLech:     j['chenhLech'] as int? ?? 0,
      );

  /// Nhãn "MA - Tên".
  String get nhaCungCapLabel =>
      [maNhaCungCap, tenNhaCungCap].where((s) => s != null && s.isNotEmpty).join(' - ');
}

class KiemKeDoiChieuModel {
  final int chuyenXeId;
  final bool coChenhLech;
  final List<KiemKeDoiChieuRow> rows;
  final List<KiemKeDoiChieuVoNCC> voTheoNCC;

  const KiemKeDoiChieuModel({
    required this.chuyenXeId,
    required this.coChenhLech,
    required this.rows,
    required this.voTheoNCC,
  });

  factory KiemKeDoiChieuModel.fromJson(Map<String, dynamic> j) => KiemKeDoiChieuModel(
        chuyenXeId:  j['chuyenXeId'] as int? ?? 0,
        coChenhLech: j['coChenhLech'] as bool? ?? false,
        rows: (j['rows'] as List? ?? [])
            .map((e) => KiemKeDoiChieuRow.fromJson(e as Map<String, dynamic>))
            .toList(),
        voTheoNCC: (j['voTheoNCC'] as List? ?? [])
            .map((e) => KiemKeDoiChieuVoNCC.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
