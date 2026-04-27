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
  bool isRemoving = false;
  String? errorText;
  List<Map<String, dynamic>> approvedDrivers = [];

  @override
  void initState() {
    super.initState();
    _loadApprovedDrivers();
  }

  Future<void> _loadApprovedDrivers() async {
    try {
      final approved = await _authService.getApprovedDriversForCurrentCompany();

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

  Future<void> _removeDriver(Map<String, dynamic> driver) async {
    final driverId = driver['driver_id']?.toString();
    final name = driver['full_name']?.toString() ?? 'this driver';
    if (driverId == null || driverId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete driver from company?'),
          content: Text(
            'This will remove $name from your approved drivers list.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      setState(() => isRemoving = true);
      await _authService.removeDriverFromCurrentCompany(driverId: driverId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Driver removed successfully')),
      );
      await _loadApprovedDrivers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to remove driver: $e')));
    } finally {
      if (mounted) {
        setState(() => isRemoving = false);
      }
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
                          const status = 'approved';

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
                                Expanded(
                                  child: Text(
                                    phone,
                                    style: AppTextStyles.body,
                                  ),
                                ),
                                SecondaryButton(
                                  label: 'Delete',
                                  icon: Icons.delete_outline_rounded,
                                  isExpanded: false,
                                  borderColor: AppColors.danger,
                                  foregroundColor: AppColors.danger,
                                  isLoading: isRemoving,
                                  onPressed: isRemoving
                                      ? null
                                      : () => _removeDriver(driver),
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
