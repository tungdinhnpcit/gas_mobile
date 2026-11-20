// lib/features/lich_tuan/data/models/lich_tuan_model.dart
import '../../domain/entities/lich_tuan_entity.dart';

/// Model JSON lịch tuần — map trực tiếp sang entity.
class LichTuanModel {
  LichTuanModel._(this.entity);

  final LichTuanEntity entity;

  static String _s(dynamic v) => (v as String?)?.trim() ?? '';

  /// Parse lịch lãnh đạo / ban / khác / cá nhân (có NgayGioBD_Base, NgayGioKT_Base)
  factory LichTuanModel.fromJson(Map<String, dynamic> json) {
    final bd = DateTime.parse(json['NgayGioBD_Base'] as String);
    final ktRaw = json['NgayGioKT_Base'] as String?;
    return LichTuanModel._(LichTuanEntity(
      lichtuanId: json['Lichtuan_ID'] as int,
      ngayGioBD: _s(json['NgayGioBD']),
      gio: _s(json['gio']),
      thoiGian: _s(json['ThoiGian']),
      diaDiem: _s(json['DiaDiem']),
      chuTri: _s(json['ChuTri']),
      noiDung: _s(json['NoiDung']),
      ngayGioBDBase: bd,
      ngayGioKTBase: ktRaw == null ? bd : DateTime.parse(ktRaw),
      thamGiaChitiet: _s(json['ThamGiaChitiet']),
      thayDoi: _s(json['ThayDoi']),
      isTruyenHinh: json['isTruyenHinh'] as bool? ?? false,
      tt: _s(json['TT']),
      dvChuanBi: _cleanChuoi(json['DvChuanBiChuoi']),
      thanhPhanThamGia: _cleanChuoi(json['TPThamGiaChuoi']),
      taiLieuHop: json['Tailieu_Hop'] as bool? ?? false,
    ));
  }

  /// Parse lịch xe (loai=4): không có ngày gốc, phải dựng từ "Thứ 2 02/11" + "07:00".
  /// Năm suy ra từ rangeStart; tháng nhỏ hơn tháng bắt đầu → sang năm sau (tuần vắt năm).
  factory LichTuanModel.fromXeJson(Map<String, dynamic> json,
      {required DateTime rangeStart}) {
    final ngayLabel = _s(json['NgayGioXe']);
    final gio = _s(json['gioxe']);
    final m = RegExp(r'(\d{1,2})/(\d{1,2})').firstMatch(ngayLabel);
    var date = rangeStart;
    if (m != null) {
      final day = int.parse(m.group(1)!);
      final month = int.parse(m.group(2)!);
      final year = month < rangeStart.month ? rangeStart.year + 1 : rangeStart.year;
      date = DateTime(year, month, day);
    }
    final hm = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(gio);
    final bd = hm == null
        ? date
        : DateTime(date.year, date.month, date.day,
            int.parse(hm.group(1)!), int.parse(hm.group(2)!));
    return LichTuanModel._(LichTuanEntity(
      lichtuanId: json['Lichtuan_ID'] as int,
      ngayGioBD: ngayLabel,
      gio: gio,
      thoiGian: _s(json['ThoiGianXe']),
      diaDiem: _s(json['DiaDiem']),
      chuTri: _s(json['ChuTri']),
      noiDung: _s(json['NoiDung']),
      ngayGioBDBase: bd,
      ngayGioKTBase: bd,
      thamGiaChitiet: '',
      thayDoi: '',
      isTruyenHinh: false,
      tt: _s(json['TT']),
      dvChuanBi: _cleanChuoi(json['DvChuanBiChuoi']),
      thanhPhanThamGia: _cleanChuoi(json['TPThamGiaChuoi']),
      chiTietXe: _s(json['chitietXe']),
    ));
  }

  /// Chuỗi API thường có đuôi ",  " thừa → bỏ dấu phẩy/khoảng trắng ở hai đầu
  static String _cleanChuoi(dynamic v) =>
      _s(v).replaceAll(RegExp(r'^[\s,]+|[\s,]+$'), '');

  LichTuanEntity toEntity() => entity;
}
