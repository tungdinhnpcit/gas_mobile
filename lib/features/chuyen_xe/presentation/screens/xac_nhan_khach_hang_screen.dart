// lib/features/chuyen_xe/presentation/screens/xac_nhan_khach_hang_screen.dart
import 'dart:io'; // thu vien xu ly file tren he thong
import 'dart:typed_data'; // thu vien xu ly du lieu nhi phan (Uint8List)
import 'package:flutter/material.dart'; // thu vien ui flutter
import 'package:flutter_image_compress/flutter_image_compress.dart'; // nen anh truoc khi upload
import 'package:flutter_riverpod/flutter_riverpod.dart'; // quan ly state voi riverpod
import 'package:image_picker/image_picker.dart'; // chup anh tu camera
import 'package:intl/intl.dart'; // dinh dang so tien
import 'package:go_router/go_router.dart'; // dieu huong man hinh
import 'package:signature/signature.dart'; // widget ve chu ky tren canvas

import '../../data/models/chuyen_xe_model.dart'; // model du lieu chuyen xe, ban hang
import '../providers/chuyen_xe_provider.dart'; // provider quan ly state chuyen xe

// dinh dang so tien theo kieu Viet Nam (phan nghin dung dau cham)
final _vnd = NumberFormat('#,###', 'vi_VN');

// man hinh xac nhan khach hang - hien bien lai va cho phep chup anh hoac ky xac nhan
class XacNhanKhachHangScreen extends ConsumerStatefulWidget {
  final int xacNhanId; // id ban ghi xac nhan trong DB
  final int chuyenXeId; // id chuyen xe de refresh provider sau khi xac nhan
  final String? tenKhachHang; // ten khach hang hien thi tren bien lai
  final List<BanHangKhachHangModel>? banHangList; // danh sach hang ban truyen tu man hinh nhap
  final double tienMat; // so tien khach tra bang tien mat
  final double tienCK; // so tien khach tra bang chuyen khoan
  final double dieuChinhTien; // dieu chinh tien (+/-): duong = them, am = bot
  final double tienChenhLechVo; // chenh lech tien khi doi vo khac hang/gia (+/-)
  final List<BanHangNoVoModel>? noVoList; // danh sach no vo cua khach nay
  final double conLai; // so tien con lai chua tra (no)
  final String? ghiChu; // ghi chu them tu lai xe
  final String? tenTaiKhoan; // ten tai khoan cong ty nhan chuyen khoan
  final String? soTaiKhoan; // so tai khoan cong ty nhan chuyen khoan
  final String? tenNganHang; // ten ngan hang cua tai khoan nhan

  const XacNhanKhachHangScreen({
    super.key,
    required this.xacNhanId, // bat buoc phai co id xac nhan
    required this.chuyenXeId, // bat buoc phai co id chuyen xe de invalidate provider
    this.tenKhachHang, // co the null neu khong truyen ten
    this.banHangList, // co the null neu khong co danh sach hang
    this.tienMat = 0, // mac dinh 0 neu khong truyen (truong hop xac nhan lai tu badge)
    this.tienCK = 0, // mac dinh 0 neu khong truyen
    this.dieuChinhTien = 0, // mac dinh 0 neu khong truyen
    this.tienChenhLechVo = 0, // mac dinh 0 neu khong truyen
    this.noVoList, // co the null neu khong co no vo
    this.conLai = 0, // mac dinh 0 neu khong truyen
    this.ghiChu, // co the null neu khong co ghi chu
    this.tenTaiKhoan, // co the null neu khong chon tai khoan CK
    this.soTaiKhoan, // co the null neu khong chon tai khoan CK
    this.tenNganHang, // co the null neu khong chon tai khoan CK
  });

  @override
  ConsumerState<XacNhanKhachHangScreen> createState() => _XacNhanKhachHangScreenState();
}

// state cua man hinh xac nhan khach hang
class _XacNhanKhachHangScreenState extends ConsumerState<XacNhanKhachHangScreen> {
  bool _uploading = false; // trang thai dang upload de khoa nut va hien loading
  bool _daChupAnh = false; // da upload anh bien lai ky tay chua
  bool _daKy = false;      // da ky xac nhan tren app chua

