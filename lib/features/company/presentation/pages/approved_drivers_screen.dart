import 'package:flutter/material.dart';

import 'package:wasle/core/ui/ui.dart';
import 'package:wasle/features/auth/data/auth_service.dart';

class ApprovedDriversScreen extends StatefulWidget {
  const ApprovedDriversScreen({super.key});

  @override
  State<ApprovedDriversScreen> createState() => _ApprovedDriversScreenState();
}

class _ApprovedDriversScreenState extends State<ApprovedDriversScreen> {
  final AuthService _authService = AuthService();

  bool isLoading = true;
  String? errorText;
  List<Map<String, dynamic>> approvedDrivers = [];

  @override
  void initState() {
    super.initState();
    _loadApprovedDrivers();
  }

  Future<void> _loadApprovedDrivers() async {
    try {
      final data = await _authService.getDriverRequestsForCurrentCompany();

      final approved = data.where((request) {
        final requestStatus = request['request_status']?.toString().toLowerCase();
        return requestStatus == 'approved';
      }).toList();

      if (!mounted) return;
      setState(() {
        approvedDrivers = approved;
        isLoading = false;
        errorText = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorText = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Approved Drivers'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorText != null
              ? EmptyStateWidget(
                  icon: Icons.error_outline_rounded,
                  title: 'Unable to load approved drivers',
                  message: errorText!,
                  action: SecondaryButton(
                    label: 'Try Again',
                    isExpanded: false,
                    onPressed: _loadApprovedDrivers,
                  ),
                )
              : approvedDrivers.isEmpty
                  ? const EmptyStateWidget(
                      icon: Icons.verified_user_outlined,
                      title: 'No approved drivers yet',
                      message: 'Approved driver accounts will appear here.',
                    )
                  : RefreshIndicator(
                      onRefresh: _loadApprovedDrivers,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        itemCount: approvedDrivers.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: AppSpacing.md),
                        itemBuilder: (context, index) {
                          final driver = approvedDrivers[index];
                          final name = driver['full_name']?.toString() ?? 'Unknown Driver';
                          final phone = driver['phone']?.toString() ?? '-';
                          final status = driver['verification_status']?.toString() ?? 'approved';

                          return InfoCard(
                            title: name,
                            subtitle: 'Approved driver',
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.successSoft,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.person_outline_rounded,
                                color: AppColors.success,
                                size: 20,
                              ),
                            ),
                            trailing: StatusChip(
                              label: status,
                              tone: StatusChip.fromStatus(status),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.phone_outlined,
                                  size: 18,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                Text(
                                  phone,
                                  style: AppTextStyles.body,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
