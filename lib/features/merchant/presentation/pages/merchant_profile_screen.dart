import 'package:flutter/material.dart';
import 'package:wasle/core/ui/ui.dart';
import 'package:wasle/features/auth/data/auth_service.dart';

class MerchantProfileScreen extends StatefulWidget {
  const MerchantProfileScreen({super.key});

  @override
  State<MerchantProfileScreen> createState() => _MerchantProfileScreenState();
}

class _MerchantProfileScreenState extends State<MerchantProfileScreen> {
  final AuthService _authService = AuthService();

  Map<String, dynamic>? profile;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await _authService.getCurrentProfile();
      if (!mounted) return;

      setState(() {
        profile = data;
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  Future<void> _logout() async {
    await _authService.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/welcome', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Merchant Profile')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: [
                InfoCard(
                  title: 'Full Name',
                  value: profile?['full_name']?.toString() ?? '-',
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: AppSpacing.md),
                InfoCard(
                  title: 'Phone',
                  value: profile?['phone']?.toString() ?? '-',
                  icon: Icons.phone_outlined,
                ),
                const SizedBox(height: AppSpacing.md),
                InfoCard(
                  title: 'Role',
                  value: profile?['role']?.toString() ?? 'merchant',
                  icon: Icons.storefront_outlined,
                ),
                const SizedBox(height: AppSpacing.xl),
                SecondaryButton(
                  label: 'Logout',
                  onPressed: _logout,
                  icon: Icons.logout,
                ),
              ],
            ),
    );
  }
}
