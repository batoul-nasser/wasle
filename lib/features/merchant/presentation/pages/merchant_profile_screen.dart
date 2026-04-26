import 'package:flutter/material.dart';
import 'package:wasle/features/auth/data/auth_service.dart';
import 'package:wasle/features/merchant/presentation/pages/merchant_about_wasle_screen.dart';
import 'package:wasle/features/merchant/presentation/pages/merchant_issues_screen.dart';
import 'package:wasle/features/merchant/presentation/pages/merchant_notifications_screen.dart';
import 'package:wasle/features/merchant/presentation/pages/merchant_security_screen.dart';
import 'package:wasle/features/orders/data/order_service.dart';

class MerchantProfileScreen extends StatefulWidget {
  const MerchantProfileScreen({super.key});

  @override
  State<MerchantProfileScreen> createState() => _MerchantProfileScreenState();
}

class _MerchantProfileScreenState extends State<MerchantProfileScreen> {
  final AuthService _authService = AuthService();
  final OrdersService _ordersService = OrdersService();

  bool _loading = true;
  bool _logoutLoading = false;

  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _orders = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _authService.getCurrentProfile(),
        _ordersService.getOrders(),
      ]);

      if (!mounted) return;

      setState(() {
        _profile = results[0] as Map<String, dynamic>?;
        _orders = List<Map<String, dynamic>>.from(results[1] as List);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    if (_logoutLoading) return;

    setState(() => _logoutLoading = true);

    try {
      await _authService.signOut();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/welcome', (_) => false);
    } catch (_) {
      if (!mounted) return;
      _showSnack('Failed to sign out. Please try again.');
      setState(() => _logoutLoading = false);
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MerchantNotificationsScreen()),
    );
    await _load();
  }

  Future<void> _openIssues() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MerchantIssuesScreen()),
    );
    await _load();
  }

  Future<void> _openSecurity() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MerchantSecurityScreen()),
    );
    await _load();
  }

  Future<void> _openAboutWasle() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MerchantAboutWasleScreen()),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  int _countDelivered() {
    return _orders.where((o) {
      final s = _safe(o['status']).toLowerCase();
      return s == 'delivered' || s == 'completed';
    }).length;
  }

  int _countIssues() {
    return _orders.where((o) {
      final s = _safe(o['status']).toLowerCase();
      return s == 'failed' ||
          s == 'cancelled' ||
          s == 'returning' ||
          s == 'returning_to_store' ||
          s == 'returned_to_store' ||
          s == 'customer_not_available';
    }).length;
  }

  int _countActive() {
    return _orders.where((o) {
      final s = _safe(o['status']).toLowerCase();
      return s != 'delivered' &&
          s != 'completed' &&
          s != 'failed' &&
          s != 'cancelled' &&
          s != 'returning' &&
          s != 'returning_to_store' &&
          s != 'returned_to_store' &&
          s != 'customer_not_available';
    }).length;
  }

  String _safe(dynamic value, {String fallback = '-'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  @override
  Widget build(BuildContext context) {
    final fullName = _safe(
      _profile?['full_name'],
      fallback: 'Merchant Account',
    );
    final phone = _safe(_profile?['phone'], fallback: 'No phone added');
    final role = _safe(_profile?['role'], fallback: 'merchant');
    final status = _safe(_profile?['status'], fallback: 'active');

    final total = _orders.length;
    final delivered = _countDelivered();
    final issues = _countIssues();
    final active = _countActive();

    return Scaffold(
      backgroundColor: _W.bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  14,
                  0,
                  14,
                  28 + MediaQuery.of(context).padding.bottom,
                ),
                children: [
                  _TopNav(
                    onNotifications: _openNotifications,
                    onSecurity: _openSecurity,
                  ),
                  const SizedBox(height: 4),
                  _HeroCard(
                    title: fullName,
                    subtitle: 'Merchant workspace',
                    phone: phone,
                    role: role,
                    status: status,
                    total: total,
                    active: active,
                    issues: issues,
                  ),
                  const SizedBox(height: 14),
                  _StatsRow(total: total, delivered: delivered, issues: issues),
                  const SizedBox(height: 14),
                  _SectionCard(
                    icon: Icons.tune_outlined,
                    iconColor: _W.blue,
                    iconBg: _W.blueLt,
                    title: 'Account Settings',
                    subtitle: 'Manage merchant tools and app access',
                    child: Column(
                      children: [
                        _SettingTile(
                          icon: Icons.notifications_outlined,
                          iconColor: _W.amber,
                          iconBg: _W.amberLt,
                          title: 'Notifications',
                          subtitle: 'Recent order updates and delivery alerts',
                          onTap: _openNotifications,
                        ),
                        const SizedBox(height: 8),
                        _SettingTile(
                          icon: Icons.lock_outline,
                          iconColor: _W.blue,
                          iconBg: _W.blueLt,
                          title: 'Security',
                          subtitle: 'Validate merchant access and permissions',
                          onTap: _openSecurity,
                        ),
                        const SizedBox(height: 8),
                        _SettingTile(
                          icon: Icons.inventory_2_outlined,
                          iconColor: _W.green,
                          iconBg: _W.greenLt,
                          title: 'Issues Center',
                          subtitle: 'Review failed and return-flow orders',
                          onTap: _openIssues,
                        ),
                        const SizedBox(height: 8),
                        _SettingTile(
                          icon: Icons.info_outline,
                          iconColor: _W.slate,
                          iconBg: _W.slateLt,
                          title: 'About Wasle',
                          subtitle:
                              'App information, support and merchant guide',
                          onTap: _openAboutWasle,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    icon: Icons.info_outline,
                    iconColor: _W.slate,
                    iconBg: _W.slateLt,
                    title: 'Account Summary',
                    subtitle: 'Read-only merchant overview',
                    child: Column(
                      children: [
                        _InfoRow(label: 'Full Name', value: fullName),
                        _InfoRow(label: 'Phone', value: phone),
                        _InfoRow(label: 'Role', value: role),
                        _InfoRow(label: 'Status', value: status),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SignOutButton(loading: _logoutLoading, onTap: _logout),
                ],
              ),
            ),
    );
  }
}

class _W {
  _W._();

  static const bg = Color(0xFFF4F7FF);
  static const white = Color(0xFFFFFFFF);
  static const blue = Color(0xFF1A56DB);
  static const blueDark = Color(0xFF1044C4);
  static const blueLt = Color(0xFFEBF0FD);
  static const navy = Color(0xFF0B1D3F);
  static const gray = Color(0xFF6B7A99);
  static const border = Color(0xFFDDE5F7);
  static const green = Color(0xFF0BA360);
  static const greenLt = Color(0xFFE6F7EF);
  static const red = Color(0xFFE53054);
  static const redLt = Color(0xFFFDEAED);
  static const amber = Color(0xFFD4800A);
  static const amberLt = Color(0xFFFEF4E2);
  static const slate = Color(0xFF94A3B8);
  static const slateLt = Color(0xFFF1F4FC);
  static const white13 = Color(0x22FFFFFF);
  static const white20 = Color(0x33FFFFFF);
  static const white70 = Color(0xB3FFFFFF);
  static const white07 = Color(0x12FFFFFF);
  static const white03 = Color(0x08FFFFFF);
}

TextStyle _t(
  double size,
  FontWeight w, {
  Color color = _W.navy,
  double? height,
  double? spacing,
}) {
  return TextStyle(
    fontSize: size,
    fontWeight: w,
    color: color,
    height: height,
    letterSpacing: spacing,
  );
}

BoxDecoration _cardDecor({double radius = 20}) {
  return BoxDecoration(
    color: _W.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: _W.border, width: 1.5),
  );
}

class _TopNav extends StatelessWidget {
  final VoidCallback onNotifications;
  final VoidCallback onSecurity;

  const _TopNav({required this.onNotifications, required this.onSecurity});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _W.blue,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.local_shipping_outlined,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          RichText(
            text: TextSpan(
              style: _t(22, FontWeight.w900, spacing: -0.5),
              children: const [
                TextSpan(text: 'wa'),
                TextSpan(
                  text: 'sle',
                  style: TextStyle(color: _W.blue),
                ),
              ],
            ),
          ),
          const Spacer(),
          _NavIconBtn(
            icon: Icons.notifications_outlined,
            hasDot: true,
            onTap: onNotifications,
          ),
          const SizedBox(width: 8),
          _NavIconBtn(icon: Icons.shield_outlined, onTap: onSecurity),
        ],
      ),
    );
  }
}

