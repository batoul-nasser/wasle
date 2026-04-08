import 'package:flutter/material.dart';

import 'package:wasle/ui/auth/auth_controller.dart';

import 'services/order_service.dart';

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
  static const slate = Color(0xFF94A3B8);
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

class MerchantSecurityValidationScreen extends StatefulWidget {
  const MerchantSecurityValidationScreen({super.key});

  @override
  State<MerchantSecurityValidationScreen> createState() =>
      _MerchantSecurityValidationScreenState();
}

class _MerchantSecurityValidationScreenState
    extends State<MerchantSecurityValidationScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final auth = await authController.loadMerchantSecuritySnapshot();
    final data = await orderService.loadMerchantSecuritySnapshot();
    return {
      ...auth,
      ...data,
    };
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _W.bg,
      appBar: AppBar(
        backgroundColor: _W.bg,
        elevation: 0,
        centerTitle: false,
        foregroundColor: _W.navy,
        title: Text(
          'Security & Validation',
          style: _t(20, FontWeight.w800),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: _W.blue),
            );
          }

          final data = snapshot.data ?? const <String, dynamic>{};
          final checks = _buildChecks(data);

          return RefreshIndicator(
            color: _W.blue,
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
              children: [
                _SummaryCard(data: data),
                const SizedBox(height: 14),
                Text(
                  'Validation checks',
                  style: _t(16, FontWeight.w800),
                ),
                const SizedBox(height: 10),
                ...checks.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CheckCard(
                      icon: item.icon,
                      color: item.color,
                      bg: item.bg,
                      title: item.title,
                      description: item.description,
                      badge: item.badge,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _ManualNoteCard(data: data),
              ],
            ),
          );
        },
      ),
    );
  }

  List<_CheckItem> _buildChecks(Map<String, dynamic> data) {
    final profileRole = (data['profileRole']?.toString() ?? '').trim();
    final membershipCount = (data['merchantMembershipCount'] as int?) ?? 0;
    final merchantId = (data['merchantId']?.toString() ?? '').trim();
    final branchId = (data['branchId']?.toString() ?? '').trim();
    final visibleMerchantIds =
        (data['visibleMerchantIds'] as List?)?.cast<String>() ?? const <String>[];

    final hasSession = data['hasSession'] == true;
    final isMerchantRole = profileRole == 'merchant';
    final hasMembership = membershipCount > 0;
    final hasMerchantContext = merchantId.isNotEmpty;
    final onlyOwnOrders = hasMerchantContext &&
        (visibleMerchantIds.isEmpty ||
            (visibleMerchantIds.length == 1 && visibleMerchantIds.first == merchantId));

    return [
      _CheckItem.passFail(
        condition: hasSession,
        passTitle: 'Authenticated merchant session found',
        failTitle: 'No authenticated session found',
        passDescription: 'The app found an active signed-in user before loading merchant data.',
        failDescription: 'Sign in with a merchant account before running validation.',
      ),
      _CheckItem.passFail(
        condition: isMerchantRole,
        passTitle: 'profiles.role is merchant',
        failTitle: 'profiles.role is not merchant',
        passDescription: 'Role-aware entry is aligned with the merchant flow.',
        failDescription: 'The current account is not tagged as merchant in profiles.',
      ),
      _CheckItem.passFail(
        condition: hasMembership,
        passTitle: 'merchant_users membership exists',
        failTitle: 'merchant_users membership missing',
        passDescription: 'The current user is linked to a merchant account.',
        failDescription: 'Merchant membership could not be verified for this user.',
      ),
      _CheckItem.passFail(
        condition: hasMerchantContext,
        passTitle: 'Merchant context resolved',
        failTitle: 'Merchant context not resolved',
        passDescription: branchId.isNotEmpty
            ? 'merchant_id and branch_id were resolved for order creation.'
            : 'merchant_id was resolved. branch_id is empty or optional for this account.',
        failDescription: 'The app could not resolve merchant_id for the current account.',
      ),
      _CheckItem.passFail(
        condition: onlyOwnOrders,
        passTitle: 'Visible orders are scoped to the merchant',
        failTitle: 'Order list may not be fully scoped',
        passDescription: 'The current in-app query is filtered by merchant_id and only returned this merchant scope.',
        failDescription: 'The visible order set needs review. Confirm the query and backend RLS policy.',
      ),
      _CheckItem.partial(
        title: 'Driver/company info stays read-only in merchant UI',
        description:
            'The merchant app shows assignment details but does not expose direct edit controls for driver or company data.',
      ),
      _CheckItem.partial(
        title: 'Backend status-transition enforcement still needs live verification',
        description:
            'Client-side guards are in place, but final proof still requires testing against Supabase policies / functions with real accounts.',
      ),
    ];
  }
}

class _SummaryCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _SummaryCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final merchantId = data['merchantId']?.toString() ?? '—';
    final branchId = data['branchId']?.toString() ?? '—';
    final profileRole = data['profileRole']?.toString() ?? '—';
    final ordersCount = data['ordersCount']?.toString() ?? '0';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _W.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _W.border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Current merchant snapshot', style: _t(16, FontWeight.w800)),
          const SizedBox(height: 10),
          _SummaryRow(label: 'Role', value: profileRole),
          _SummaryRow(label: 'Merchant ID', value: merchantId),
          _SummaryRow(label: 'Branch ID', value: branchId),
          _SummaryRow(label: 'Visible orders', value: ordersCount),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: _t(13, FontWeight.w700, color: _W.gray),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: _t(13, FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bg;
  final String title;
  final String description;
  final String badge;

  const _CheckCard({
    required this.icon,
    required this.color,
    required this.bg,
    required this.title,
    required this.description,
    required this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _W.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _W.border, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: _t(14, FontWeight.w800),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badge,
                        style: _t(11, FontWeight.w800, color: color),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: _t(13, FontWeight.w500, color: _W.gray, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualNoteCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _ManualNoteCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _W.amberLt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _W.border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Still required outside the app',
            style: _t(14, FontWeight.w800, color: _W.amber),
          ),
          const SizedBox(height: 8),
          Text(
            'Run one cross-account test to confirm merchant A cannot read merchant B orders. Also verify that forbidden status changes are blocked server-side, not only hidden in the UI.',
            style: _t(13, FontWeight.w600, color: _W.navy, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _CheckItem {
  final IconData icon;
  final Color color;
  final Color bg;
  final String title;
  final String description;
  final String badge;

  const _CheckItem({
    required this.icon,
    required this.color,
    required this.bg,
    required this.title,
    required this.description,
    required this.badge,
  });

  factory _CheckItem.passFail({
    required bool condition,
    required String passTitle,
    required String failTitle,
    required String passDescription,
    required String failDescription,
  }) {
    return _CheckItem(
      icon: condition ? Icons.check_circle_outline : Icons.close,
      color: condition ? _W.green : _W.red,
      bg: condition ? _W.greenLt : _W.redLt,
      title: condition ? passTitle : failTitle,
      description: condition ? passDescription : failDescription,
      badge: condition ? 'PASS' : 'FAIL',
    );
  }

  factory _CheckItem.partial({
    required String title,
    required String description,
  }) {
    return _CheckItem(
      icon: Icons.info_outline,
      color: _W.amber,
      bg: _W.amberLt,
      title: title,
      description: description,
      badge: 'MANUAL',
    );
  }
}
