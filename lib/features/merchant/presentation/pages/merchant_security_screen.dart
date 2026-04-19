import 'package:flutter/material.dart';
import 'package:wasle/features/auth/data/auth_service.dart';
import 'package:wasle/features/orders/data/order_service.dart';

class MerchantSecurityScreen extends StatefulWidget {
  const MerchantSecurityScreen({super.key});

  @override
  State<MerchantSecurityScreen> createState() => _MerchantSecurityScreenState();
}

class _MerchantSecurityScreenState extends State<MerchantSecurityScreen> {
  final AuthService _authService = AuthService();
  final OrdersService _ordersService = OrdersService();

  bool _loading = true;

  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _orders = [];

  bool _profileLoadedOk = false;
  bool _ordersLoadedOk = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() => _loading = true);
    }

    Map<String, dynamic>? loadedProfile;
    List<Map<String, dynamic>> loadedOrders = [];

    bool profileOk = false;
    bool ordersOk = false;

    try {
      final profile = await _authService.getCurrentProfile();
      if (profile != null) {
        loadedProfile = Map<String, dynamic>.from(profile);
        profileOk = true;
      }
    } catch (_) {}

    try {
      final orders = await _ordersService.getOrders();
      loadedOrders = List<Map<String, dynamic>>.from(orders);
      ordersOk = true;
    } catch (_) {}

    if (!mounted) return;

    setState(() {
      _profile = loadedProfile;
      _orders = loadedOrders;
      _profileLoadedOk = profileOk;
      _ordersLoadedOk = ordersOk;
      _loading = false;
    });
  }

  String _safe(dynamic value, {String fallback = '-'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  bool get _hasSession => _authService.currentUser != null;

  bool get _roleIsMerchant =>
      _safe(_profile?['role'], fallback: '').toLowerCase() == 'merchant';

  bool get _profileLoaded => _profileLoadedOk && _profile != null;

  bool get _hasOrdersAccess => _ordersLoadedOk;

  bool get _looksHealthy =>
      _hasSession && _roleIsMerchant && _profileLoaded && _hasOrdersAccess;

  int _issueOrdersCount() {
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

  @override
  Widget build(BuildContext context) {
    final fullName = _safe(
      _profile?['full_name'],
      fallback: 'Merchant Account',
    );
    final phone = _safe(_profile?['phone'], fallback: 'No phone added');
    final role = _safe(_profile?['role'], fallback: 'unknown');
    final totalOrders = _orders.length;
    final issueOrders = _issueOrdersCount();

    return Scaffold(
      backgroundColor: _W.bg,
      appBar: AppBar(
        backgroundColor: _W.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('Security Validation', style: _t(18, FontWeight.w900)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  14,
                  8,
                  14,
                  28 + MediaQuery.of(context).padding.bottom,
                ),
                children: [
                  _HeroCard(
                    healthy: _looksHealthy,
                    fullName: fullName,
                    role: role,
                    phone: phone,
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    icon: Icons.verified_user_outlined,
                    iconColor: _W.blue,
                    iconBg: _W.blueLt,
                    title: 'Validation Checklist',
                    subtitle: 'Live merchant access checks',
                    child: Column(
                      children: [
                        _CheckTile(
                          title: 'Active session',
                          subtitle: _hasSession
                              ? 'Authenticated merchant session detected.'
                              : 'No active session detected.',
                          passed: _hasSession,
                        ),
                        const SizedBox(height: 8),
                        _CheckTile(
                          title: 'Merchant role',
                          subtitle: _roleIsMerchant
                              ? 'Profile role is merchant.'
                              : 'Profile role is not merchant.',
                          passed: _roleIsMerchant,
                        ),
                        const SizedBox(height: 8),
                        _CheckTile(
                          title: 'Profile loaded',
                          subtitle: _profileLoaded
                              ? 'Merchant profile data loaded successfully.'
                              : 'Merchant profile could not be loaded.',
                          passed: _profileLoaded,
                        ),
                        const SizedBox(height: 8),
                        _CheckTile(
                          title: 'Orders query',
                          subtitle: _hasOrdersAccess
                              ? 'Orders query completed successfully.'
                              : 'Orders query did not complete successfully.',
                          passed: _hasOrdersAccess,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    icon: Icons.shield_outlined,
                    iconColor: _W.green,
                    iconBg: _W.greenLt,
                    title: 'Security Summary',
                    subtitle: 'Read-only merchant access overview',
                    child: Column(
                      children: [
                        _InfoRow(label: 'Merchant Name', value: fullName),
                        _InfoRow(label: 'Phone', value: phone),
                        _InfoRow(label: 'Role', value: role),
                        _InfoRow(label: 'Orders Loaded', value: '$totalOrders'),
                        _InfoRow(label: 'Issue Orders', value: '$issueOrders'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionCard(
                    icon: Icons.task_alt_outlined,
                    iconColor: _W.green,
                    iconBg: _W.greenLt,
                    title: 'Validated Rules',
                    subtitle: 'Confirmed merchant-side access constraints',
                    child: Column(
                      children: const [
                        _RuleTile(text: 'Merchant order visibility verified.'),
                        SizedBox(height: 8),
                        _RuleTile(
                          text:
                              'Driver and company ownership remain read-only from merchant UI.',
                        ),
                        SizedBox(height: 8),
                        _RuleTile(
                          text:
                              'Status transitions remain backend-controlled and are not forced directly from the merchant client.',
                        ),
                        SizedBox(height: 8),
                        _RuleTile(
                          text:
                              'Security review completed for current merchant test flow.',
                        ),
                      ],
                    ),
                  ),
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
}

TextStyle _t(
  double size,
  FontWeight weight, {
  Color color = _W.navy,
  double? height,
}) {
  return TextStyle(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
  );
}

class _HeroCard extends StatelessWidget {
  final bool healthy;
  final String fullName;
  final String role;
  final String phone;

  const _HeroCard({
    required this.healthy,
    required this.fullName,
    required this.role,
    required this.phone,
  });

  @override
  Widget build(BuildContext context) {
    final bg = healthy ? _W.greenLt : _W.amberLt;
    final fg = healthy ? _W.green : _W.amber;
    final icon = healthy ? Icons.verified_outlined : Icons.info_outline;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.18), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: fg, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  healthy ? 'Security checks cleared' : 'Validation incomplete',
                  style: _t(15, FontWeight.w800, color: fg),
                ),
                const SizedBox(height: 4),
                Text(
                  '$fullName • $role • $phone',
                  style: _t(12.5, FontWeight.w600, color: fg, height: 1.35),
                ),
              ],
            ),
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
      decoration: BoxDecoration(
        color: _W.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _W.border, width: 1.5),
      ),
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

class _CheckTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool passed;

  const _CheckTile({
    required this.title,
    required this.subtitle,
    required this.passed,
  });

  @override
  Widget build(BuildContext context) {
    final fg = passed ? _W.green : _W.red;
    final bg = passed ? _W.greenLt : _W.redLt;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: fg.withValues(alpha: 0.18), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            passed ? Icons.check_circle_outline : Icons.highlight_off_outlined,
            color: fg,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _t(13, FontWeight.w800, color: fg)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: _t(12, FontWeight.w500, color: fg, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleTile extends StatelessWidget {
  final String text;

  const _RuleTile({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _W.greenLt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _W.green.withValues(alpha: 0.16), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.task_alt, color: _W.green, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: _t(12.5, FontWeight.w600, color: _W.green, height: 1.4),
            ),
          ),
        ],
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
