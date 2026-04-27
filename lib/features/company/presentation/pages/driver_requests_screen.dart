import 'package:flutter/material.dart';

import 'package:wasle/core/ui/ui.dart';
import 'package:wasle/features/auth/data/auth_service.dart';

class DriverRequestsScreen extends StatefulWidget {
  const DriverRequestsScreen({super.key});

  @override
  State<DriverRequestsScreen> createState() => _DriverRequestsScreenState();
}

class _DriverRequestsScreenState extends State<DriverRequestsScreen> {
  final AuthService _authService = AuthService();

  bool isLoading = true;
  String? errorText;
  List<Map<String, dynamic>> requests = [];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  List<Map<String, dynamic>> _pendingOnly(List<Map<String, dynamic>> data) {
    return data.where((request) {
      final status = request['request_status']?.toString().toLowerCase();
      return status == null || status == 'pending';
    }).toList();
  }

  Future<void> _loadRequests() async {
    try {
      final data = await _authService.getDriverRequestsForCurrentCompany();

      if (!mounted) return;
      setState(() {
        requests = _pendingOnly(data);
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

  Future<void> _acceptRequest(Map<String, dynamic> request) async {
    try {
      await _authService.acceptDriverRequest(
        requestId: request['request_id'],
        driverProfileId: request['driver_profile_id'],
      );

      if (!mounted) return;
      setState(() {
        requests.removeWhere(
          (r) => r['request_id'] == request['request_id'],
        );
      });
    } catch (e) {
      debugPrint('$e');
    }
  }

  Future<void> _rejectRequest(Map<String, dynamic> request) async {
    try {
      await _authService.rejectDriverRequest(
        requestId: request['request_id'],
        driverProfileId: request['driver_profile_id'],
      );

      if (!mounted) return;
      setState(() {
        requests.removeWhere(
          (r) => r['request_id'] == request['request_id'],
        );
      });
    } catch (e) {
      debugPrint('$e');
    }
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final driverName = request['full_name']?.toString() ?? 'Unknown Driver';
    final phone = request['phone']?.toString() ?? '-';
    final requestStatus = request['request_status']?.toString() ?? '-';
    final verificationStatus = request['verification_status']?.toString() ?? '-';
    final decisionStatus = requestStatus.toLowerCase() == 'approved'
        ? 'approved'
        : requestStatus.toLowerCase() == 'rejected'
            ? 'rejected'
            : 'pending';

    return InfoCard(
      title: driverName,
      subtitle: 'Driver application request',
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.person_outline_rounded,
          color: AppColors.primary,
          size: 20,
        ),
      ),
      trailing: StatusChip(
        label: requestStatus,
        tone: StatusChip.fromStatus(requestStatus),
      ),
      child: Column(
        children: [
          _RequestField(
            label: 'Phone',
            value: phone,
            icon: Icons.phone_outlined,
          ),
          const SizedBox(height: AppSpacing.sm),
          _RequestField(
            label: 'Company Decision',
            value: decisionStatus,
            icon: Icons.verified_user_outlined,
            trailing: StatusChip(
              label: decisionStatus,
              tone: StatusChip.fromStatus(decisionStatus),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Driver verification profile: $verificationStatus',
            style: AppTextStyles.bodyMuted,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: 'Accept',
                  icon: Icons.check_circle_outline,
                  backgroundColor: AppColors.success,
                  onPressed: () => _acceptRequest(request),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: SecondaryButton(
                  label: 'Reject',
                  icon: Icons.close_rounded,
                  borderColor: AppColors.danger,
                  foregroundColor: AppColors.danger,
                  onPressed: () => _rejectRequest(request),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Requests'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorText != null
              ? EmptyStateWidget(
                  icon: Icons.error_outline_rounded,
                  title: 'Could not load requests',
                  message: errorText!,
                  action: SecondaryButton(
                    label: 'Try Again',
                    isExpanded: false,
                    onPressed: _loadRequests,
                  ),
                )
              : requests.isEmpty
                  ? const EmptyStateWidget(
                      icon: Icons.inbox_outlined,
                      title: 'No driver requests',
                      message: 'New requests from drivers will appear here.',
                    )
                  : RefreshIndicator(
                      onRefresh: _loadRequests,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        itemCount: requests.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: AppSpacing.md),
                        itemBuilder: (context, index) {
                          return _buildRequestCard(requests[index]);
                        },
                      ),
                    ),
    );
  }
}

class _RequestField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Widget? trailing;

  const _RequestField({
    required this.label,
    required this.value,
    required this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            '$label: $value',
            style: AppTextStyles.body,
          ),
        ),
        if (trailing case final trailingWidget?) trailingWidget,
      ],
    );
  }
}
