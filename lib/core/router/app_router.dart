// lib/core/router/app_router.dart
import 'package:flutter/cupertino.dart' show CupertinoPage; // CupertinoPage cho animation swipe-back kieu iOS
import 'package:flutter/material.dart'; // thu vien UI chinh cua Flutter
import 'package:flutter/services.dart' show SystemUiOverlayStyle; // dieu chinh mau status bar
import 'package:flutter_riverpod/flutter_riverpod.dart'; // quan ly state toan cuc voi Riverpod
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // luu tru an toan (JWT token)
import 'package:go_router/go_router.dart'; // thu vien dieu huong route

import '../../features/ghi_chu/data/models/ghi_chu_model.dart';
import '../../features/ghi_chu/presentation/screens/ghi_chu_form_screen.dart';
import '../../features/ghi_chu/presentation/screens/ghi_chu_list_screen.dart';
import '../../features/than_so_hoc/presentation/screens/than_so_hoc_screen.dart'; // man hinh than so hoc
import '../network/api_client.dart'; // client goi API, xu ly redirect khi het han token
import '../../features/auth/presentation/screens/login_screen.dart'; // man hinh dang nhap (thiet ke moi theo Figma)
import '../../features/home/presentation/screens/home_screen.dart'; // man hinh trang chu
import '../../features/chuyen_xe/presentation/screens/chuyen_xe_detail_screen.dart'; // chi tiet chuyen xe
import '../../features/chuyen_xe/presentation/screens/chuyen_xe_list_screen.dart'; // danh sach chuyen xe
import '../../features/lich_tuan/presentation/screens/lich_tuan_screen.dart'; // lich tuan lam viec
import '../../features/thong_bao/presentation/screens/thong_bao_detail_screen.dart'; // chi tiet thong bao
import '../../features/thong_bao/presentation/screens/thong_bao_list_screen.dart'; // danh sach thong bao
import '../../features/cham_cong/presentation/screens/cham_cong_screen.dart'; // cham cong hang ngay
import '../../features/nhan_vien/presentation/screens/nhan_vien_list_screen.dart'; // danh sach nhan vien
import '../../features/nhan_vien/presentation/screens/nhan_vien_detail_screen.dart'; // chi tiet nhan vien
import '../../features/xe/presentation/screens/xe_list_screen.dart'; // danh sach xe
import '../../features/xe/presentation/screens/xe_detail_screen.dart'; // chi tiet xe
import '../../features/mat_hang/presentation/screens/mat_hang_list_screen.dart'; // danh sach mat hang
import '../../features/mat_hang/presentation/screens/mat_hang_detail_screen.dart'; // chi tiet mat hang
import '../../features/nha_cung_cap/presentation/screens/nha_cung_cap_list_screen.dart'; // danh sach nha cung cap
import '../../features/nha_cung_cap/presentation/screens/nha_cung_cap_detail_screen.dart'; // chi tiet nha cung cap
import '../../features/khach_hang/presentation/screens/khach_hang_list_screen.dart'; // danh sach khach hang
import '../../features/khach_hang/presentation/screens/khach_hang_detail_screen.dart'; // chi tiet khach hang
import '../../features/tong_quan/presentation/screens/tong_quan_screen.dart'; // tong quan doanh thu
import '../../features/tong_quan/presentation/screens/dai_ly_chi_tiet_screen.dart'; // chi tiet dai ly
import '../../features/tong_quan/presentation/screens/dai_ly_chua_mua_screen.dart'; // dai ly chua mua
import '../../features/tong_quan/presentation/screens/thong_ke_chuyen_xe_screen.dart'; // thong ke chuyen xe theo ngay
import '../../features/cai_dat/presentation/screens/cai_dat_screen.dart'; // man hinh cai dat
import '../../features/cai_dat/presentation/screens/thong_tin_tai_khoan_screen.dart'; // thong tin tai khoan nguoi dung
import '../../features/cai_dat/presentation/screens/doi_mat_khau_screen.dart'; // doi mat khau
import '../../features/cai_dat/presentation/screens/dong_bo_screen.dart'; // lam moi cache danh muc
import '../../features/chuyen_xe/presentation/screens/bat_dau_chuyen_screen.dart'; // bat dau ban hang trong ngay
import '../../features/chuyen_xe/presentation/screens/tim_kiem_khach_hang_screen.dart'; // tim kiem khach hang
import '../../features/chuyen_xe/presentation/screens/tim_kiem_phu_xe_screen.dart'; // tim kiem phu xe
import '../../features/chuyen_xe/presentation/screens/tim_kiem_mat_hang_screen.dart'; // tim kiem mat hang
import '../../features/chuyen_xe/presentation/screens/tim_kiem_nha_cung_cap_screen.dart'; // tim kiem nha cung cap
import '../../features/chuyen_xe/presentation/screens/chon_no_cu_screen.dart'; // chon khoan no cu de thu
import '../../features/chuyen_xe/presentation/screens/chuyen_xe_theo_ngay_screen.dart'; // xem chuyen xe theo ngay
import '../../features/chuyen_xe/presentation/screens/nhap_ban_hang_screen.dart'; // nhap ban hang cho khach
import '../../features/chuyen_xe/presentation/screens/sua_ban_hang_khach_hang_screen.dart'; // sua ban hang da nhap
import '../../features/chuyen_xe/presentation/screens/xac_nhan_khach_hang_screen.dart'; // xac nhan khach hang bang anh hoac chu ky
import '../../features/chuyen_xe/presentation/screens/phe_duyet_chuyen_xe_screen.dart'; // phe duyet chuyen xe (ke toan sau khi lai xe ket thuc)
import '../../features/chuyen_xe/data/models/chuyen_xe_model.dart'; // model du lieu chuyen xe
import '../../features/khach_hang/presentation/screens/tao_khach_hang_screen.dart'; // tao moi khach hang nhanh
import '../../features/kiem_ke/presentation/screens/kiem_ke_list_screen.dart'; // danh sach kiem ke
import '../../features/kiem_ke/presentation/screens/kiem_ke_nhap_screen.dart'; // nhap so lieu kiem ke
import '../../features/kiem_ke/presentation/screens/kiem_ke_tao_chuyen_screen.dart'; // tao chuyen kiem ke moi (Luong A cu)
import '../../features/kiem_ke/presentation/screens/kiem_ke_chon_chuyen_screen.dart'; // chon chuyen de lien ket vao phieu kiem ke
import '../../features/kiem_ke/presentation/screens/kiem_ke_nhap_so_mang_ve_screen.dart'; // ke toan nhap so mang ve truoc khi chon chuyen
import '../../features/kiem_ke/presentation/screens/kiem_ke_doi_chieu_screen.dart'; // doi chieu so mang ve
import '../../features/thong_bao/presentation/providers/thong_bao_provider.dart'; // provider so thong bao chua doc
import '../providers/user_info_provider.dart'; // thong tin user dang nhap (lay userId)
import '../services/background_polling_service.dart'; // dich vu kiem tra thong bao nen
import '../services/notification_service.dart'; // dich vu thong bao FCM va local
import '../services/sync_service.dart'; // dich vu dong bo danh muc tu server
import 'app_routes.dart'; // hang so chua tat ca cac duong dan route

