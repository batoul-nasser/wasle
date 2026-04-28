import 'package:flutter/material.dart';

import 'package:wasle/core/debug/automation_test_logger.dart';
import 'package:wasle/core/ui/ui.dart';
import 'package:wasle/features/auth/data/auth_service.dart';
import 'package:wasle/features/driver/data/driver_deliveries_repository.dart';
import 'package:wasle/features/driver/data/driver_live_location_service.dart';
import 'package:wasle/features/driver/presentation/pages/my_deliveries_screen.dart';
import 'driver_profile_screen.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  final AuthService _authService = AuthService();
  final DriverDeliveriesRepository _deliveriesRepository =
      DriverDeliveriesRepository();
  final DriverLiveLocationService _liveLocationService =
      DriverLiveLocationService.instance;

  bool isLoading = true;
  bool isUpdatingAvailability = false;
  String? errorText;
  String? latestRequestStatus;
  String? locationPermissionMessage;
  int assignedCount = 0;
  int activeCount = 0;
  int completedCount = 0;

  Map<String, dynamic>? profileData;
  Map<String, dynamic>? driverData;
  Map<String, dynamic>? companyData;
  Map<String, dynamic>? locationData;
  String? approvedRequestCompanyId;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    try {
      final user = _authService.currentUser;

      if (user == null) {
        if (!mounted) return;
        setState(() {
          isLoading = false;
          errorText = 'User not found';
        });
        return;
      }

      final profile = await _authService.getProfileById(user.id);
      final driver = await _authService.getDriverByProfileId(user.id);
      final requestStatus = await _authService.getLatestDriverRequestStatus();
      final requestSummary = await _authService.getLatestDriverRequestSummary();

      Map<String, dynamic>? company;
      Map<String, dynamic>? location;

      final driverId = driver?['id']?.toString();
      final companyId = driver?['company_id']?.toString();
      final approvedCompanyFromRequest = requestStatus == 'approved'
          ? _stringOrNull(requestSummary, 'company_id')
          : null;
      final effectiveCompanyId = (companyId != null && companyId.isNotEmpty)
          ? companyId
          : approvedCompanyFromRequest;

      if (driverId != null && driverId.isNotEmpty) {
        location = await _authService.getDriverLocationByDriverId(driverId);
      }

      if (effectiveCompanyId != null && effectiveCompanyId.isNotEmpty) {
        company = await _authService.getCompanyById(effectiveCompanyId);
      }

      try {
        final counts = await _deliveriesRepository.getDriverDeliveryCounts();
        assignedCount = counts['assigned'] ?? 0;
        activeCount = counts['active'] ?? 0;
        completedCount = counts['completed'] ?? 0;
      } catch (_) {
        assignedCount = 0;
        activeCount = 0;
        completedCount = 0;
      }

      if (!mounted) return;

      setState(() {
        profileData = profile;
        driverData = driver;
        companyData = company;
        locationData = location;
        latestRequestStatus = requestStatus;
        approvedRequestCompanyId = approvedCompanyFromRequest;
        isLoading = false;
        errorText = null;
      });

      await AutomationTestLogger.log(
        'driver_dashboard',
        'Driver dashboard state loaded',
        data: {
          'current_user_id': user.id,
          'driver_row_id': driverId,
          'profile_id': driver?['profile_id']?.toString(),
          'company_id': companyId,
          'effective_company_id': effectiveCompanyId,
          'approved_request_company_id': approvedCompanyFromRequest,
          'verification_status': driver?['verification_status']?.toString(),
          'availability_status': driver?['availability_status']?.toString(),
          'can_start_working': _canStartWorking,
          'needs_company_join_request': _needsCompanyJoinRequest,
          'latest_request_status': requestStatus,
        },
      );

      await _syncLiveLocationTracking();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorText = e.toString();
        isLoading = false;
      });
    }
  }

  bool get _hasLinkedCompany {
    final driverCompanyId = driverData?['company_id']?.toString();
    if (driverCompanyId != null && driverCompanyId.isNotEmpty) return true;

    final requestCompanyId = approvedRequestCompanyId?.trim();
    return requestCompanyId != null && requestCompanyId.isNotEmpty;
  }

  bool get _isDriverApproved {
    final verificationStatus = driverData?['verification_status']
        ?.toString()
        .trim()
        .toLowerCase();
    if (verificationStatus == 'approved') return true;
    return latestRequestStatus?.trim().toLowerCase() == 'approved';
  }

  bool get _hasPendingCompanyRequest =>
      latestRequestStatus?.trim().toLowerCase() == 'pending';

  bool get _needsCompanyJoinRequest =>
      !_hasLinkedCompany && !_hasPendingCompanyRequest;

  bool get _canStartWorking => _hasLinkedCompany && _isDriverApproved;

  bool get _canUseCompanyDriverActions => _canStartWorking;

  bool get _isAvailableForAssignment =>
      driverData?['availability_status']?.toString().trim().toLowerCase() ==
      'available';

  bool get _isActiveShift => driverData?['is_active_shift'] == true;

  String? _stringOrNull(Map<String, dynamic>? row, String key) {
    final value = row?[key];
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  String get _companyLinkStateLabel {
    if (_hasLinkedCompany && _isDriverApproved) return 'Approved';
    if (_hasPendingCompanyRequest) return 'Pending request';
    if (_needsCompanyJoinRequest) return 'Not linked';
    return driverData?['verification_status']?.toString() ?? 'Unknown';
  }

  String get _companyLinkStateMessage {
    if (_hasLinkedCompany && _isDriverApproved) {
      return 'You are linked to ${companyData?['name'] ?? 'your delivery company'} and ready to work.';
    }
    if (_hasPendingCompanyRequest) {
      return 'Your delivery company request is still under review.';
    }
    return 'You are not linked to a delivery company yet.';
  }

  String get _availabilityLabel =>
      _isAvailableForAssignment && _isActiveShift ? 'Available' : 'Unavailable';

  String get _locationReadinessLabel {
    final lat = locationData?['lat'] ?? driverData?['current_location_lat'];
    final lng = locationData?['lng'] ?? driverData?['current_location_lng'];
    if (lat == null || lng == null) return 'Missing location';
    return 'Location saved';
  }

  String get _locationSubtitle {
    final updatedAt =
        locationData?['last_location_ping_at']?.toString() ??
        locationData?['updated_at']?.toString() ??
        driverData?['last_location_ping_at']?.toString();
    if (updatedAt == null || updatedAt.isEmpty) {
      return 'No live location synced yet.';
    }
    return 'Last sync ${_ageLabelFromUtc(updatedAt)}';
  }

  String _ageLabelFromUtc(String utcIso) {
    final parsed = DateTime.tryParse(utcIso)?.toUtc();
    if (parsed == null) return 'unknown';
    final diff = DateTime.now().toUtc().difference(parsed);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    return '${diff.inHours} h ago';
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const DriverProfileScreen()),
    ).then((_) => _loadDashboard());
  }

  void _openMyDeliveries() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MyDeliveriesScreen()),
    ).then((_) => _loadDashboard());
  }

  Future<void> _openCompanyJoinFlow() async {
    final route = _hasPendingCompanyRequest
        ? '/waiting-approval'
        : '/select-company';
    await Navigator.pushNamed(context, route);
    await _loadDashboard();
  }

  void _showCompanyLinkRequiredMessage() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_companyLinkStateMessage)));
  }

  Future<void> _syncLiveLocationTracking() async {
    final driverId = driverData?['id']?.toString();
    if (driverId == null || driverId.isEmpty) return;

    _liveLocationService.configure(driverId);

    if (!_canUseCompanyDriverActions ||
        !_isAvailableForAssignment ||
        !_isActiveShift) {
      await _liveLocationService.stopTracking();
      return;
    }

    final started = await _liveLocationService.startTracking(
      driverId: driverId,
      requestPermissionIfNeeded: true,
      syncImmediately: true,
    );
    if (!started) {
      await _authService.endDriverShift(driverId: driverId);
      if (!mounted) return;
      setState(() {
        driverData = {
          ...?driverData,
          'availability_status': 'unavailable',
          'is_available': false,
          'is_active_shift': false,
        };
        locationPermissionMessage =
            'Location permission or device location is required before starting a shift.';
      });
      return;
    }

    final latestLocation = await _authService.getDriverLocationByDriverId(
      driverId,
    );
    if (!mounted) return;
    setState(() {
      locationData = latestLocation;
    });
  }

  Future<void> _setAvailability(bool shouldBeAvailable) async {
    final driverId = driverData?['id']?.toString();
    if (driverId == null || driverId.isEmpty) return;

    if (shouldBeAvailable && !_canStartWorking) {
      _showCompanyLinkRequiredMessage();
      return;
    }

    try {
      setState(() {
        isUpdatingAvailability = true;
        locationPermissionMessage = null;
      });

      if (shouldBeAvailable) {
        final started = await _liveLocationService.startTracking(
          driverId: driverId,
          requestPermissionIfNeeded: true,
          syncImmediately: true,
        );
        if (!started) {
          if (!mounted) return;
          setState(() {
            locationPermissionMessage =
                'Location permission or device location is required before starting a shift.';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Enable location permission to start your shift.'),
            ),
          );
          return;
        }
        await _authService.startDriverShift(driverId: driverId);
      } else {
        await _authService.endDriverShift(driverId: driverId);
        await _liveLocationService.stopTracking();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(shouldBeAvailable ? 'Shift started' : 'Shift ended'),
        ),
      );
      await _loadDashboard();
    } catch (e) {
      if (shouldBeAvailable) {
        await _liveLocationService.stopTracking();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update working mode: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isUpdatingAvailability = false;
        });
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fullName = profileData?['full_name']?.toString() ?? 'Driver';
    final companyName = companyData?['name']?.toString() ?? 'Not linked yet';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Profile',
            onPressed: _openProfile,
            icon: const Icon(Icons.person_outline_rounded),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorText != null
          ? EmptyStateWidget(
              icon: Icons.error_outline_rounded,
              title: 'Unable to load dashboard',
              message: errorText!,
              action: SecondaryButton(
                label: 'Try Again',
                isExpanded: false,
                onPressed: _loadDashboard,
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadDashboard,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                children: [
                  InfoCard(
                    title: 'Welcome back, $fullName',
                    subtitle: companyName,
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.local_shipping_outlined,
                        color: AppColors.primary,
                      ),
                    ),
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        StatusChip(
                          label: '$assignedCount assigned',
                          tone: StatusChip.fromStatus('info'),
                        ),
                        StatusChip(
                          label: '$activeCount active',
                          tone: StatusChip.fromStatus('warning'),
                        ),
                        StatusChip(
                          label: '$completedCount completed',
                          tone: StatusChip.fromStatus('success'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  InfoCard(
                    title: 'Delivery Company Access',
                    subtitle: _companyLinkStateMessage,
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.apartment_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _MetaRow(
                          label: 'Link status',
                          value: _companyLinkStateLabel,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _MetaRow(
                          label: 'Latest request',
                          value: latestRequestStatus ?? '-',
                        ),
                        if (!_canStartWorking) ...[
                          const SizedBox(height: AppSpacing.md),
                          PrimaryButton(
                            label: _hasPendingCompanyRequest
                                ? 'Open Approval Status'
                                : 'Request to Join a Delivery Company',
                            icon: _hasPendingCompanyRequest
                                ? Icons.hourglass_top_rounded
                                : Icons.send_rounded,
                            onPressed: _openCompanyJoinFlow,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const SectionHeader(
                    title: 'Working Mode',
                    subtitle:
                        'Company link, availability, and location readiness',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  InfoCard(
                    title: 'Working State',
                    child: Column(
                      children: [
                        _MetaRow(
                          label: 'Availability',
                          value: _availabilityLabel,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _MetaRow(
                          label: 'Active shift',
                          value: _isActiveShift ? 'Active' : 'Inactive',
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _MetaRow(
                          label: 'Location',
                          value: _locationReadinessLabel,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _locationSubtitle,
                            style: AppTextStyles.bodyMuted,
                          ),
                        ),
                        if (locationPermissionMessage != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              locationPermissionMessage!,
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.danger,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PrimaryButton(
                    label: _isAvailableForAssignment
                        ? 'Unavailable / End Shift'
                        : 'Available / Start Shift',
                    icon: _isAvailableForAssignment
                        ? Icons.pause_circle_outline_rounded
                        : Icons.play_circle_outline_rounded,
                    isLoading: isUpdatingAvailability,
                    onPressed: () =>
                        _setAvailability(!_isAvailableForAssignment),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const SectionHeader(
                    title: 'Quick Actions',
                    subtitle: 'Common actions for your account',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PrimaryButton(
                    label: 'My Deliveries',
                    icon: Icons.local_shipping_outlined,
                    onPressed: _openMyDeliveries,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SecondaryButton(
                    label: 'View Profile',
                    icon: Icons.badge_outlined,
                    onPressed: _openProfile,
                  ),
                ],
              ),
            ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: AppTextStyles.bodyMuted)),
        StatusChip(label: value, tone: StatusChip.fromStatus(value)),
      ],
    );
  }
}
