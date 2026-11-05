// lib/features/home/presentation/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/user_info_provider.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/menu_icon_mapper.dart';
import '../../../../features/menu/providers/menu_provider.dart';
import '../../../../features/auth/data/auth_models.dart';
import '../../../../features/thong_bao/presentation/providers/thong_bao_provider.dart';
import '../../../../core/services/background_polling_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkNotifications());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkNotifications();
    }
  }

  // Kiem tra so thong bao chua doc moi khi vao/quay lai man hinh Home,
  // hien local notification banner neu co thong bao moi ke tu lan kiem tra truoc.
  Future<void> _checkNotifications() async {
    const storage = FlutterSecureStorage();
    final userIdStr = await storage.read(key: 'user_id');
    final userId = int.tryParse(userIdStr ?? '');
    if (userId == null || !mounted) return;

    try {
      await BackgroundPollingService.checkAndNotifyIfIncreased(userId);
      if (mounted) ref.invalidate(soChuaDocProvider);
    } catch (_) {
      // best-effort — khong lam gian doan trai nghiem Home neu API loi
    }
  }

  @override
  Widget build(BuildContext context) {
    final menusAsync = ref.watch(menuProvider);
    final userAsync  = ref.watch(userInfoProvider);
    final soChuaDoc  = ref.watch(soChuaDocProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(menuProvider);
        ref.invalidate(userInfoProvider);
        ref.invalidate(soChuaDocProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeaderSection(userAsync: userAsync, soChuaDoc: soChuaDoc),
            _WhiteContent(menusAsync: menusAsync, userAsync: userAsync),
          ],
        ),
      ),
    );
  }
}

// ─── Header Section (gradient + user greeting) ─────────────────────────────

class _HeaderSection extends StatelessWidget {
  final AsyncValue<UserInfo> userAsync;
  final AsyncValue<int> soChuaDoc;

  const _HeaderSection({required this.userAsync, required this.soChuaDoc});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Chào buổi sáng';
    if (h < 18) return 'Chào buổi chiều';
    return 'Chào buổi tối';
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Stack(
      children: [
        // Ảnh nền nhà máy gas — phủ kín header
        Positioned.fill(
          child: Image.asset(
            'assets/images/bg-login.jpg',
            fit: BoxFit.cover,
          ),
        ),
        // Overlay tối (đậm dần xuống dưới) để chữ trắng đọc rõ
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF00695C).withValues(alpha: 0.55),
                  const Color(0xFF004D40).withValues(alpha: 0.75),
                ],
              ),
            ),
          ),
        ),
        // Nội dung header
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Space cho status bar + transparent AppBar
            SizedBox(height: topPad + kToolbarHeight),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 26),
              child: userAsync.when(
                loading: () => const SizedBox(height: 64),
                error: (_, __) => _UserRow(
                  context: context,
                  info: null,
                  greeting: _greeting(),
                  soChuaDoc: soChuaDoc,
                ),
                data: (info) => _UserRow(
                  context: context,
                  info: info,
                  greeting: _greeting(),
                  soChuaDoc: soChuaDoc,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _UserRow extends StatelessWidget {
  final BuildContext context;
  final UserInfo? info;
  final String greeting;
  final AsyncValue<int> soChuaDoc;

  const _UserRow({
    required this.context,
    required this.info,
    required this.greeting,
    required this.soChuaDoc,
  });

  @override
  Widget build(BuildContext outerContext) {
    final name      = info?.fullName ?? 'Người dùng';
    final avatarUrl = info?.avatarUrl;
    final baseUrl   = AppConstants.staticBaseUrl;

    // Tạo chữ viết tắt từ họ tên (tối đa 2 chữ cái đầu)
    final words    = name.trim().split(' ').where((w) => w.isNotEmpty).toList();
    final initials = words.length >= 2
        ? '${words.first[0]}${words.last[0]}'.toUpperCase()
        : name.isNotEmpty
            ? name[0].toUpperCase()
            : 'GS';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Avatar — tap → màn hình thông tin tài khoản
        GestureDetector(
          onTap: () => context.go(AppRoutes.thongTinTaiKhoan),
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 2),
              color: Colors.white.withValues(alpha: 0.2),
            ),
            child: ClipOval(
              child: avatarUrl != null && avatarUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: '$baseUrl$avatarUrl',
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _InitialsWidget(initials: initials),
                    )
                  : _InitialsWidget(initials: initials),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Lời chào + tên — tap → màn hình thông tin tài khoản
        Expanded(
          child: GestureDetector(
            onTap: () => context.go(AppRoutes.thongTinTaiKhoan),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        greeting,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white60, size: 20),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Bell thông báo
        _NotificationBell(soChuaDoc: soChuaDoc, context: context),
      ],
    );
  }
}