// key dieu huong navigator goc - dung cho cac man hinh full-screen khong co bottom nav
final _rootNavigatorKey  = GlobalKey<NavigatorState>();
// key dieu huong navigator shell - dung cho cac man hinh co bottom nav
final _shellNavigatorKey = GlobalKey<NavigatorState>();
// doi tuong doc ghi token an toan (dung de kiem tra dang nhap trong redirect)
final _storage           = const FlutterSecureStorage();

// provider cung cap GoRouter cho toan bo app - duoc inject vao MaterialApp
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    navigatorKey: _rootNavigatorKey, // root navigator nhan tat ca cac route
    initialLocation: AppRoutes.home, // mo app bat dau tai trang chu
    redirect: (context, state) async { // ham guard kiem tra dang nhap truoc moi lan dieu huong
      final token   = await _storage.read(key: 'jwt_token'); // doc JWT token tu secure storage
      final isLogin = state.matchedLocation == AppRoutes.login; // kiem tra dang o man hinh login
      if (token == null && !isLogin) return AppRoutes.login; // chua dang nhap -> chuyen sang login
      if (token != null && isLogin)  return AppRoutes.home; // da dang nhap ma vao login -> ve home
      return null; // cho phep di chuyen binh thuong
    },
    routes: [
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.ghiChuForm,
        pageBuilder: (_, state) => CupertinoPage(
          key: state.pageKey,
          child: GhiChuFormScreen(item: state.extra as GhiChuModel?),
        ),
      ),
      GoRoute(
        path: AppRoutes.login, // route /login
        builder: (_, __) => const LoginScreen(), // man hinh dang nhap (thiet ke moi theo Figma)
      ),
      // Detail routes tai root navigator -- full-screen, ho tro swipe-back va nut back vat ly
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey, // gan vao root navigator de hien toan man hinh
        path: '/chuyen-xe/:id', // route chi tiet chuyen xe theo id
        pageBuilder: (_, state) => CupertinoPage( // CupertinoPage cho animation slide tu phai sang trai
          key: state.pageKey,
          child: ChuyenXeDetailScreen(chuyenXeId: state.pathParameters['id']!), // truyen id tu URL
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/thong-bao/:id', // route chi tiet thong bao
        pageBuilder: (_, state) => CupertinoPage(
          key: state.pageKey,
          child: ThongBaoDetailScreen(thongBaoId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/nhan-vien/:id', // route chi tiet nhan vien
        pageBuilder: (_, state) => CupertinoPage(
          key: state.pageKey,
          child: NhanVienDetailScreen(nhanVienId: int.parse(state.pathParameters['id']!)), // parse id sang int
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/xe/:id', // route chi tiet xe
        pageBuilder: (_, state) => CupertinoPage(
          key: state.pageKey,
          child: XeDetailScreen(xeId: int.parse(state.pathParameters['id']!)),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/mat-hang/:id', // route chi tiet mat hang
        pageBuilder: (_, state) => CupertinoPage(
          key: state.pageKey,
          child: MatHangDetailScreen(matHangId: int.parse(state.pathParameters['id']!)),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/nha-cung-cap/:id', // route chi tiet nha cung cap
        pageBuilder: (_, state) => CupertinoPage(
          key: state.pageKey,
          child: NhaCungCapDetailScreen(nhaCungCapId: int.parse(state.pathParameters['id']!)),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.taoKhachHang, // route tao moi khach hang nhanh (tu man hinh nhap ban hang)
        pageBuilder: (_, state) {
          // Callback nhan khach vua tao — gan truc tiep vao man cha, khong phu thuoc pop-result
          final onCreated = (state.extra as Map?)?['onCreated']
              as void Function(Map<String, dynamic>)?;
          return CupertinoPage(
            key: state.pageKey,
            child: TaoKhachHangScreen(onCreated: onCreated),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.timKiemKhachHang, // route tim kiem khach hang (popup chon)
        pageBuilder: (_, state) => CupertinoPage(
          key: state.pageKey,
          child: const TimKiemKhachHangScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.timKiemPhuXe, // route tim kiem phu xe (popup chon)
        pageBuilder: (_, state) => CupertinoPage(
          key: state.pageKey,
          child: const TimKiemPhuXeScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.timKiemMatHang, // route tim kiem mat hang (co the loc theo nha cung cap)
        pageBuilder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?; // doc tham so extra tu man hinh goi
          return CupertinoPage(
            key: state.pageKey,
            child: TimKiemMatHangScreen(
              nhaCungCapId: extra?['nhaCungCapId'] as int?, // loc mat hang theo nha cung cap neu co
            ),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.timKiemNhaCungCap, // route tim kiem nha cung cap (popup chon)
        pageBuilder: (_, state) => CupertinoPage(
          key: state.pageKey,
          child: const TimKiemNhaCungCapScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.chonNoCu, // route chon khoan no cu de thu (popup chon)
        pageBuilder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return CupertinoPage(
            key: state.pageKey,
            child: ChonNoCuScreen(excludeChuyenXeId: extra?['excludeChuyenXeId'] as int?),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/khach-hang/:id', // route chi tiet khach hang
        pageBuilder: (_, state) => CupertinoPage(
          key: state.pageKey,
          child: KhachHangDetailScreen(
            id: int.parse(state.pathParameters['id']!),
            // ngay mua cuoi (optional) tu danh sach "lau chua mua" - hien thi "Mua cuoi"
            ngayMuaCuoiCung: state.uri.queryParameters['ngayMua'] != null
                ? DateTime.tryParse(state.uri.queryParameters['ngayMua']!)
                : null,
          ),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.batDauChuyen, // route bat dau ban hang (kiem tra chuyen xe hom nay)
        pageBuilder: (_, state) => CupertinoPage(
          key: state.pageKey,
          child: const BatDauChuyenScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.banHangTheoNgay, // route xem chuyen xe theo ngay cu the
        pageBuilder: (_, state) => CupertinoPage(
          key: state.pageKey,
          child: ChuyenXeTheoNgayScreen(
              args: state.extra as ChuyenXeTheoNgayArgs), // truyen toan bo args qua extra
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/ban-hang/:id/nhap', // route nhap ban hang online (chuyen xe da co server id)
        pageBuilder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return CupertinoPage(
            key: state.pageKey,
            child: NhapBanHangScreen(
              chuyenXeServerId: int.tryParse(state.pathParameters['id']!), // id chuyen xe tren server
              phuXeId: extra?['phuXeId'] as int?, // id phu xe neu co
              ngayXuat: extra?['ngayXuat'] as DateTime?, // ngay xuat chuyen -> lay gia cau hinh theo ngay
            ),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/ban-hang/:chuyenXeId/khach-hang/:khachHangId/sua', // route sua ban hang da nhap cho khach hang cu the
        pageBuilder: (_, state) {
          final cxId  = int.tryParse(state.pathParameters['chuyenXeId']  ?? '') ?? 0; // id chuyen xe
          final khId  = int.tryParse(state.pathParameters['khachHangId'] ?? '') ?? 0; // id khach hang
          final extra = state.extra as Map<String, dynamic>? ?? {}; // du lieu extra, mac dinh map rong
          final rows  = (extra['rows'] as List?) // lay danh sach dong ban hang hien tai
              ?.map((e) => e as BanHangKhachHangModel).toList() ?? [];
          final gasDuRows = (extra['gasDuRows'] as List?) // lay danh sach dong mua gas du hien tai
              ?.map((e) => e as GasDuChiTietModel).toList() ?? <GasDuChiTietModel>[];
          final noVoRows = (extra['noVoRows'] as List?) // lay danh sach dong no vo hien tai
              ?.map((e) => e as BanHangNoVoModel).toList() ?? <BanHangNoVoModel>[];
          final thanhToan = extra['thanhToan'] as BanHangThanhToanModel?; // thong tin thanh toan hien tai
          return CupertinoPage(
            key: state.pageKey,
            child: SuaBanHangKhachHangScreen(
              chuyenXeId: cxId,
              khachHangId: khId,
              rows: rows, // truyen cac dong ban hang hien tai vao man hinh sua
              gasDuRows: gasDuRows, // truyen cac dong mua gas du hien tai vao man hinh sua
              noVoRows: noVoRows, // truyen cac dong no vo hien tai vao man hinh sua
              thanhToan: thanhToan, // truyen thong tin thanh toan hien tai vao man hinh sua
              canEdit: cxId > 0, // chi cho sua khi co id chuyen xe hop le
            ),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.kiemKeDocLapNhap, // route tao phieu kiem ke doc lap (Luong B)
        pageBuilder: (_, state) => CupertinoPage(
          key: state.pageKey,
          child: KiemKeNhapScreen(
            ngayLap: state.extra is DateTime ? state.extra as DateTime : null,
          ),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/kiem-ke/:kiemKeId/sua', // sua phieu kiem ke doc lap (Luong B)
        pageBuilder: (_, state) => CupertinoPage(
          key: state.pageKey,
          child: KiemKeNhapScreen(
            kiemKeId: int.parse(state.pathParameters['kiemKeId']!),
          ),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/kiem-ke/:kiemKeId/nhap-so-mang-ve', // ke toan nhap so mang ve truoc khi chon chuyen
        pageBuilder: (_, state) => CupertinoPage(
          key: state.pageKey,
          child: KiemKeNhapSoMangVeScreen(
            kiemKeId: int.parse(state.pathParameters['kiemKeId']!),
            ngay: state.extra is DateTime ? state.extra as DateTime : null,
          ),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/kiem-ke/:kiemKeId/chon-chuyen', // route chon chuyen de lien ket vao phieu kiem ke
        pageBuilder: (_, state) => CupertinoPage(
          key: state.pageKey,
          child: KiemKeChonChuyenScreen(
            kiemKeId: int.parse(state.pathParameters['kiemKeId']!),
            ngayMacDinh: state.extra is DateTime ? state.extra as DateTime : null,
          ),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/kiem-ke/:chuyenXeId/doi-chieu', // route doi chieu so mang ve (ke toan vs lai xe)
        pageBuilder: (_, state) => CupertinoPage(
          key: state.pageKey,
          child: KiemKeDoiChieuScreen(
            chuyenXeId: int.parse(state.pathParameters['chuyenXeId']!),
          ),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRoutes.kiemKeTaoChuyen, // Luong A cu: tao chuyen roi kiem ke gan san (khong con loi vao tu menu)
        pageBuilder: (_, state) => CupertinoPage(
          key: state.pageKey,
          child: const KiemKeTaoChuyenScreen(),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/kiem-ke/:chuyenXeId/nhap-cu', // Luong A cu: nhap so lieu kiem ke gan san cho 1 chuyen
        pageBuilder: (_, state) => CupertinoPage(
          key: state.pageKey,
          child: KiemKeNhapScreen(
            chuyenXeId: int.parse(state.pathParameters['chuyenXeId']!),
          ),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/dai-ly-chi-tiet/:id', // route chi tiet lich su mua hang cua dai ly
        pageBuilder: (_, state) => CupertinoPage(
          key: state.pageKey,
          child: DaiLyChiTietScreen(
            khachHangId: int.parse(state.pathParameters['id']!),
            tuNgay: state.uri.queryParameters['tuNgay'] != null // ngay bat dau loc tu query param
                ? DateTime.tryParse(state.uri.queryParameters['tuNgay']!)
                : null,
            denNgay: state.uri.queryParameters['denNgay'] != null // ngay ket thuc loc tu query param
                ? DateTime.tryParse(state.uri.queryParameters['denNgay']!)
                : null,
          ),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/tong-quan/chuyen-xe', // route thong ke chuyen xe theo khoang thoi gian
        pageBuilder: (_, state) => CupertinoPage(
          key: state.pageKey,
          child: ThongKeChuyenXeScreen(
            tuNgay: state.uri.queryParameters['tuNgay'] != null
                ? DateTime.tryParse(state.uri.queryParameters['tuNgay']!)
                : null,
            denNgay: state.uri.queryParameters['denNgay'] != null
                ? DateTime.tryParse(state.uri.queryParameters['denNgay']!)
                : null,
          ),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/phe-duyet/:id', // route man hinh phe duyet chuyen xe (ke toan sau khi lai xe ket thuc tren mobile)
        pageBuilder: (_, state) => CupertinoPage(
          key: state.pageKey,
          child: PheDuyetChuyenXeScreen(
            chuyenXeId: int.parse(state.pathParameters['id']!), // id chuyen xe can phe duyet
          ),
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: '/xac-nhan/:xacNhanId', // route man hinh xac nhan khach hang (bien lai + anh/chu ky)
        pageBuilder: (_, state) {
          final xacNhanId = int.parse(state.pathParameters['xacNhanId']!); // id ban ghi xac nhan
          final extra = state.extra as Map<String, dynamic>?; // tham so truyen qua extra
          return CupertinoPage(
            key: state.pageKey,
            child: XacNhanKhachHangScreen(
              xacNhanId: xacNhanId, // id xac nhan de upload anh/chu ky dung dich
              chuyenXeId: extra?['chuyenXeId'] as int? ?? 0, // id chuyen xe de refresh provider sau khi xac nhan
              tenKhachHang: extra?['tenKhachHang'] as String?, // ten khach hang hien thi tren bien lai
              banHangList: extra?['banHangList'] as List<BanHangKhachHangModel>?, // danh sach hang ban hien thi tren bien lai
              tienMat: (extra?['tienMat'] as double?) ?? 0, // tien mat khach da tra
              tienCK: (extra?['tienCK'] as double?) ?? 0, // tien chuyen khoan khach da tra
              dieuChinhTien: (extra?['dieuChinhTien'] as double?) ?? 0, // dieu chinh tien (+/-)
              tienChenhLechVo: (extra?['tienChenhLechVo'] as double?) ?? 0, // chenh lech tien doi vo (+/-)
              noVoList: extra?['noVoList'] as List<BanHangNoVoModel>?, // danh sach no vo cua khach
              conLai: (extra?['conLai'] as double?) ?? 0, // so tien con no chua thanh toan
              ghiChu: extra?['ghiChu'] as String?, // ghi chu them neu co
              tenTaiKhoan: extra?['tenTaiKhoan'] as String?, // ten tai khoan cong ty nhan CK
              soTaiKhoan: extra?['soTaiKhoan'] as String?, // so tai khoan cong ty nhan CK
              tenNganHang: extra?['tenNganHang'] as String?, // ten ngan hang cua tai khoan nhan
            ),
          );
        },
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey, // shell navigator quan ly cac man hinh co bottom nav
        builder: (_, __, child) => _MainShell(child: child), // boc noi dung vao shell co AppBar + BottomNav
        routes: [
          GoRoute(
            path: AppRoutes.home, // trang chu
            builder: (_, __) => const HomeScreen(),
          ),
          GoRoute(
            path: AppRoutes.chuyenXeList, // danh sach chuyen xe
            builder: (_, __) => const ChuyenXeListScreen(),
          ),
          GoRoute(
            path: AppRoutes.thongBaoList, // danh sach thong bao
            builder: (_, __) => const ThongBaoListScreen(),
          ),
          GoRoute(
            path: AppRoutes.nhanVienList, // danh sach nhan vien
            builder: (_, __) => const NhanVienListScreen(),
          ),
          GoRoute(
            path: AppRoutes.xeList, // danh sach xe
            builder: (_, __) => const XeListScreen(),
          ),
          GoRoute(
            path: AppRoutes.matHangList, // danh sach mat hang gas
            builder: (_, __) => const MatHangListScreen(),
          ),
          GoRoute(
            path: AppRoutes.nhaCungCapList, // danh sach nha cung cap / hang san xuat
            builder: (_, __) => const NhaCungCapListScreen(),
          ),
          GoRoute(
            path: AppRoutes.khachHangList, // danh sach khach hang / dai ly
            builder: (_, __) => const KhachHangListScreen(),
          ),
          GoRoute(
            path: AppRoutes.tongQuan, // tong quan doanh thu va bieu do
            builder: (_, __) => const TongQuanScreen(),
          ),
          GoRoute(
            path: AppRoutes.daiLyChuaMua, // danh sach dai ly lau chua mua hang
            builder: (_, __) => const DaiLyChuaMuaScreen(),
          ),
          GoRoute(
            path: AppRoutes.lichTuan, // lich tuan lam viec cua lai xe
            builder: (_, __) => const LichTuanScreen(),
          ),
          GoRoute(
            path: AppRoutes.chamCong, // cham cong hang ngay
            builder: (_, __) => const ChamCongScreen(),
          ),
          GoRoute(
            path: AppRoutes.caiDat, // man hinh cai dat chung
            builder: (_, __) => const CaiDatScreen(),
          ),
          GoRoute(
            path: AppRoutes.thongTinTaiKhoan, // thong tin ca nhan nguoi dung dang nhap
            builder: (_, __) => const ThongTinTaiKhoanScreen(),
          ),
          GoRoute(
            path: AppRoutes.doiMatKhau, // doi mat khau tai khoan
            builder: (_, __) => const DoiMatKhauScreen(),
          ),
          GoRoute(
            path: AppRoutes.dongBo, // man hinh dong bo du lieu offline len server
            builder: (_, __) => const DongBoScreen(),
          ),
          GoRoute(
            path: AppRoutes.kiemKeList, // danh sach chuyen kiem ke hang hoa
            builder: (_, __) => const KiemKeListScreen(),
          ),
          GoRoute(
            path: AppRoutes.ghiChuList,
            builder: (_, __) => const GhiChuListScreen(),
          ),
          GoRoute(
            path: AppRoutes.thanSoHoc, // man hinh than so hoc
            builder: (_, __) => const ThanSoHocScreen(),
          ),
        ],
      ),
    ],
  );

  NotificationService.setNavigateCallback((route) { // dang ky callback dieu huong khi bam thong bao FCM
    router.go(route);
    // Mo tu notification -> lam moi badge + nap lai danh sach de hien thi thong bao vua nhan
    ref.invalidate(soChuaDocProvider);
    final uid = ref.read(userInfoProvider).valueOrNull?.userId ?? 0;
    if (uid > 0) {
      ref.invalidate(thongBaoListProvider);
    }
  });
  ApiClient.setNavigateToLogin((route) => router.go(route)); // dang ky callback chuyen sang login khi token het han (401)

  return router;
});

// ------------------------------------------------------------------
// _MainShell -- Shell boc noi dung: co AppBar + BottomNav 3 tab co dinh
// ------------------------------------------------------------------

// widget shell chinh chua AppBar, BottomNav va boc noi dung cac man hinh con
class _MainShell extends ConsumerStatefulWidget {
  const _MainShell({required this.child});
  final Widget child; // noi dung man hinh hien tai (duoc inject boi ShellRoute)

  @override
  ConsumerState<_MainShell> createState() => _MainShellState();
}

// state cua shell: quan ly tab hien tai, dong bo danh muc khi mo app, post-login tasks
class _MainShellState extends ConsumerState<_MainShell> with WidgetsBindingObserver {
  int _currentIndex = 0; // chi so tab dang chon (0=Home, 1=ThongBao, 2=CaiDat)
  DateTime? _lastCatalogSync; // thoi diem bat dau dong bo danh muc gan nhat (de throttle)
  bool _catalogSyncing = false; // dang dong bo thi khong goi chong

  // khoang cach toi thieu giua 2 lan dong bo khi app quay lai foreground
  static const _resumeSyncInterval = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // nghe vong doi app de dong bo khi quay lai foreground
    _syncCatalog(force: true); // moi lan mo app deu dong bo lai danh muc
    WidgetsBinding.instance.addPostFrameCallback((_) => _runPostLoginTasks()); // chay sau khi frame dau tien hien thi
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // app quay lai foreground -> dong bo lai danh muc (co throttle 5 phut)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _syncCatalog();
  }

  // dong bo cache danh muc (mat hang, khach hang, xe...) tu server ve SQLite.
  // force=true: bo qua throttle (dung khi mo app). Loi chi log, khong chan nguoi dung.
  Future<void> _syncCatalog({bool force = false}) async {
    if (_catalogSyncing) return;
    final last = _lastCatalogSync;
    if (!force && last != null && DateTime.now().difference(last) < _resumeSyncInterval) return;
    _catalogSyncing = true;
    _lastCatalogSync = DateTime.now();
    try {
      final result = await SyncService.instance.syncCatalog(); // thuc hien dong bo danh muc tu server
      debugPrint('[SYNC] ${result.summary}');
    } catch (e) {
      debugPrint('[SYNC] LỖI dong bo danh muc: $e');
    } finally {
      _catalogSyncing = false;
    }
  }

  // chay cac tac vu nen sau khi dang nhap thanh cong: dang ky FCM, background polling, kiem tra thong bao
  Future<void> _runPostLoginTasks() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'jwt_token'); // lay token de xac minh da dang nhap
    if (token == null || !mounted) return; // chua dang nhap hoac widget bi destroy thi bo qua

    // 1. Dang ky FCM token voi backend de backend biet dia chi gui thong bao
    try {
      final fcmToken = await NotificationService.getFcmToken(); // lay token FCM tu Firebase
      if (fcmToken != null) {
        await ApiClient.instance.dio.put( // goi API luu token vao DB
          '/api/auth/device-token',
          data: {'fcmToken': fcmToken},
        );
        debugPrint('[POST-LOGIN] FCM token registered');
      }
      // Tu dong re-register khi FCM token thay doi (Firebase dinh ky cap nhat token)
      NotificationService.onTokenRefresh.listen((newToken) async {
        try {
          await ApiClient.instance.dio.put('/api/auth/device-token',
              data: {'fcmToken': newToken}); // cap nhat token moi len server
          debugPrint('[POST-LOGIN] FCM token refreshed');
        } catch (e) {
          debugPrint('[POST-LOGIN] FCM token refresh failed: $e');
        }
      });
    } catch (e) {
      debugPrint('[POST-LOGIN] FCM registration failed: $e');
    }

    // 2. Dang ky background polling (workmanager) de kiem tra thong bao khi app bi kill
    try {
      await BackgroundPollingService.registerPeriodicTask(); // dang ky task chay dinh ky khi app nen
      debugPrint('[POST-LOGIN] Background polling registered');
    } catch (e) {
      debugPrint('[POST-LOGIN] Background polling failed: $e');
    }

    // 3. Kiem tra thong bao chua doc va hien local notification neu co thong bao moi
    try {
      final userIdStr = await storage.read(key: 'user_id'); // lay user id tu secure storage
      final userId = int.tryParse(userIdStr ?? '');
      if (userId == null || !mounted) return;

      await BackgroundPollingService.checkAndNotifyIfIncreased(userId);
      debugPrint('[POST-LOGIN] Notification check done for userId=$userId');
    } catch (e) {
      debugPrint('[POST-LOGIN] Notification check failed: $e');
    }
  }

  // 3 tab chinh cua bottom navigation
  static const _tabs = [
    _TabDef(
      route:        AppRoutes.home, // tab trang chu
      icon:         Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label:        'Trang chủ',
    ),
    _TabDef(
      route:        AppRoutes.thongBaoList, // tab thong bao
      icon:         Icons.notifications_outlined,
      selectedIcon: Icons.notifications_rounded,
      label:        'Thông báo',
    ),
    _TabDef(
      route:        AppRoutes.caiDat, // tab cai dat
      icon:         Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
      label:        'Cài đặt',
    ),
  ];

  // tieu de hien thi tren AppBar cho 3 tab chinh
  static const _tabTitles = ['Trang chủ', 'Thông báo', 'Cài đặt'];

  // bang anh xa tu route path -> tieu de AppBar cho cac man hinh chuc nang (khong phai 3 tab)
  static const _featureTitles = {
    AppRoutes.chuyenXeList:     'Chuyến xe',
    AppRoutes.nhanVienList:     'Nhân viên',
    AppRoutes.xeList:           'Xe',
    AppRoutes.matHangList:      'Mặt hàng',
    AppRoutes.nhaCungCapList:   'Nhà cung cấp',
    AppRoutes.khachHangList:    'Khách hàng',
    AppRoutes.tongQuan:         'Tổng quan',
    AppRoutes.daiLyChuaMua:     'Đại lý lâu chưa mua',
    AppRoutes.lichTuan:         'Lịch tuần',
    AppRoutes.chamCong:         'Chấm công',
    AppRoutes.thongTinTaiKhoan: 'Thông tin tài khoản',
    AppRoutes.doiMatKhau:       'Đổi mật khẩu',
    AppRoutes.dongBo:           'Đồng bộ dữ liệu',
    AppRoutes.kiemKeList:       'Kiểm kê',
    AppRoutes.ghiChuList: 'Ghi chú bảo mật',
    AppRoutes.thanSoHoc: 'Thần số học',
  };

  // tra ve tieu de AppBar tuong ung voi route hien tai
  String _resolveTitle(String location) {
    if (_featureTitles.containsKey(location)) return _featureTitles[location]!; // man hinh chuc nang
    return _tabTitles[_currentIndex]; // mac dinh dung tieu de cua tab dang chon
  }

  // xu ly khi nguoi dung bam vao mot tab trong bottom nav
  void _onTabTapped(int index) {
    final location = GoRouterState.of(context).uri.path;
    if (index == _currentIndex && location == _tabs[index].route) return; // da o tab nay roi, bo qua
    setState(() => _currentIndex = index); // cap nhat chi so tab hien tai
    context.go(_tabs[index].route); // dieu huong toi route cua tab do
  }

  @override
  Widget build(BuildContext context) {
    final location   = GoRouterState.of(context).uri.path; // lay duong dan hien tai
    final isTabRoute = location == AppRoutes.home || // kiem tra co dang o 1 trong 3 tab chinh khong
        _tabs.any((t) => t.route == location);
    final isHome     = location == AppRoutes.home; // kiem tra co dang o trang chu khong
    final title      = _resolveTitle(location); // lay tieu de AppBar tuong ung

    void goBack() { // ham quay lai man hinh truoc
      if (context.canPop()) {
        context.pop(); // neu co man hinh truoc trong stack thi pop
      } else {
        context.go(AppRoutes.home); // khong co man hinh truoc thi ve trang chu
      }
    }

    // Vuot phai de quay lai -- chi bat khi vuot bat dau tu mep trai man hinh (< 40px),
    // tranh nuot gesture keo doc cua ListView (vd: pull-to-refresh).
    double dragStartX = 0;
    return GestureDetector(
      // Chi cham gesture ngang; khong dung behavior de khong nuot cham cua child.
      onHorizontalDragStart: (details) {
        dragStartX = details.globalPosition.dx;
      },
      onHorizontalDragEnd: (details) {
        if (!isTabRoute &&
            dragStartX < 40 && // chi vuot back khi bat dau tu mep trai
            (details.primaryVelocity ?? 0) > 300) { // vuot nhanh tu trai sang phai
          goBack();
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: isHome, // trang chu: body tran xuong duoi AppBar (hieu ung trong suot)
        appBar: AppBar(
          automaticallyImplyLeading: false, // khong tu dong them nut back, tu xu ly thu cong
          // Trang chu: AppBar trong suot, khong hien title, icon trang
          backgroundColor: isHome ? Colors.transparent : null, // trong suot o trang chu
          elevation: isHome ? 0 : null, // bo bong o trang chu
          scrolledUnderElevation: isHome ? 0 : null, // bo bong khi cuon o trang chu
          foregroundColor: isHome ? Colors.white : null, // icon trang de hien tren anh nen
          systemOverlayStyle: isHome // status bar trong suot nen trang o trang chu
              ? const SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: Brightness.light, // icon status bar mau sang (tren nen toi)
                  statusBarBrightness: Brightness.dark,
                )
              : null,
          leading: isTabRoute // neu o tab chinh thi khong hien nut back
              ? null
              : IconButton( // neu o man hinh chuc nang thi hien nut back
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Quay lại',
                  onPressed: goBack,
                ),
          title: isHome ? null : Text(title), // trang chu khong co title, man hinh khac hien title
        ),
        body: widget.child, // noi dung man hinh hien tai duoc inject tu ShellRoute
        bottomNavigationBar: NavigationBar( // thanh dieu huong duoi cung voi 3 tab
          selectedIndex: _currentIndex, // danh dau tab dang chon
          onDestinationSelected: _onTabTapped, // goi ham khi bam vao tab
          destinations: [
            NavigationDestination(
              icon:         Icon(_tabs[0].icon), // icon trang chu khong chon
              selectedIcon: Icon(_tabs[0].selectedIcon), // icon trang chu khi duoc chon
              label:        _tabs[0].label,
            ),
            NavigationDestination(
              icon:         _NotificationIcon(selectedIcon: _tabs[1].icon), // icon thong bao voi badge so chua doc
              selectedIcon: _NotificationIcon(selectedIcon: _tabs[1].selectedIcon),
              label:        _tabs[1].label,
            ),
            NavigationDestination(
              icon:         Icon(_tabs[2].icon), // icon cai dat khong chon
              selectedIcon: Icon(_tabs[2].selectedIcon), // icon cai dat khi duoc chon
              label:        _tabs[2].label,
            ),
          ],
        ),
      ),
    );
  }
}

// dinh nghia cau truc du lieu cho mot tab trong bottom navigation
class _TabDef {
  final String route; // duong dan route khi bam vao tab nay
  final IconData icon; // icon khi tab khong duoc chon
  final IconData selectedIcon; // icon khi tab duoc chon
  final String label; // nhan hien thi duoi icon

  const _TabDef({
    required this.route,
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

// ------------------------------------------------------------------
// _AppDrawer -- side drawer 50% man hinh: user info + menu + logout
// ------------------------------------------------------------------

// Icon tab Thong bao voi Badge hien so chua doc lay tu Riverpod provider
class _NotificationIcon extends ConsumerWidget {
  const _NotificationIcon({required this.selectedIcon});
  final IconData selectedIcon; // icon duoc truyen tu ben ngoai (co the la icon chon hoac khong chon)

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(soChuaDocProvider).valueOrNull ?? 0; // lay so thong bao chua doc, mac dinh 0
    if (count == 0) return Icon(selectedIcon); // neu khong co thong bao chua doc thi hien icon binh thuong
    return Badge( // neu co thong bao thi hien badge do tren icon
      label: Text(count > 9 ? '9+' : '$count'), // gioi han hien toi da 9+, tranh badge qua to
      child: Icon(selectedIcon),
    );
  }
}
