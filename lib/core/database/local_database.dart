// lib/core/database/local_database.dart
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._init();
  LocalDatabase._init();

  Database? _db;

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    return openDatabase(
      join(dir, 'gasmanager.db'),
      version: 10,
      onCreate: _create,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS cache_nhan_vien (
          server_id    INTEGER PRIMARY KEY,
          ma_nhan_vien TEXT NOT NULL,
          ho_ten       TEXT NOT NULL,
          ten_chuc_vu  TEXT,
          is_lai_xe    INTEGER DEFAULT 0,
          is_active    INTEGER DEFAULT 1
        )
      ''');
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS cache_tai_khoan (
          server_id     INTEGER PRIMARY KEY,
          ma_tai_khoan  TEXT NOT NULL,
          ten_tai_khoan TEXT NOT NULL,
          loai          TEXT NOT NULL,
          so_tai_khoan  TEXT,
          ngan_hang     TEXT,
          is_active     INTEGER DEFAULT 1
        )
      ''');
    }
    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS cache_mat_hang_vo (
          binh_server_id INTEGER PRIMARY KEY,
          vo_server_id   INTEGER NOT NULL
        )
      ''');
    }
    if (oldVersion < 8) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS cache_gia_ban_ngay (
          mat_hang_id INTEGER NOT NULL,
          ngay        TEXT    NOT NULL,
          gia_ban     REAL    NOT NULL DEFAULT 0,
          PRIMARY KEY (mat_hang_id, ngay)
        )
      ''');
    }
    if (oldVersion < 9) {
      await db.execute(
        'ALTER TABLE cache_xe ADD COLUMN nhan_vien_lai_xe_id INTEGER',
      );
      await db.execute(
        'ALTER TABLE cache_xe ADD COLUMN nhan_vien_phu_xe_id INTEGER',
      );
    }
    if (oldVersion < 10) {
      // App chỉ chạy online: xoá các bảng hàng đợi offline, chỉ giữ cache danh mục
      for (final t in const [
        'chuyen_xe_offline',
        'ban_hang_offline',
        'ban_hang_gas_du_local',
        'ban_hang_no_vo_local',
      ]) {
        await db.execute('DROP TABLE IF EXISTS $t');
      }
      // Bỏ khách hàng tạo offline chưa có server_id (không còn cơ chế đồng bộ lên)
      await db.execute('DELETE FROM khach_hang_local WHERE server_id IS NULL');
    }

  }

  Future<void> _create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE cache_mat_hang (
        server_id       INTEGER PRIMARY KEY,
        ma_mat_hang     TEXT NOT NULL,
        ten_mat_hang    TEXT NOT NULL,
        don_vi_tinh     TEXT,
        nha_cung_cap_id INTEGER,
        ten_nha_cc      TEXT,
        don_gia         REAL DEFAULT 0,
        is_active       INTEGER DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE cache_mat_hang_vo (
        binh_server_id INTEGER PRIMARY KEY,
        vo_server_id   INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE cache_gia_ban_ngay (
        mat_hang_id INTEGER NOT NULL,
        ngay        TEXT    NOT NULL,
        gia_ban     REAL    NOT NULL DEFAULT 0,
        PRIMARY KEY (mat_hang_id, ngay)
      )
    ''');
    await db.execute('''
      CREATE TABLE cache_nha_cung_cap (
        server_id  INTEGER PRIMARY KEY,
        ma_ncc     TEXT NOT NULL,
        ten_ncc    TEXT NOT NULL,
        is_active  INTEGER DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE cache_xe (
        server_id             INTEGER PRIMARY KEY,
        bien_so_xe            TEXT NOT NULL,
        loai_xe               TEXT,
        nhan_vien_lai_xe_id   INTEGER,
        nhan_vien_phu_xe_id   INTEGER,
        is_active             INTEGER DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE cache_nhan_vien (
        server_id    INTEGER PRIMARY KEY,
        ma_nhan_vien TEXT NOT NULL,
        ho_ten       TEXT NOT NULL,
        ten_chuc_vu  TEXT,
        is_lai_xe    INTEGER DEFAULT 0,
        is_active    INTEGER DEFAULT 1
      )
    ''');
    await db.execute('''
      CREATE TABLE khach_hang_local (
        local_id            INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id           INTEGER UNIQUE,
        ma_khach_hang       TEXT,
        ten_khach_hang      TEXT NOT NULL,
        dia_chi             TEXT,
        so_dien_thoai       TEXT,
        email               TEXT,
        latitude            REAL,
        longitude           REAL,
        is_active           INTEGER DEFAULT 1,
        is_offline_created  INTEGER DEFAULT 0,
        is_synced           INTEGER DEFAULT 1,
        created_at          TEXT,
        updated_at          TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE cache_tai_khoan (
        server_id     INTEGER PRIMARY KEY,
        ma_tai_khoan  TEXT NOT NULL,
        ten_tai_khoan TEXT NOT NULL,
        loai          TEXT NOT NULL,
        so_tai_khoan  TEXT,
        ngan_hang     TEXT,
        is_active     INTEGER DEFAULT 1
      )
    ''');
  }

  // ── Cache mặt hàng ────────────────────────────────────────────────────────

  Future<void> upsertMatHangList(List<Map<String, dynamic>> items) async {
    final d = await db;
    final batch = d.batch();
    for (final item in items) {
      batch.insert('cache_mat_hang', item,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getMatHangList() async {
    final d = await db;
    return d.query('cache_mat_hang', where: 'is_active = 1');
  }

  // ── Cache giá bán theo ngày ──────────────────────────────────────────────

  /// Ghi đè toàn bộ giá đã cấu hình của một ngày (ngay dạng yyyy-MM-dd).
  Future<void> upsertGiaBanNgay(
      String ngay, List<Map<String, dynamic>> items) async {
    final d = await db;
    final batch = d.batch();
    batch.delete('cache_gia_ban_ngay', where: 'ngay = ?', whereArgs: [ngay]);
    for (final item in items) {
      batch.insert('cache_gia_ban_ngay', item,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// Giá bán đã cấu hình của mặt hàng cho ngày; null nghĩa là chưa cấu hình.
  Future<double?> getGiaBanNgay(int matHangId, String ngay) async {
    final d = await db;
    final rows = await d.query(
      'cache_gia_ban_ngay',
      columns: ['gia_ban'],
      where: 'mat_hang_id = ? AND ngay = ?',
      whereArgs: [matHangId, ngay],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final gia = (rows.first['gia_ban'] as num?)?.toDouble() ?? 0;
    return gia > 0 ? gia : null;
  }

  // ── Cache mapping bình → vỏ ──────────────────────────────────────────────

  Future<void> upsertMatHangVoList(List<Map<String, dynamic>> items) async {
    final d = await db;
    final batch = d.batch();
    for (final item in items) {
      batch.insert('cache_mat_hang_vo', item,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<Map<int, int>> getBinhToVoMap() async {
    final d = await db;
    final rows = await d.query('cache_mat_hang_vo');
    return {
      for (final r in rows)
        (r['binh_server_id'] as int): (r['vo_server_id'] as int),
    };
  }

  // ── Cache nhà cung cấp ───────────────────────────────────────────────────

  Future<void> upsertNhaCungCapList(List<Map<String, dynamic>> items) async {
    final d = await db;
    final batch = d.batch();
    for (final item in items) {
      batch.insert('cache_nha_cung_cap', item,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getNhaCungCapList() async {
    final d = await db;
    return d.query('cache_nha_cung_cap', where: 'is_active = 1');
  }

  // ── Cache xe ─────────────────────────────────────────────────────────────

  Future<void> upsertXeList(List<Map<String, dynamic>> items) async {
    final d = await db;
    final batch = d.batch();
    for (final item in items) {
      batch.insert('cache_xe', item,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getXeList() async {
    final d = await db;
    return d.query('cache_xe', where: 'is_active = 1');
  }

  // ── Cache nhân viên (lái xe) ─────────────────────────────────────────────

  Future<void> upsertNhanVienList(List<Map<String, dynamic>> items) async {
    final d = await db;
    final batch = d.batch();
    for (final item in items) {
      batch.insert('cache_nhan_vien', item,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getNhanVienList() async {
    final d = await db;
    return d.query('cache_nhan_vien',
        where: 'is_active = 1 AND is_lai_xe = 1',
        orderBy: 'ho_ten ASC');
  }

  Future<void> clearNhanVienCache() async {
    final d = await db;
    await d.delete('cache_nhan_vien');
  }

  // ── Cache tài khoản công ty ──────────────────────────────────────────────

  Future<void> upsertTaiKhoanList(List<Map<String, dynamic>> items) async {
    final d = await db;
    final batch = d.batch();
    for (final item in items) {
      batch.insert('cache_tai_khoan', item,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// Trả tài khoản không phải tiền mặt (ngan-hang, ca-nhan) để dùng cho dropdown CK.
  Future<List<Map<String, dynamic>>> getTaiKhoanList() async {
    final d = await db;
    return d.query(
      'cache_tai_khoan',
      where: "is_active = 1 AND loai != 'tien-mat'",
      orderBy: 'ten_tai_khoan ASC',
    );
  }

  // ── Khách hàng ───────────────────────────────────────────────────────────

  Future<void> upsertKhachHangList(List<Map<String, dynamic>> items) async {
    final d = await db;
    final batch = d.batch();
    for (final item in items) {
      batch.insert('khach_hang_local', item,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getKhachHangList({String? search}) async {
    final d = await db;
    if (search == null || search.isEmpty) {
      return d.query('khach_hang_local',
          where: 'is_active = 1', orderBy: 'ten_khach_hang ASC');
    }
    return d.query(
      'khach_hang_local',
      where: 'is_active = 1 AND ten_khach_hang LIKE ?',
      whereArgs: ['%$search%'],
      orderBy: 'ten_khach_hang ASC',
    );
  }

}