class _NavIconBtn extends StatelessWidget {
  final IconData icon;
  final bool hasDot;
  final VoidCallback? onTap;

  const _NavIconBtn({required this.icon, this.hasDot = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 38,
              height: 38,
              decoration: _cardDecor(radius: 12),
              child: Icon(icon, size: 18, color: _W.navy),
            ),
          ),
        ),
        if (hasDot)
          Positioned(
            top: 7,
            right: 7,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _W.red,
                shape: BoxShape.circle,
                border: Border.all(color: _W.white, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String phone;
  final String role;
  final String status;
  final int total;
  final int active;
  final int issues;

  const _HeroCard({
    required this.title,
    required this.subtitle,
    required this.phone,
    required this.role,
    required this.status,
    required this.total,
    required this.active,
    required this.issues,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_W.blueDark, _W.blue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 130,
              height: 130,
              decoration: const BoxDecoration(
                color: _W.white07,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -24,
            right: 24,
            child: Container(
              width: 74,
              height: 74,
              decoration: const BoxDecoration(
                color: _W.white03,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MERCHANT PROFILE',
                style: _t(10, FontWeight.w700, color: _W.white70, spacing: 1.4),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: _W.white13,
                      border: Border.all(color: _W.white20, width: 2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.storefront_outlined,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: _t(22, FontWeight.w900, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: _t(13, FontWeight.w500, color: _W.white70),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          phone,
                          style: _t(13, FontWeight.w500, color: _W.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _W.white13,
                  border: Border.all(color: _W.white20),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      size: 12,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Role · ${role.toUpperCase()} • ${status.toUpperCase()}',
                      style: _t(12, FontWeight.w700, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _HeroChip(
                    icon: Icons.inventory_2_outlined,
                    label: '$total orders total',
                  ),
                  _HeroChip(
                    icon: Icons.local_shipping_outlined,
                    label: '$active active now',
                  ),
                  _HeroChip(icon: Icons.error_outline, label: '$issues issues'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _W.white13,
        border: Border.all(color: _W.white20),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 6),
          Text(label, style: _t(12, FontWeight.w700, color: Colors.white)),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final int total;
  final int delivered;
  final int issues;

  const _StatsRow({
    required this.total,
    required this.delivered,
    required this.issues,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            value: '$total',
            label: 'Total Orders',
            valueColor: _W.blue,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            value: '$delivered',
            label: 'Delivered',
            valueColor: _W.green,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            value: '$issues',
            label: 'Issues',
            valueColor: _W.red,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color valueColor;

  const _StatCard({
    required this.value,
    required this.label,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: _cardDecor(radius: 16),
      child: Column(
        children: [
          Text(value, style: _t(24, FontWeight.w900, color: valueColor)),
          const SizedBox(height: 4),
          Text(
            label,
            style: _t(11, FontWeight.w600, color: _W.gray),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecor(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 17, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: _t(15, FontWeight.w800)),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: _t(12, FontWeight.w500, color: _W.gray),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: _W.border),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _W.bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: iconColor.withValues(alpha: 0.06),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _W.border, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: _t(14, FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: _t(
                        12,
                        FontWeight.w500,
                        color: _W.gray,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: _W.slate,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: _t(12, FontWeight.w600, color: _W.gray)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: _t(13, FontWeight.w700),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _SignOutButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;

  const _SignOutButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _W.redLt,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: _W.red.withValues(alpha: 0.10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _W.red.withValues(alpha: 0.25),
              width: 1.5,
            ),
          ),
          child: loading
              ? const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: _W.red,
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.logout_outlined, color: _W.red, size: 19),
                    const SizedBox(width: 8),
                    Text(
                      'Sign Out',
                      style: _t(14, FontWeight.w800, color: _W.red),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