  // nen anh giam dan quality/kich thuoc toi khi duoi nguong an toan (900KB, chua margin
  // duoi hard-limit 1MB cua backend XacNhanKhachHangController) - anh camera thuong 2-8MB
  Future<Uint8List> _compressPhotoBytes(Uint8List rawBytes) async {
    const maxBytes = 900 * 1024;
    var quality = 85;
    var minSize = 1600;

    Future<Uint8List> compressOnce() => FlutterImageCompress.compressWithList(
          rawBytes,
          quality: quality,
          minWidth: minSize,
          minHeight: minSize,
        );

    var result = await compressOnce();

    while (result.lengthInBytes > maxBytes && quality > 30) {
      quality -= 15;
      result = await compressOnce();
    }

    while (result.lengthInBytes > maxBytes && minSize > 600) {
      minSize -= 300;
      result = await compressOnce();
    }

    return result;
  }

  // xu ly chup anh bien lai da co chu ky tay cua khach roi upload len server
  Future<void> _uploadAnh() async {
    try {
      setState(() => _uploading = true); // bat trang thai loading
      final picker = ImagePicker(); // khoi tao doi tuong chup anh
      final photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 90); // mo camera
      if (photo == null) return; // nguoi dung huy khong chup anh thi thoat

      // nen anh truoc khi upload de tranh vuot gioi han 1MB cua backend
      final rawBytes = await File(photo.path).readAsBytes();
      final compressedBytes = await _compressPhotoBytes(rawBytes);

      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/receipt_${widget.xacNhanId}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(compressedBytes);

      final repo = ref.read(chuyenXeRepositoryProvider); // lay repository tu provider
      await repo.uploadXacNhan( // goi api upload anh len server
        widget.xacNhanId, // id ban ghi xac nhan can cap nhat
        file: tempFile, // file anh da nen
        loaiXacNhan: 'anh', // danh dau day la xac nhan bang anh
      );

      await tempFile.delete().catchError((_) => tempFile); // xoa file tam, bo qua neu xoa loi

      if (mounted) { // kiem tra widget con tren cay truoc khi cap nhat UI
        setState(() => _daChupAnh = true); // danh dau da co anh bien lai, van cho ky tiep
        ScaffoldMessenger.of(context).showSnackBar( // hien thong bao thanh cong
          const SnackBar(
            content: Text('✓ Đã lưu ảnh biên lai. Có thể ký thêm trên app.'),
            backgroundColor: Colors.green,
            duration: Duration(milliseconds: 2000), // tu dong an sau 2 giay
          ),
        );
      }
    } catch (e) {
      if (mounted) { // kiem tra widget con song truoc khi hien thong bao loi
        ScaffoldMessenger.of(context).showSnackBar( // hien thong bao loi
          SnackBar(
            content: Text('❌ Lỗi: ${e.toString().split('\n').first}'), // chi lay dong loi dau tien
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _uploading = false); // tat trang thai loading du thanh cong hay that bai
    }
  }

  // xu ly mo man hinh ve chu ky, doi ket qua roi quay ve tab ban hang
  Future<void> _kyXacNhan() async {
    if (!mounted) return; // dam bao widget con song truoc khi dieu huong
    final result = await Navigator.of(context).push<String>( // mo man hinh ve chu ky, doi ket qua String
      MaterialPageRoute(builder: (_) => ChuKyScreen(xacNhanId: widget.xacNhanId)), // truyen xacNhanId sang man hinh chu ky
    );
    if (result != null && mounted) { // neu khach da ky thanh cong (result = 'ok') va widget con song
      setState(() => _daKy = true); // danh dau da ky tren app, van cho chup anh bien lai tiep
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Đã lưu chữ ký. Có thể chụp thêm ảnh biên lai.'),
          backgroundColor: Colors.green,
          duration: Duration(milliseconds: 2000),
        ),
      );
    }
  }

  // hoan tat man hinh: refresh tab ban hang de hien du lieu vua nhap + xac nhan, roi quay ve
  void _hoanTat() {
    if (widget.chuyenXeId > 0) {
      ref.invalidate(chuyenXeDetailProvider(widget.chuyenXeId)); // buoc provider fetch lai du lieu moi
    }
    context.pop(); // quay ve tab ban hang
  }

  // widget hien mot hang thong tin trong bien lai (nhan trai, gia tri phai)
  Widget _infoRow(String label, String value, {Color? valueColor, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final banHangList = widget.banHangList ?? []; // lay danh sach hang, neu null thi dung list rong
    final tongTien = banHangList.fold<double>(0, (sum, b) => sum + b.thanhTien) +
        widget.tienChenhLechVo; // tinh tong tien tu tat ca cac dong hang + chenh lech doi vo
    final tongVoThu = banHangList.fold<int>(0, (sum, b) => sum + b.soVoThu); // tong so vo thu tu khach
    final tongVoBan = banHangList.fold<int>(0, (sum, b) => sum + b.soVoBan); // tong so vo ban cho khach
    final noVoList = widget.noVoList ?? []; // danh sach no vo cua khach nay
    // loc ra cac dong ban binh gas: dong co thanh tien > 0 la ban binh, dong co thanh tien = 0 la vo
    final dongBanBinh = banHangList.where((b) => b.thanhTien > 0).toList();

    return PopScope(
      // Invalidate provider chi tiet tren MỌI duong thoat man hinh (swipe-back
      // gesture cua CupertinoPage, nut back AppBar, nut Huỷ, nut Hoàn tất) để
      // tab ban hang luon fetch lai danh sach khach + tong so moi nhat.
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && widget.chuyenXeId > 0) {
          ref.invalidate(chuyenXeDetailProvider(widget.chuyenXeId));
        }
      },
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Xác nhận khách hàng'), // tieu de man hinh
        leading: BackButton(onPressed: () { // nut quay lai
          if (context.canPop()) {
            context.pop(); // neu co man hinh truoc thi pop
          } else {
            context.go('/'); // neu khong co thi ve trang chu
          }
        }),
      ),
      body: SingleChildScrollView( // cho phep cuon khi noi dung dai hon man hinh
        padding: const EdgeInsets.all(16), // khoang cach 16px xung quanh
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, // can trai noi dung
          children: [
            // ---- Bien lai ban hang ----
            Container( // khung chua bien lai
              decoration: BoxDecoration(
                border: Border.all(color: Colors.teal.shade200), // vien khung mau teal nhat
                borderRadius: BorderRadius.circular(8), // goc bo tron 8px
                color: Colors.grey.shade50, // nen xam rat nhat
              ),
              padding: const EdgeInsets.all(14), // khoang dem ben trong 14px
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // tieu de bien lai
                  Row(
                    children: [
                      const Icon(Icons.receipt_long_outlined, size: 16, color: Colors.teal),
                      const SizedBox(width: 6),
                      const Text(
                        'BIÊN LAI BÁN HÀNG',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.teal),
                      ),
                    ],
                  ),
                  const Divider(height: 16),

                  // thong tin khach hang
                  _infoRow('Khách hàng:', widget.tenKhachHang ?? '—', bold: true),
                  const SizedBox(height: 8),

                  // bang chi tiet mat hang (chi hien neu co dong ban binh)
                  if (dongBanBinh.isNotEmpty) ...[
                    const Text('Chi tiết hàng bán:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black54)),
                    const SizedBox(height: 4),
                    Table(
                      columnWidths: const { // ty le do rong cot
                        0: FlexColumnWidth(3), // cot mat hang rong nhat
                        1: FlexColumnWidth(1), // cot so luong
                        2: FlexColumnWidth(1.5), // cot don gia
                        3: FlexColumnWidth(2), // cot thanh tien
                      },
                      children: [
                        // hang tieu de
                        TableRow(
                          decoration: BoxDecoration(color: Colors.grey.shade200),
                          children: [
                            _cell('Mặt hàng', isHeader: true),
                            _cell('SL', isHeader: true, align: TextAlign.center),
                            _cell('Đ/giá', isHeader: true, align: TextAlign.right),
                            _cell('T.tiền', isHeader: true, align: TextAlign.right),
                          ],
                        ),
                        // cac dong hang ban
                        ...dongBanBinh.map((b) => TableRow(
                          children: [
                            _cell('${b.maMatHang ?? ''} ${b.tenMatHang ?? ''}', maxLines: 2),
                            _cell('${b.soLuong}', align: TextAlign.center),
                            _cell(_vnd.format(b.donGia), align: TextAlign.right),
                            _cell('${_vnd.format(b.thanhTien)} đ', align: TextAlign.right),
                          ],
                        )),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],

                  // section vo thu va vo ban (chi hien neu co)
                  if (tongVoThu > 0 || tongVoBan > 0) ...[
                    const Divider(height: 10),
                    const Text('Vỏ bình:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black54)),
                    const SizedBox(height: 4),
                    if (tongVoThu > 0) _infoRow('Vỏ thu:', '$tongVoThu vỏ'),
                    if (tongVoBan > 0) _infoRow('Vỏ bán:', '$tongVoBan vỏ'),
                    const SizedBox(height: 8),
                  ],

                  // section no vo (chi hien neu co khai bao no vo khi nhap ban hang)
                  if (noVoList.isNotEmpty) ...[
                    const Divider(height: 10),
                    const Text('Nợ vỏ:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black54)),
                    const SizedBox(height: 4),
                    for (final n in noVoList)
                      _infoRow(
                        '${n.tenNhaCungCap != null ? [n.maNhaCungCap, n.tenNhaCungCap].where((s) => s != null && s.isNotEmpty).join(' - ') : '(Không rõ hãng)'} • ${n.tenMatHang ?? ''}:',
                        '${n.soLuong} vỏ',
                        valueColor: Colors.orange.shade700,
                      ),
                    const SizedBox(height: 8),
                  ],

                  // section tong hop thanh toan
                  const Divider(height: 10),
                  const Text('Thanh toán:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black54)),
                  const SizedBox(height: 4),
                  _infoRow('Tổng tiền:', '${_vnd.format(tongTien)} đ', valueColor: Colors.teal.shade700, bold: true),
                  // chi hien dong chenh lech doi vo khi khac 0
                  if (widget.tienChenhLechVo != 0)
                    _infoRow(
                      'Chênh lệch đổi vỏ:',
                      '${widget.tienChenhLechVo > 0 ? '+' : ''}${_vnd.format(widget.tienChenhLechVo)} đ',
                      valueColor: widget.tienChenhLechVo > 0 ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  // chi hien dong dieu chinh khi co gia tri khac 0 (them/bot tien luc nhap ban hang)
                  if (widget.dieuChinhTien != 0)
                    _infoRow(
                      'Điều chỉnh:',
                      '${widget.dieuChinhTien > 0 ? '+' : ''}${_vnd.format(widget.dieuChinhTien)} đ',
                      valueColor: widget.dieuChinhTien > 0 ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  _infoRow('Tiền mặt:', '${_vnd.format(widget.tienMat)} đ'), // luon hien du co = 0
                  _infoRow('Chuyển khoản:', '${_vnd.format(widget.tienCK)} đ'), // luon hien du co = 0
                  // hien thong tin tai khoan nhan CK neu co (chi hien khi co chuyen khoan)
                  if (widget.tienCK > 0 && (widget.tenTaiKhoan != null || widget.soTaiKhoan != null))
                    Padding(
                      padding: const EdgeInsets.only(left: 8, top: 2, bottom: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.tenTaiKhoan != null)
                            Text(
                              '→ ${widget.tenTaiKhoan}${widget.tenNganHang != null ? ' — ${widget.tenNganHang}' : ''}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                            ),
                          if (widget.soTaiKhoan != null)
                            Text(
                              '   STK: ${widget.soTaiKhoan}',
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                            ),
                        ],
                      ),
                    ),
                  // hien tien no - do neu no, xanh neu da thanh toan du
                  _infoRow(
                    'Còn lại (nợ):',
                    '${_vnd.format(widget.conLai)} đ',
                    valueColor: widget.conLai > 0 ? Colors.red.shade700 : Colors.green.shade700,
                    bold: true,
                  ),

                  // ghi chu (chi hien neu co)
                  if (widget.ghiChu != null && widget.ghiChu!.isNotEmpty) ...[
                    const Divider(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ghi chú: ', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                        Expanded(
                          child: Text(
                            widget.ghiChu!,
                            style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24), // khoang cach giua bien lai va cac nut

            // ---- Cac nut xac nhan (co the lam ca 2 luong song song) ----
            const Text(
              'Xác nhận bằng:', // tieu de nhom nut
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 4),
            const Text(
              'Có thể vừa ký trên app vừa chụp ảnh biên lai — cả hai đều được lưu.',
              style: TextStyle(fontSize: 11, color: Colors.black54, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity, // nut rong toan man hinh
              child: ElevatedButton.icon(
                icon: Icon(_daChupAnh ? Icons.check_circle : Icons.camera_alt_outlined, size: 20),
                label: Text(_daChupAnh ? '✓ Đã có ảnh biên lai — chụp lại' : '📷 Chụp ảnh biên lai ký tay'),
                onPressed: _uploading ? null : _uploadAnh, // vo hieu hoa khi dang upload
                style: ElevatedButton.styleFrom(
                  backgroundColor: _daChupAnh ? const Color(0xFF2E7D32) : const Color(0xFF1976D2), // xanh la khi da co
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  disabledBackgroundColor: Colors.grey.shade300, // mau xam khi bi vo hieu hoa
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity, // nut rong toan man hinh
              child: ElevatedButton.icon(
                icon: Icon(_daKy ? Icons.check_circle : Icons.edit_outlined, size: 20),
                label: Text(_daKy ? '✓ Đã ký trên app — ký lại' : '✍️ Ký xác nhận trên app'),
                onPressed: _uploading ? null : _kyXacNhan, // vo hieu hoa khi dang upload
                style: ElevatedButton.styleFrom(
                  backgroundColor: _daKy ? const Color(0xFF2E7D32) : const Color(0xFF7C3AED), // xanh la khi da co
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity, // nut rong toan man hinh
              child: (_daChupAnh || _daKy)
                  ? ElevatedButton.icon( // da xac nhan it nhat 1 luong -> nut Hoan tat noi bat
                      icon: const Icon(Icons.done_all, size: 20),
                      label: const Text('Hoàn tất'),
                      onPressed: _uploading ? null : _hoanTat,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00897B), // teal
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        disabledBackgroundColor: Colors.grey.shade300,
                      ),
                    )
                  : OutlinedButton.icon( // chua xac nhan -> luu va bo qua
                      icon: const Icon(Icons.close_outlined, size: 20),
                      label: const Text('Lưu và không xác nhận'),
                      onPressed: _uploading ? null : _hoanTat,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        disabledForegroundColor: Colors.grey.shade300,
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            if (_uploading) // chi hien loading khi dang xu ly
              Center(
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: const CircularProgressIndicator(strokeWidth: 2), // vong tron loading nho
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }

  // helper tao o trong bang bien lai
  Widget _cell(String text, {bool isHeader = false, TextAlign align = TextAlign.left, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isHeader ? FontWeight.w600 : FontWeight.normal,
          color: isHeader ? Colors.black87 : Colors.black,
        ),
        textAlign: align,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ============ Man hinh ve chu ky ============

// man hinh full screen cho phep khach hang ve chu ky bang ngon tay roi upload len server
class ChuKyScreen extends ConsumerStatefulWidget {
  final int xacNhanId; // id ban ghi xac nhan se duoc cap nhat sau khi upload chu ky

  const ChuKyScreen({super.key, required this.xacNhanId});

  @override
  ConsumerState<ChuKyScreen> createState() => _ChuKyScreenState();
}

// state quan ly canvas ve chu ky va trang thai upload
class _ChuKyScreenState extends ConsumerState<ChuKyScreen> {
  late SignatureController _signatureController; // controller dieu khien canvas chu ky
  bool _uploading = false; // trang thai dang xu ly upload

  @override
  void initState() {
    super.initState();
    _signatureController = SignatureController( // khoi tao controller canvas chu ky
      penStrokeWidth: 3, // do day net but 3px
      penColor: Colors.black, // mau but la mau den
      exportBackgroundColor: Colors.white, // nen trang khi xuat anh PNG
    );
  }

  @override
  void dispose() {
    _signatureController.dispose(); // giai phong controller khi man hinh bi xoa
    super.dispose();
  }

  // xu ly xuat chu ky thanh PNG roi upload len server, tra ve ket qua cho man hinh cha
  Future<void> _confirm() async {
    if (!_signatureController.isNotEmpty) { // kiem tra khach co ve gi chua
      ScaffoldMessenger.of(context).showSnackBar( // nhac khach chua ve chu ky
        const SnackBar(
          content: Text('❌ Vui lòng ký trước khi xác nhận'),
          backgroundColor: Colors.red,
        ),
      );
      return; // thoat som, khong lam gi them
    }

    try {
      setState(() => _uploading = true); // bat trang thai loading
      final Uint8List? pngBytes = await _signatureController.toPngBytes(); // xuat canvas thanh mang byte PNG
      if (pngBytes == null) throw Exception('Không thể xuất chữ ký'); // nem loi neu xuat that bai

      // luu byte PNG ra file tam tren thiet bi de chuan bi upload
      final tempDir = Directory.systemTemp; // lay thu muc temp cua he thong
      final tempFile = File('${tempDir.path}/signature_${widget.xacNhanId}_${DateTime.now().millisecondsSinceEpoch}.png'); // ten file doc nhat theo thoi gian
      await tempFile.writeAsBytes(pngBytes); // ghi byte PNG vao file tam

      // upload file tam len server
      final repo = ref.read(chuyenXeRepositoryProvider); // lay repository tu provider
      await repo.uploadXacNhan( // goi API upload
        widget.xacNhanId, // id ban ghi xac nhan
        file: tempFile, // file PNG chua chu ky
        loaiXacNhan: 'ky', // danh dau day la xac nhan bang chu ky
      );

      // xoa file tam sau khi upload xong, bo qua neu xoa bi loi (tra ve chinh file de thoa man kieu tra ve)
      await tempFile.delete().catchError((_) => tempFile);

      if (mounted) { // kiem tra widget con song truoc khi cap nhat UI
        ScaffoldMessenger.of(context).showSnackBar( // thong bao thanh cong
          const SnackBar(
            content: Text('✓ Xác nhận chữ ký thành công'),
            backgroundColor: Colors.green,
            duration: Duration(milliseconds: 1500),
          ),
        );
        Future.delayed(const Duration(milliseconds: 1500), () { // cho snackbar hien roi moi dong
          if (mounted) Navigator.pop(context, 'ok'); // tra ve 'ok' cho man hinh cha biet da ky thanh cong
        });
      }
    } catch (e) {
      if (mounted) { // kiem tra widget con song truoc khi hien loi
        ScaffoldMessenger.of(context).showSnackBar( // hien thong bao loi
          SnackBar(
            content: Text('❌ Lỗi: ${e.toString().split('\n').first}'), // lay dong dau tien cua thong bao loi
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _uploading = false); // tat loading du thanh cong hay that bai
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vẽ chữ ký'), // tieu de man hinh
        leading: BackButton(onPressed: () => context.pop()), // nut quay lai, khong truyen ket qua
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined), // icon xoa de ve lai
            onPressed: _uploading ? null : () => _signatureController.clear(), // xoa toan bo net da ve
            tooltip: 'Xóa', // tooltip giai thich chuc nang
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded( // canvas chiem phan lon man hinh
            child: Container(
              color: Colors.white, // nen trang cho vung ve
              child: Signature(
                controller: _signatureController, // gan controller quan ly net ve
                backgroundColor: Colors.grey.shade100, // nen xam rat nhat phia sau
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16), // khoang dem 16px xung quanh hai nut
            child: Row(
              children: [
                Expanded( // nut huy chiem nua chieu rong
                  child: OutlinedButton(
                    onPressed: _uploading ? null : () => context.pop(), // huy va quay ve khong tra ket qua
                    child: const Text('Hủy'),
                  ),
                ),
                const SizedBox(width: 12), // khoang cach giua 2 nut
                Expanded( // nut xac nhan chiem nua chieu rong
                  child: ElevatedButton(
                    onPressed: _uploading ? null : _confirm, // vo hieu hoa khi dang xu ly
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981), // mau xanh la xac nhan
                      foregroundColor: Colors.white,
                    ),
                    child: _uploading
                        ? const SizedBox( // hien loading spinner khi dang upload
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white), // mau trang cho spinner tren nen xanh
                            ),
                          )
                        : const Text('Xác nhận'), // text binh thuong khi khong loading
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
