// lib/features/lich_tuan/domain/entities/lich_tuan_entity.dart
import 'package:equatable/equatable.dart';

/// Loại lịch tương ứng từng tab. `code` = tham số `loai` của API LichtuanJson;
/// `caNhan` (code 0) dùng API riêng LichtuanNVJson theo nvid.
enum LichTuanLoai {
  caNhan(0, 'Của tôi'),
  lanhDao(1, 'Lãnh đạo'),
  ban(2, 'Của ban'),
  khac(3, 'Khác'),
  xe(4, 'Lịch xe');

  const LichTuanLoai(this.code, this.label);
  final int code;
  final String label;
}

class LichTuanEntity extends Equatable {
  const LichTuanEntity({
    required this.lichtuanId,
    required this.ngayGioBD,
    required this.gio,
    required this.thoiGian,
    required this.diaDiem,
    required this.chuTri,
    required this.noiDung,
    required this.ngayGioBDBase,
    required this.ngayGioKTBase,
    required this.thamGiaChitiet,
    required this.thayDoi,
    required this.isTruyenHinh,
    required this.tt,
    this.dvChuanBi = '',
    this.thanhPhanThamGia = '',
    this.taiLieuHop = false,
    this.chiTietXe = '',
  });

  final int lichtuanId;
  final String ngayGioBD;
  final String gio;
  final String thoiGian;
  final String diaDiem;
  final String chuTri;
  final String noiDung;
  final DateTime ngayGioBDBase;
  final DateTime ngayGioKTBase;
  final String thamGiaChitiet;
  final String thayDoi;
  final bool isTruyenHinh;
  final String tt;
  final String dvChuanBi;
  final String thanhPhanThamGia;
  final bool taiLieuHop;
  /// HTML chi tiết xe (biển số, lái xe, SĐT) — chỉ có ở lịch xe
  final String chiTietXe;

  @override
  List<Object?> get props => [lichtuanId, ngayGioBDBase];
}
