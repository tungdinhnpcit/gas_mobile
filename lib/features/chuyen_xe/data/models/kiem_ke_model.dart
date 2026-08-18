// lib/features/chuyen_xe/data/models/kiem_ke_model.dart

// ---------- Kiểm kê chuyến xe: chi tiết theo Nhà cung cấp + Mặt hàng ----------

class KiemKeChiTietModel {
  final int id;
  final int? nhaCungCapId;
  final String? maNhaCungCap;
  final String? tenNhaCungCap;
  final int matHangId;
  final String? maMatHang;
  final String? tenMatHang;
  final int soBinhXuat;
  final int soVoXuat;
  final int? soBinhConLai;
  final int? soVoMangVe;
  final int soKgGasDu;

  const KiemKeChiTietModel({
    required this.id,
    this.nhaCungCapId,
    this.maNhaCungCap,
    this.tenNhaCungCap,
    required this.matHangId,
    this.maMatHang,
    this.tenMatHang,
    required this.soBinhXuat,
    required this.soVoXuat,
    this.soBinhConLai,
    this.soVoMangVe,
    this.soKgGasDu = 0,
  });

  factory KiemKeChiTietModel.fromJson(Map<String, dynamic> json) => KiemKeChiTietModel(
        id:            json['id'] as int? ?? 0,
        nhaCungCapId:  json['nhaCungCapId'] as int?,
        maNhaCungCap:  json['maNhaCungCap'] as String?,
        tenNhaCungCap: json['tenNhaCungCap'] as String?,
        matHangId:     json['matHangId'] as int,
        maMatHang:     json['maMatHang'] as String?,
        tenMatHang:    json['tenMatHang'] as String?,
        soBinhXuat:    json['soBinhXuat'] as int? ?? 0,
        soVoXuat:      json['soVoXuat'] as int? ?? 0,
        soBinhConLai:  json['soBinhConLai'] as int?,
        soVoMangVe:    json['soVoMangVe'] as int?,
        soKgGasDu:     json['soKgGasDu'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'nhaCungCapId': nhaCungCapId,
        'matHangId':    matHangId,
        'soBinhXuat':   soBinhXuat,
        'soVoXuat':     soVoXuat,
      };

  /// Nhãn "MA - Tên".
  String get matHangLabel =>
      [maMatHang, tenMatHang].where((s) => s != null && s.isNotEmpty).join(' - ');
  String get nhaCungCapLabel =>
      [maNhaCungCap, tenNhaCungCap].where((s) => s != null && s.isNotEmpty).join(' - ');
}

// ---------- Kiểm kê chuyến xe: tổng hợp ----------

class KiemKeChuyenXeModel {
  final int id;
  final int? chuyenXeId;
  final String? maChuyenXe;
  // Xe chuẩn bị hàng lúc lập phiếu xuất kho — tham khảo, hiển thị khi phiếu chưa gắn chuyến.
  final int? xeId;
  final String? bienSoXe;
  final DateTime? ngayLap;
  final String? nguoiLap;
  final String? ghiChu;
  final DateTime? chotAt;
  final String? nguoiChot;
  final bool daGanChuyen;
  final bool daChot;
  final List<KiemKeChiTietModel> chiTiet;

  const KiemKeChuyenXeModel({
    required this.id,
    this.chuyenXeId,
    this.maChuyenXe,
    this.xeId,
    this.bienSoXe,
    this.ngayLap,
    this.nguoiLap,
    this.ghiChu,
    this.chotAt,
    this.nguoiChot,
    this.daGanChuyen = false,
    this.daChot = false,
    required this.chiTiet,
  });

  factory KiemKeChuyenXeModel.fromJson(Map<String, dynamic> json) => KiemKeChuyenXeModel(
        id:         json['id'] as int? ?? 0,
        chuyenXeId: json['chuyenXeId'] as int?,
        maChuyenXe: json['maChuyenXe'] as String?,
        xeId:       json['xeId'] as int?,
        bienSoXe:   json['bienSoXe'] as String?,
        ngayLap:    json['ngayLap'] != null
            ? DateTime.tryParse(json['ngayLap'] as String)
            : null,
        nguoiLap: json['nguoiLap'] as String?,
        ghiChu:   json['ghiChu'] as String?,
        chotAt:   json['chotAt'] != null
            ? DateTime.tryParse(json['chotAt'] as String)
            : null,
        nguoiChot:   json['nguoiChot'] as String?,
        daGanChuyen: json['daGanChuyen'] as bool? ?? (json['chuyenXeId'] != null),
        daChot:      json['daChot'] as bool? ?? (json['chotAt'] != null),
        chiTiet: (json['chiTiet'] as List? ?? [])
            .map((e) => KiemKeChiTietModel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
