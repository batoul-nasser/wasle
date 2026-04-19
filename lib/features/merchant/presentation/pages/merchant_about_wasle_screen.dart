import 'package:flutter/material.dart';

class MerchantAboutWasleScreen extends StatelessWidget {
  const MerchantAboutWasleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _W.bg,
      appBar: AppBar(
        backgroundColor: _W.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('About Wasle', style: _t(18, FontWeight.w900)),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          14,
          8,
          14,
          28 + MediaQuery.of(context).padding.bottom,
        ),
        children: const [
          _HeroCard(),
          SizedBox(height: 12),
          _InfoSection(),
          SizedBox(height: 12),
          _SupportSection(),
          SizedBox(height: 12),
          _VersionSection(),
        ],
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
  static const amber = Color(0xFFD4800A);
  static const amberLt = Color(0xFFFEF4E2);
  static const slate = Color(0xFF94A3B8);
  static const white13 = Color(0x22FFFFFF);
  static const white20 = Color(0x33FFFFFF);
  static const white70 = Color(0xB3FFFFFF);
  static const white07 = Color(0x12FFFFFF);
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

class _HeroCard extends StatelessWidget {
  const _HeroCard();

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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ABOUT WASLE',
                style: _t(10, FontWeight.w700, color: _W.white70, spacing: 1.4),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: _W.white13,
                      border: Border.all(color: _W.white20, width: 2),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.local_shipping_outlined,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Wasle Merchant',
                          style: _t(22, FontWeight.w900, color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manage deliveries, monitor issues, and track merchant operations in one place.',
                          style: _t(
                            13,
                            FontWeight.w500,
                            color: _W.white70,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecor(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.info_outline,
            iconColor: _W.blue,
            iconBg: _W.blueLt,
            title: 'What is Wasle?',
            subtitle: 'Merchant app overview',
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: _W.border),
          const SizedBox(height: 14),
          Text(
            'Wasle helps merchants create delivery orders, monitor active shipments, review exceptions, and follow order timelines from one workspace.',
            style: _t(13, FontWeight.w500, color: _W.gray, height: 1.55),
          ),
          const SizedBox(height: 12),
          const _BulletLine(text: 'Create and track delivery orders'),
          const _BulletLine(text: 'Review failed and return-flow issues'),
          const _BulletLine(text: 'Monitor notifications and order history'),
          const _BulletLine(
            text: 'Validate merchant access and account status',
          ),
        ],
      ),
    );
  }
}

class _SupportSection extends StatelessWidget {
  const _SupportSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecor(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.support_agent_outlined,
            iconColor: _W.green,
            iconBg: _W.greenLt,
            title: 'Support',
            subtitle: 'When to contact the ops team',
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: _W.border),
          const SizedBox(height: 14),
          const _BulletLine(
            text: 'Assignment delays or company acceptance problems',
          ),
          const _BulletLine(
            text:
                'Unexpected delivery status issues or missing timeline events',
          ),
          const _BulletLine(
            text: 'Merchant account access or permissions validation',
          ),
          const _BulletLine(
            text: 'Order cancellation or exception flow follow-up',
          ),
        ],
      ),
    );
  }
}

class _VersionSection extends StatelessWidget {
  const _VersionSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecor(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            icon: Icons.verified_outlined,
            iconColor: _W.amber,
            iconBg: _W.amberLt,
            title: 'App Information',
            subtitle: 'Static release info',
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: _W.border),
          const SizedBox(height: 14),
          _InfoRow(label: 'Product', value: 'Wasle Merchant'),
          _InfoRow(label: 'Module', value: 'Merchant Workspace'),
          _InfoRow(label: 'Build', value: 'Internal Preview'),
          _InfoRow(label: 'Status', value: 'Operational'),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
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
              Text(subtitle, style: _t(12, FontWeight.w500, color: _W.gray)),
            ],
          ),
        ),
      ],
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
            width: 110,
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

class _BulletLine extends StatelessWidget {
  final String text;

  const _BulletLine({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 7, color: _W.slate),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: _t(12.5, FontWeight.w500, color: _W.gray, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