class _InitialsWidget extends StatelessWidget {
  final String initials;
  const _InitialsWidget({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white.withValues(alpha: 0.15),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  final AsyncValue<int> soChuaDoc;
  final BuildContext context;

  const _NotificationBell({required this.soChuaDoc, required this.context});

  @override
  Widget build(BuildContext outerContext) {
    final count = soChuaDoc.valueOrNull ?? 0;
    return GestureDetector(
      onTap: () => context.go(AppRoutes.thongBaoList),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_outlined,
              color: Colors.white,
              size: 22,
            ),
          ),
          if (count > 0)
            Positioned(
              top: -1,
              right: -1,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Color(0xFFFF5722),
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── White Content Area (rounded top, trắng đè lên gradient) ───────────────

class _WhiteContent extends StatelessWidget {
  final AsyncValue<List<MenuInfo>> menusAsync;
  final AsyncValue<UserInfo> userAsync;

  const _WhiteContent({required this.menusAsync, required this.userAsync});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF5F6FA),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          _StatsRow(userAsync: userAsync),
          const SizedBox(height: 24),
          _MenuSection(menusAsync: menusAsync),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── Stats Row (2 thẻ mini) ─────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final AsyncValue<UserInfo> userAsync;
  const _StatsRow({required this.userAsync});

  String _roleLabel(String roleCode) => switch (roleCode.toLowerCase()) {
        'admin'    => 'Quản trị viên',
        'quan-ly'  => 'Quản lý',
        'ke-toan'  => 'Kế toán',
        'lai-xe'   => 'Lái xe',
        'giam-doc' => 'Giám đốc',
        _          => roleCode.isNotEmpty ? roleCode : 'Người dùng',
      };

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final info = userAsync.valueOrNull;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              icon: Icons.badge_outlined,
              label: 'Vai trò',
              value: info != null ? _roleLabel(info.roleCode) : '...',
              iconColor: const Color(0xFF00695C),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              icon: Icons.calendar_today_outlined,
              label: 'Hôm nay',
              value: _formatDate(DateTime.now()),
              iconColor: const Color(0xFF1565C0),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF718096),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A202C),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Menu Section: 4 cột + phần "Chức năng khác" (horizontal scroll) ────────

class _MenuSection extends StatelessWidget {
  final AsyncValue<List<MenuInfo>> menusAsync;
  const _MenuSection({required this.menusAsync});

  @override
  Widget build(BuildContext context) {
    return menusAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text('Không tải được menu: $e',
              style: const TextStyle(color: Color(0xFFA0AEC0))),
        ),
      ),
      data: (menus) {
        if (menus.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(40),
            child: Center(
              child: Text('Không có chức năng nào',
                  style: TextStyle(color: Color(0xFFA0AEC0))),
            ),
          );
        }

        // 8 menu đầu hiển thị dạng grid 4 cột, phần còn lại scroll ngang
        final primary   = menus.take(8).toList();
        final secondary = menus.skip(8).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tiêu đề
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Chức năng',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A202C),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Grid 4 cột — icon tròn
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: primary.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 4,
                  childAspectRatio: 0.82,
                ),
                itemBuilder: (ctx, i) => _QuickActionItem(
                  menu: primary[i],
                  index: i,
                  onTap: () => ctx.go(primary[i].mobileRoute!),
                ),
              ),
            ),

            // "Chức năng khác" — horizontal scroll nếu có > 8 menu
            if (secondary.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Chức năng khác',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A202C),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 104,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: secondary.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (ctx, i) => _SecondaryMenuItem(
                    menu: secondary[i],
                    index: i + 8,
                    onTap: () => ctx.go(secondary[i].mobileRoute!),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

// Icon tròn 4 cột (kiểu banking app)
class _QuickActionItem extends StatelessWidget {
  final MenuInfo menu;
  final int index;
  final VoidCallback onTap;

  const _QuickActionItem({
    required this.menu,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = kMenuCardColors[index % kMenuCardColors.length];
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              mapMenuIcon(menu.menuCode),
              size: 26,
              color: color,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            menu.menuName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF2D3748),
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

// Card ngang dùng cho phần "Chức năng khác"
class _SecondaryMenuItem extends StatelessWidget {
  final MenuInfo menu;
  final int index;
  final VoidCallback onTap;

  const _SecondaryMenuItem({
    required this.menu,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = kMenuCardColors[index % kMenuCardColors.length];
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 90,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(mapMenuIcon(menu.menuCode), size: 28, color: color),
            const SizedBox(height: 6),
            Text(
              menu.menuName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Color(0xFF2D3748),
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
