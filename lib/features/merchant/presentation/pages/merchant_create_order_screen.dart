import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wasle/core/services/payment_service.dart';
import 'package:wasle/features/auth/data/auth_service.dart';
import 'package:wasle/features/payment/data/payment_model.dart';
import 'package:wasle/features/payment/presentation/widgets/payment_method_selector.dart';

enum DeliveryCompanyMode { allApproved, linkedOnly }

class MerchantCreateOrderScreen extends StatefulWidget {
  const MerchantCreateOrderScreen({super.key});

  @override
  State<MerchantCreateOrderScreen> createState() =>
      _MerchantCreateOrderScreenState();
}

class _MerchantCreateOrderScreenState extends State<MerchantCreateOrderScreen> {
  final SupabaseClient _client = Supabase.instance.client;
  final PaymentService _paymentService = PaymentService();
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  final _customerNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _timeWindowCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _pickupPointSearchCtrl = TextEditingController();

  final _parcelDescriptionCtrl = TextEditingController();
  final _itemCountCtrl = TextEditingController(text: '1');
  final _estimatedWeightCtrl = TextEditingController();
  final _estimatedVolumeCtrl = TextEditingController();

  String? _merchantId;
  String? _merchantBranchId;
  double? _merchantBranchLat;
  double? _merchantBranchLng;
  String? _merchantBranchName;
  String? _merchantBranchAddress;

  String? _loadError;
  bool _loadingFormData = false;
  bool _submitting = false;

  String _pickupSourceType = _pickupFromStore;
  String _dropoffType = _dropoffHome;

  String? _selectedSourcePickupPointId;
  String? _selectedDestinationPickupPointId;
  String? _selectedDeliveryCompanyId;
  String? _recommendedDeliveryCompanyId;
  String? _automationHint;

  List<_PickupPointOption> _allPickupPoints = const [];
  List<_PickupPointOption> _sourcePickupPoints = const [];
  List<_PickupPointOption> _destinationPickupPoints = const [];

  List<_DeliveryCompanyOption> _allDeliveryCompanies = const [];
  List<_DeliveryCompanyOption> _filteredDeliveryCompanies = const [];

  PaymentMethod _paymentMethod = PaymentMethod.cashAtPickup;
  double _paymentAmount = 0;
  int _paymentFieldRevision = 0;

  double? _selectedCustomerLat;
  double? _selectedCustomerLng;

  static const _pickupFromStore = 'From Store';
  static const _pickupFromPickupPoint = 'From Pickup Point';

  static const _dropoffHome = 'Home Delivery';
  static const _dropoffPickupSpecific = 'Specific Pickup Point';

  static const DeliveryCompanyMode _deliveryCompanyMode =
      DeliveryCompanyMode.linkedOnly;

  static const int _maxRecommendedCompanies = 3;
  static const int _maxSourcePickupSuggestions = 5;
  static const int _maxDestinationPickupSuggestions = 5;

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _customerNameCtrl,
      _phoneCtrl,
      _emailCtrl,
      _addressCtrl,
      _timeWindowCtrl,
      _notesCtrl,
      _pickupPointSearchCtrl,
      _parcelDescriptionCtrl,
      _itemCountCtrl,
      _estimatedWeightCtrl,
      _estimatedVolumeCtrl,
    ]) {
      controller.addListener(_refresh);
    }
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _loadingFormData = true;
      _loadError = null;
      _automationHint = null;
    });

    try {
      final merchantId = await _resolveMerchantId();
      final branch = await _resolveMerchantBranch(merchantId);

      if (!mounted) return;
      setState(() {
        _merchantId = merchantId;
        _merchantBranchId = branch?.id;
        _merchantBranchLat = branch?.lat;
        _merchantBranchLng = branch?.lng;
        _merchantBranchName = branch?.name;
        _merchantBranchAddress = branch?.addressText;
      });

      final pickupPoints = await _loadPickupPoints();
      final deliveryCompanies = await _loadDeliveryCompanies(merchantId);

      if (!mounted) return;

      setState(() {
        _allPickupPoints = pickupPoints;
        _sourcePickupPoints = const [];
        _destinationPickupPoints = const [];
        _allDeliveryCompanies = deliveryCompanies;
        _filteredDeliveryCompanies = const [];
        _selectedSourcePickupPointId = pickupPoints.length == 1
            ? pickupPoints.first.id
            : null;
        _selectedDestinationPickupPointId = null;
        _selectedDeliveryCompanyId = null;
        _loadingFormData = false;
      });

      await _recomputeAutomation();
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _loadingFormData = false;
        _loadError = message;
      });
      _showSnackBar(message, isError: true);
    }
  }

  Future<String> _resolveMerchantId() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('You must be logged in.');
    }

    final merchantRow = await _client
        .from('merchant_users')
        .select('merchant_id')
        .eq('profile_id', user.id)
        .maybeSingle();

    final merchantId = merchantRow?['merchant_id']?.toString();
    if (merchantId == null || merchantId.isEmpty) {
      throw Exception('Merchant profile not found. Please contact support.');
    }

    return merchantId;
  }

  Future<_MerchantBranchOption?> _resolveMerchantBranch(
    String merchantId,
  ) async {
    final rows = await _client
        .from('merchant_branches')
        .select('id, merchant_id, name, address_text, lat, lng, is_active')
        .eq('merchant_id', merchantId)
        .eq('is_active', true)
        .order('created_at', ascending: false)
        .limit(1);

    final raw = List<Map<String, dynamic>>.from(rows);
    if (raw.isEmpty) return null;

    final row = raw.first;
    return _MerchantBranchOption(
      id: row['id']?.toString() ?? '',
      name: (row['name']?.toString() ?? '').trim(),
      addressText: (row['address_text']?.toString() ?? '').trim(),
      lat: _asDouble(row['lat']),
      lng: _asDouble(row['lng']),
    );
  }

  Future<List<_PickupPointOption>> _loadPickupPoints() async {
  final rows = await _client
      .from('pickup_points')
      .select('''
        id,
        name,
        address_text,
        lat,
        lng,
        city,
        area,
        is_active,
        status,
        branch_id,
        merchant_branches:branch_id (
          name,
          address_text
        )
      ''')
      .eq('is_active', true)
      .inFilter('status', ['approved', 'active'])
      .order('created_at', ascending: false);

  final raw = List<Map<String, dynamic>>.from(rows);

  final options = raw
      .map((row) {
        final pickupName = (row['name']?.toString() ?? '').trim();
        final pickupAddress = (row['address_text']?.toString() ?? '').trim();
        final city = (row['city']?.toString() ?? '').trim();
        final area = (row['area']?.toString() ?? '').trim();
        final lat = _asDouble(row['lat']);
        final lng = _asDouble(row['lng']);

        String branchName = '';
        final branch = row['merchant_branches'];

        if (branch is Map<String, dynamic>) {
          branchName = (branch['name']?.toString() ?? '').trim();
        } else if (branch is List && branch.isNotEmpty) {
          final first = branch.first;
          if (first is Map<String, dynamic>) {
            branchName = (first['name']?.toString() ?? '').trim();
          }
        }

        final title = branchName.isNotEmpty
            ? '$pickupName — $branchName'
            : pickupName;

        return _PickupPointOption(
          id: row['id']?.toString() ?? '',
          name: title,
          subtitle: pickupAddress.isEmpty ? null : pickupAddress,
          addressText: pickupAddress,
          lat: lat,
          lng: lng,
          city: city,
          area: area,
        );
      })
      .where(
        (option) =>
            option.id.isNotEmpty &&
            option.name.isNotEmpty &&
            option.lat != null &&
            option.lng != null,
      )
      .toList();

  return options;
}

  Future<List<_DeliveryCompanyOption>> _loadDeliveryCompanies(
    String merchantId,
  ) async {
    final basicOptions = switch (_deliveryCompanyMode) {
      DeliveryCompanyMode.allApproved => await _loadApprovedDeliveryCompanies(),
      DeliveryCompanyMode.linkedOnly => await _loadLinkedDeliveryCompanies(
        merchantId,
      ),
    };

    if (basicOptions.isEmpty) return const [];

    final companyIds = basicOptions.map((e) => e.id).toList();

    List<Map<String, dynamic>> hubRows = const [];
    List<Map<String, dynamic>> capacityRows = const [];

    try {
      final hubs = await _client
          .from('delivery_company_hubs')
          .select(
            'id, company_id, name, address_text, city, area, lat, lng, is_active',
          )
          .inFilter('company_id', companyIds)
          .eq('is_active', true);

      hubRows = List<Map<String, dynamic>>.from(hubs);
    } catch (_) {}

    try {
      final capacities = await _client
          .from('delivery_company_capacity')
          .select(
            'company_id, max_active_orders, max_daily_orders, current_active_orders, current_daily_orders, is_active',
          )
          .inFilter('company_id', companyIds);

      capacityRows = List<Map<String, dynamic>>.from(capacities);
    } catch (_) {}

    final hubsByCompany = <String, List<_CompanyHub>>{};
    for (final row in hubRows) {
      final companyId = row['company_id']?.toString();
      if (companyId == null || companyId.isEmpty) continue;

      final hub = _CompanyHub(
        id: row['id']?.toString() ?? '',
        name: (row['name']?.toString() ?? '').trim(),
        addressText: (row['address_text']?.toString() ?? '').trim(),
        city: (row['city']?.toString() ?? '').trim(),
        area: (row['area']?.toString() ?? '').trim(),
        lat: _asDouble(row['lat']),
        lng: _asDouble(row['lng']),
        isActive: row['is_active'] == true,
      );

      hubsByCompany.putIfAbsent(companyId, () => <_CompanyHub>[]).add(hub);
    }

    final capacityByCompany = <String, _CompanyCapacity>{};
    for (final row in capacityRows) {
      final companyId = row['company_id']?.toString();
      if (companyId == null || companyId.isEmpty) continue;

      capacityByCompany[companyId] = _CompanyCapacity(
        maxActiveOrders: _asInt(row['max_active_orders']),
        maxDailyOrders: _asInt(row['max_daily_orders']),
        currentActiveOrders: _asInt(row['current_active_orders']) ?? 0,
        currentDailyOrders: _asInt(row['current_daily_orders']) ?? 0,
        isActive: row['is_active'] == true,
      );
    }

    return basicOptions.map((basic) {
      return _DeliveryCompanyOption(
        id: basic.id,
        name: basic.name,
        hubs: hubsByCompany[basic.id] ?? const [],
        capacity: capacityByCompany[basic.id],
      );
    }).toList();
  }

  Future<List<_DeliveryCompanyBasicOption>>
  _loadApprovedDeliveryCompanies() async {
    try {
      final companyRows = await _client
          .from('delivery_companies')
          .select('id, name, verification_status')
          .eq('verification_status', 'approved')
          .order('name');

      final options = List<Map<String, dynamic>>.from(companyRows)
          .map(
            (row) => _DeliveryCompanyBasicOption(
              id: row['id']?.toString() ?? '',
              name: (row['name']?.toString() ?? '').trim(),
            ),
          )
          .where((option) => option.id.isNotEmpty && option.name.isNotEmpty)
          .toList();

      options.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

      return options;
    } catch (_) {
      return const [];
    }
  }

  Future<List<_DeliveryCompanyBasicOption>> _loadLinkedDeliveryCompanies(
    String merchantId,
  ) async {
    try {
      final rows = await _client
          .from('merchant_delivery_companies')
          .select('''
            company_id,
            is_active,
            delivery_companies:company_id (
              id,
              name,
              verification_status
            )
          ''')
          .eq('merchant_id', merchantId)
          .eq('is_active', true);

      final raw = List<Map<String, dynamic>>.from(rows);

      final options = raw
          .map((row) {
            final company = row['delivery_companies'];
            Map<String, dynamic>? companyMap;

            if (company is Map<String, dynamic>) {
              companyMap = company;
            } else if (company is List &&
                company.isNotEmpty &&
                company.first is Map<String, dynamic>) {
              companyMap = company.first as Map<String, dynamic>;
            }

            if (companyMap == null) {
              return const _DeliveryCompanyBasicOption(id: '', name: '');
            }

            final status = (companyMap['verification_status']?.toString() ?? '')
                .trim();
            final id = (companyMap['id']?.toString() ?? '').trim();
            final name = (companyMap['name']?.toString() ?? '').trim();

            if (status != 'approved') {
              return const _DeliveryCompanyBasicOption(id: '', name: '');
            }

            return _DeliveryCompanyBasicOption(id: id, name: name);
          })
          .where((option) => option.id.isNotEmpty && option.name.isNotEmpty)
          .toList();

      options.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

      return options;
    } catch (_) {
      return const [];
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  bool _isValidEmail(String value) {
    final email = value.trim();
    if (email.isEmpty) return true;
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  int? _parseItemCount() {
    final raw = _itemCountCtrl.text.trim();
    if (raw.isEmpty) return null;
    return int.tryParse(raw);
  }

  double? _parsePositiveDouble(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    return double.tryParse(value);
  }

  bool get _requiresCustomerMap {
    return _dropoffType == _dropoffHome;
  }

  bool get _canSubmit {
    final hasCustomer = _customerNameCtrl.text.trim().isNotEmpty;
    final hasPhone = _phoneCtrl.text.trim().isNotEmpty;

    final sourceOk =
        _pickupSourceType != _pickupFromPickupPoint ||
        _selectedSourcePickupPointId != null;

    final destinationOk = switch (_dropoffType) {
      _dropoffHome =>
        _addressCtrl.text.trim().isNotEmpty &&
        _selectedCustomerLat != null &&
        _selectedCustomerLng != null,
      _dropoffPickupSpecific => _selectedDestinationPickupPointId != null,
      _ => false,
    };

    final mapOk =
        !_requiresCustomerMap ||
        (_selectedCustomerLat != null && _selectedCustomerLng != null);

    final hasPaymentAmount = _paymentAmount > 0;
    final companyOk =
        _allDeliveryCompanies.isEmpty || _selectedDeliveryCompanyId != null;

    final itemCount = _parseItemCount();
    final itemCountOk = itemCount == null || itemCount > 0;

    return !_loadingFormData &&
        !_submitting &&
        _merchantId != null &&
        hasCustomer &&
        hasPhone &&
        sourceOk &&
        destinationOk &&
        mapOk &&
        hasPaymentAmount &&
        companyOk &&
        itemCountOk;
  }

  Future<void> _openMapPicker() async {
    final result = await Navigator.of(context).push<_PickedMapLocation>(
      MaterialPageRoute(
        builder: (_) => _MapPickerScreen(
          initialLat: _selectedCustomerLat,
          initialLng: _selectedCustomerLng,
          initialAddress: _addressCtrl.text.trim(),
        ),
      ),
    );

    if (!mounted || result == null) return;

    setState(() {
      _selectedCustomerLat = result.lat;
      _selectedCustomerLng = result.lng;
      if (result.address.trim().isNotEmpty) {
        _addressCtrl.text = result.address.trim();
      }
    });

    await _recomputeAutomation();
  }

  Future<void> _onPickupSourceChanged(String value) async {
    setState(() {
      _pickupSourceType = value;
      if (_pickupSourceType != _pickupFromPickupPoint) {
        _selectedSourcePickupPointId = null;
      }
    });

    await _recomputeAutomation();
  }

  Future<void> _onDropoffTypeChanged(String value) async {
    setState(() {
      _dropoffType = value;

      if (_dropoffType == _dropoffPickupSpecific) {
        _selectedDestinationPickupPointId = null;
        _addressCtrl.clear();
        _selectedCustomerLat = null;
        _selectedCustomerLng = null;
      }
    });

    await _recomputeAutomation();
  }

  Future<void> _onSourcePickupChanged(String? value) async {
    setState(() => _selectedSourcePickupPointId = value);
    await _recomputeAutomation();
  }

  Future<void> _onDestinationPickupChanged(String? value) async {
    setState(() => _selectedDestinationPickupPointId = value);
    await _recomputeAutomation();
  }

  Future<void> _recomputeAutomation() async {
    if (!mounted) return;

    final merchantLocation = _merchantLocation();
    final hasMerchantLocation = merchantLocation != null;

    final nextSourcePickupPoints = _computeSourcePickupCandidates(
      merchantLocation: merchantLocation,
    );

    final nextDestinationPickupPoints = _dropoffType == _dropoffHome
        ? _computeBackupPickupCandidates(
            customerLat: _selectedCustomerLat,
            customerLng: _selectedCustomerLng,
          )
        : _computeSpecificPickupCandidates();

    String? nextSourcePickupId = _selectedSourcePickupPointId;
    String? nextDestinationPickupId = _selectedDestinationPickupPointId;
    String? nextSelectedCompanyId;
    String? nextRecommendedCompanyId;
    String? info;

    if (_pickupSourceType == _pickupFromPickupPoint) {
      if (!_containsPickup(nextSourcePickupPoints, nextSourcePickupId)) {
        nextSourcePickupId = hasMerchantLocation && nextSourcePickupPoints.isNotEmpty
            ? nextSourcePickupPoints.first.id
            : null;
      }
    } else {
      nextSourcePickupId = null;
    }

    if (_dropoffType == _dropoffHome) {
      final hasCustomerLocation =
          _selectedCustomerLat != null && _selectedCustomerLng != null;

      if (!hasCustomerLocation) {
        nextDestinationPickupId = null;
      } else if (!_containsPickup(
        nextDestinationPickupPoints,
        nextDestinationPickupId,
      )) {
        nextDestinationPickupId = nextDestinationPickupPoints.isNotEmpty
            ? nextDestinationPickupPoints.first.id
            : null;
      }
    } else if (_dropoffType == _dropoffPickupSpecific) {
      if (!_containsPickup(
        nextDestinationPickupPoints,
        nextDestinationPickupId,
      )) {
        nextDestinationPickupId = null;
      }
    } else {
      nextDestinationPickupId = null;
    }

    final destinationLocation = _resolveDestinationLocation(
      destinationPickupId: nextDestinationPickupId,
      destinationCandidates: nextDestinationPickupPoints,
    );

    final rankedCompanies = _rankDeliveryCompaniesForMerchant(
      merchantLocation: merchantLocation,
      destination: destinationLocation,
    );

    final topCompanies = rankedCompanies
        .map((entry) => entry.company)
        .take(_maxRecommendedCompanies)
        .toList();

    if (topCompanies.isNotEmpty) {
      nextRecommendedCompanyId = topCompanies.first.id;

      final currentStillValid = topCompanies.any(
        (company) => company.id == _selectedDeliveryCompanyId,
      );

      nextSelectedCompanyId = currentStillValid
          ? _selectedDeliveryCompanyId
          : topCompanies.first.id;

      info = null;
    } else if (_allDeliveryCompanies.isEmpty) {
      info = 'No linked delivery companies found.';
    } else if (!hasMerchantLocation) {
      info = 'Add merchant branch coordinates to recommend companies.';
    } else {
      info = 'No available company from the nearest 3 linked companies.';
    }

    if (!mounted) return;
    setState(() {
      _sourcePickupPoints = nextSourcePickupPoints;
      _destinationPickupPoints = nextDestinationPickupPoints;
      _selectedSourcePickupPointId = nextSourcePickupId;
      _selectedDestinationPickupPointId = nextDestinationPickupId;
      _filteredDeliveryCompanies = topCompanies;
      _selectedDeliveryCompanyId = nextSelectedCompanyId;
      _recommendedDeliveryCompanyId = nextRecommendedCompanyId;
      _automationHint = info;
    });
  }

  _LatLngOption? _merchantLocation() {
    if (_merchantBranchLat == null || _merchantBranchLng == null) return null;
    return _LatLngOption(lat: _merchantBranchLat!, lng: _merchantBranchLng!);
  }

  _LatLngOption? _resolveSourceLocation({
    String? sourcePickupId,
    List<_PickupPointOption>? sourceCandidates,
  }) {
    if (_pickupSourceType == _pickupFromStore) {
      if (_merchantBranchLat == null || _merchantBranchLng == null) return null;
      return _LatLngOption(lat: _merchantBranchLat!, lng: _merchantBranchLng!);
    }

    final selectedId = sourcePickupId ?? _selectedSourcePickupPointId;
    final sourcePickup =
        _pickupPointByIdFrom(
          selectedId,
          sourceCandidates ?? _sourcePickupPoints,
        ) ??
        _pickupPointById(selectedId);
    if (sourcePickup?.lat == null || sourcePickup?.lng == null) return null;
    return _LatLngOption(lat: sourcePickup!.lat!, lng: sourcePickup.lng!);
  }

  List<_PickupPointOption> _computeSourcePickupCandidates({
    required _LatLngOption? merchantLocation,
  }) {
    final points = List<_PickupPointOption>.from(_allPickupPoints);

    if (merchantLocation == null) {
      points.sort(
        (a, b) => a.displayName.toLowerCase().compareTo(
          b.displayName.toLowerCase(),
        ),
      );
      return points;
    }

    points.sort((a, b) {
      final da = _distanceKm(
        merchantLocation.lat,
        merchantLocation.lng,
        a.lat!,
        a.lng!,
      );
      final db = _distanceKm(
        merchantLocation.lat,
        merchantLocation.lng,
        b.lat!,
        b.lng!,
      );
      return da.compareTo(db);
    });

    return points;
  }

  List<_PickupPointOption> _computeBackupPickupCandidates({
    required double? customerLat,
    required double? customerLng,
  }) {
    final points = List<_PickupPointOption>.from(_allPickupPoints);
    if (customerLat == null || customerLng == null) return points;

    points.sort((a, b) {
      final da = _distanceKm(customerLat, customerLng, a.lat!, a.lng!);
      final db = _distanceKm(customerLat, customerLng, b.lat!, b.lng!);
      return da.compareTo(db);
    });

    return points;
  }

  List<_PickupPointOption> _computeSpecificPickupCandidates() {
    return List<_PickupPointOption>.from(_allPickupPoints);
  }

  _LatLngOption? _resolveDestinationLocation({
    String? destinationPickupId,
    List<_PickupPointOption>? destinationCandidates,
  }) {
    switch (_dropoffType) {
      case _dropoffHome:
        if (_selectedCustomerLat == null || _selectedCustomerLng == null) {
          return null;
        }
        return _LatLngOption(
          lat: _selectedCustomerLat!,
          lng: _selectedCustomerLng!,
        );

      case _dropoffPickupSpecific:
        final selectedId =
            destinationPickupId ?? _selectedDestinationPickupPointId;
        final point = _pickupPointByIdFrom(
              selectedId,
              destinationCandidates ?? _destinationPickupPoints,
            ) ??
            _pickupPointById(selectedId);
        if (point == null) return null;
        return _LatLngOption(lat: point.lat!, lng: point.lng!);

      default:
        return null;
    }
  }

  _PickupPointOption? _findNearestPickupFromList({
    required List<_PickupPointOption> points,
    required double? lat,
    required double? lng,
  }) {
    if (lat == null || lng == null || points.isEmpty) return null;

    final sorted = List<_PickupPointOption>.from(points)
      ..sort((a, b) {
        final da = _distanceKm(lat, lng, a.lat!, a.lng!);
        final db = _distanceKm(lat, lng, b.lat!, b.lng!);
        return da.compareTo(db);
      });

    return sorted.first;
  }

  List<_RankedCompanyForMerchant> _rankDeliveryCompaniesForMerchant({
    required _LatLngOption? merchantLocation,
    required _LatLngOption? destination,
  }) {
    if (merchantLocation == null) return const [];

    final nearestToMerchant = <_MerchantNearestCompany>[];

    for (final company in _allDeliveryCompanies) {
      _CompanyHub? nearestHub;
      double? nearestDistanceKm;

      for (final hub in company.hubs) {
        if (!hub.isUsable) continue;

        final distance = _distanceKm(
          merchantLocation.lat,
          merchantLocation.lng,
          hub.lat!,
          hub.lng!,
        );

        if (nearestDistanceKm == null || distance < nearestDistanceKm) {
          nearestDistanceKm = distance;
          nearestHub = hub;
        }
      }

      if (nearestHub != null && nearestDistanceKm != null) {
        nearestToMerchant.add(
          _MerchantNearestCompany(
            company: company,
            nearestHub: nearestHub,
            merchantDistanceKm: nearestDistanceKm,
          ),
        );
      }
    }

    nearestToMerchant.sort(
      (a, b) => a.merchantDistanceKm.compareTo(b.merchantDistanceKm),
    );

    final topNearest = nearestToMerchant.take(_maxRecommendedCompanies).toList();

    final feasible = topNearest
        .where((entry) => _companyHasAvailableCapacity(entry.company))
        .map((entry) {
          final cap = entry.company.capacity;
          final remainingActive = cap?.remainingActiveOrders ?? 999999;
          final remainingDaily = cap?.remainingDailyOrders ?? 999999;
          final destinationDistance = destination == null
              ? 999999.0
              : _distanceKm(
                  destination.lat,
                  destination.lng,
                  entry.nearestHub.lat!,
                  entry.nearestHub.lng!,
                );

          return _RankedCompanyForMerchant(
            company: entry.company,
            bestHub: entry.nearestHub,
            merchantDistanceKm: entry.merchantDistanceKm,
            destinationDistanceKm: destinationDistance,
            remainingActiveOrders: remainingActive,
            remainingDailyOrders: remainingDaily,
          );
        })
        .toList();

    feasible.sort((a, b) {
      final activeCompare = b.remainingActiveOrders.compareTo(a.remainingActiveOrders);
      if (activeCompare != 0) return activeCompare;

      final dailyCompare = b.remainingDailyOrders.compareTo(a.remainingDailyOrders);
      if (dailyCompare != 0) return dailyCompare;

      final destinationCompare = a.destinationDistanceKm.compareTo(b.destinationDistanceKm);
      if (destinationCompare != 0) return destinationCompare;

      return a.merchantDistanceKm.compareTo(b.merchantDistanceKm);
    });

    return feasible;
  }

  bool _companyHasAvailableCapacity(_DeliveryCompanyOption company) {
    final cap = company.capacity;
    if (cap == null) return true;
    if (!cap.isActive) return false;

    final activeOk =
        cap.maxActiveOrders == null ||
        cap.currentActiveOrders < cap.maxActiveOrders!;
    final dailyOk =
        cap.maxDailyOrders == null ||
        cap.currentDailyOrders < cap.maxDailyOrders!;

    return activeOk && dailyOk;
  }

  Future<void> _submitOrder() async {
    if (_submitting) return;
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

    final merchantId = _merchantId;
    if (merchantId == null) {
      _showSnackBar(
        _loadError ?? 'Merchant profile not found. Please contact support.',
        isError: true,
      );
      return;
    }

    if (_pickupSourceType == _pickupFromPickupPoint &&
        _selectedSourcePickupPointId == null) {
      _showSnackBar('Please select a source pickup point.', isError: true);
      return;
    }

    if (_dropoffType == _dropoffPickupSpecific &&
        _selectedDestinationPickupPointId == null) {
      _showSnackBar('Please select a destination pickup point.', isError: true);
      return;
    }

    if (_allDeliveryCompanies.isNotEmpty &&
        _selectedDeliveryCompanyId == null) {
      _showSnackBar(
        'No available recommended delivery company. Please check capacity.',
        isError: true,
      );
      return;
    }

    if (_paymentAmount <= 0) {
      _showSnackBar('Please enter a payment amount.', isError: true);
      return;
    }

    final itemCount = _parseItemCount();
    if (itemCount != null && itemCount <= 0) {
      _showSnackBar('Item count must be greater than zero.', isError: true);
      return;
    }

    if (_requiresCustomerMap &&
        (_selectedCustomerLat == null || _selectedCustomerLng == null)) {
      _showSnackBar(
        'Please select the customer location on the map.',
        isError: true,
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final effectiveAddress = _effectiveOrderAddressForCreation();

      final result = await _paymentService.createOrderWithPayment(
        merchantId: merchantId,
        branchId: _merchantBranchId,
        customerName: _customerNameCtrl.text.trim(),
        customerPhone: _phoneCtrl.text.trim(),
        customerEmail: _emailCtrl.text.trim().isEmpty
            ? null
            : _emailCtrl.text.trim(),
        address: effectiveAddress,
        amount: _paymentAmount,
        paymentMethod: _paymentMethod,
        pickupPointId: _pickupSourceType == _pickupFromPickupPoint
            ? _selectedSourcePickupPointId
            : null,
        deliveryCompanyId: _selectedDeliveryCompanyId,
        notes: _mergedNotes(),
      );

      final orderId = _resultValue(result, ['id', 'orderId', 'order_id']);
      await _saveOrderExtras(orderId);

      if (!mounted) return;
      setState(() => _submitting = false);

      final trackingCode = _resultValue(result, [
        'trackingCode',
        'tracking_code',
      ]);

      await showDialog<void>(
        context: context,
        builder: (_) => _SuccessDialog(
          orderId: orderId,
          trackingCode: trackingCode,
          pickupMethod: _summaryPickupSource,
          dropoffMethod: _summaryDropoff,
          paymentMethod: _paymentMethod.displayName,
          amount: _summaryPaymentAmount,
          packageType: _summaryPackageType,
          itemCount: _summaryItemCount,
          weight: _summaryWeight,
          volume: _summaryVolume,
          mapLocation: _summaryMapLocation,
          company: _summaryCompany,
        ),
      );

      _resetForm();
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showSnackBar(
        'Failed to create order: ${e.toString().replaceFirst('Exception: ', '')}',
        isError: true,
      );
    }
  }

  Future<void> _saveOrderExtras(String orderId) async {
    if (orderId.trim().isEmpty || orderId == '-') return;

    final destinationPickupId =
        (_dropoffType == _dropoffHome ||
            _dropoffType == _dropoffPickupSpecific)
        ? _selectedDestinationPickupPointId
        : null;

    await _client
        .from('orders')
        .update({
          'branch_id': _merchantBranchId,
          'pickup_source_type': _pickupSourceType == _pickupFromPickupPoint
              ? 'pickup_point'
              : 'store',
          'pickup_point_id': _pickupSourceType == _pickupFromPickupPoint
              ? _selectedSourcePickupPointId
              : null,
          'destination_pickup_point_id': destinationPickupId,
          'dropoff_type': _normalizedDropoffType(),
          'parcel_description': _parcelDescriptionCtrl.text.trim().isEmpty
              ? null
              : _parcelDescriptionCtrl.text.trim(),
          'item_count': _parseItemCount(),
          'estimated_weight': _parsePositiveDouble(_estimatedWeightCtrl.text),
          'estimated_volume': _parsePositiveDouble(_estimatedVolumeCtrl.text),
          'customer_address_text': _customerAddressForStorage(),
          'customer_lat': _selectedCustomerLat,
          'customer_lng': _selectedCustomerLng,
          'delivery_company_id': _selectedDeliveryCompanyId,
          'notes': _mergedNotes(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', orderId);
  }

  String _normalizedDropoffType() {
    switch (_dropoffType) {
      case _dropoffHome:
        return 'home';
      case _dropoffPickupSpecific:
        return 'pickup_point_specific';
      default:
        return 'home';
    }
  }

  String _effectiveOrderAddressForCreation() {
    switch (_dropoffType) {
      case _dropoffHome:
        return _addressCtrl.text.trim();
      case _dropoffPickupSpecific:
        return _destinationPickupPoint()?.addressText.trim().isNotEmpty == true
            ? _destinationPickupPoint()!.addressText
            : _addressCtrl.text.trim();
      default:
        return _addressCtrl.text.trim();
    }
  }

  String? _customerAddressForStorage() {
    switch (_dropoffType) {
      case _dropoffHome:
        return _addressCtrl.text.trim().isEmpty
            ? null
            : _addressCtrl.text.trim();
      case _dropoffPickupSpecific:
        return null;
      default:
        return _addressCtrl.text.trim().isEmpty
            ? null
            : _addressCtrl.text.trim();
    }
  }

  String? _mergedNotes() {
    final parts = <String>[];

    final merchantNotes = _notesCtrl.text.trim();
    final timeWindow = _timeWindowCtrl.text.trim();
    final normalizedWindowLabel = _normalizedPreferredTimeWindowLabel(
      timeWindow,
    );
    final selectedCompany = _selectedCompany();
    final customerName = _customerNameCtrl.text.trim();
    final customerPhone = _phoneCtrl.text.trim();
    final customerEmail = _emailCtrl.text.trim();

    parts.add('=== ROUTING DETAILS ===');
    parts.add(
      'Pickup source type: ${_pickupSourceType == _pickupFromPickupPoint ? 'pickup_point' : 'store'}',
    );
    parts.add('Pickup source: ${_sourceLabel()}');

    final sourceAddress = _sourceAddressLabel();
    if (sourceAddress != null) {
      parts.add('Pickup source address: $sourceAddress');
    }

    final sourceCoords = _sourceCoordinatesLabel();
    if (sourceCoords != null) {
      parts.add('Pickup source coordinates: $sourceCoords');
    }

    parts.add('Dropoff type: ${_normalizedDropoffType()}');
    parts.add('Dropoff destination: ${_destinationLabel()}');

    final destinationPickup = _destinationPickupPoint();
    if (_dropoffType == _dropoffHome && destinationPickup != null) {
      parts.add(
        'Option 1 destination: Customer map pin',
      );
      parts.add(
        'Option 2 pickup point: ${destinationPickup.displayName}',
      );

      final backupAddress = destinationPickup.addressText.trim();
      if (backupAddress.isNotEmpty) {
        parts.add('Option 2 pickup point address: $backupAddress');
      }

      if (destinationPickup.lat != null && destinationPickup.lng != null) {
        parts.add(
          'Option 2 pickup point coordinates: ${_formatCoordinates(destinationPickup.lat!, destinationPickup.lng!)}',
        );
      }
    } else if (_dropoffType == _dropoffPickupSpecific &&
        destinationPickup != null) {
      parts.add('Destination pickup point: ${destinationPickup.displayName}');

      final destinationPickupAddress = destinationPickup.addressText.trim();
      if (destinationPickupAddress.isNotEmpty) {
        parts.add('Destination pickup point address: $destinationPickupAddress');
      }

      if (destinationPickup.lat != null && destinationPickup.lng != null) {
        parts.add(
          'Destination pickup point coordinates: ${_formatCoordinates(destinationPickup.lat!, destinationPickup.lng!)}',
        );
      }
    }

    final destinationAddress = _destinationAddressLabel();
    if (destinationAddress != null) {
      parts.add('Dropoff address: $destinationAddress');
    }

    final destinationCoords = _destinationCoordinatesLabel();
    if (destinationCoords != null) {
      parts.add('Dropoff coordinates: $destinationCoords');
    }

    if (_selectedSourcePickupPointId != null) {
      parts.add('Source pickup point id: $_selectedSourcePickupPointId');
    }

    if (_selectedDestinationPickupPointId != null) {
      parts.add(
        'Destination pickup point id: $_selectedDestinationPickupPointId',
      );
    }

    parts.add('');
    parts.add('=== CUSTOMER DETAILS ===');

    if (customerName.isNotEmpty) {
      parts.add('Customer name: $customerName');
    }

    if (customerPhone.isNotEmpty) {
      parts.add('Customer phone: $customerPhone');
    }

    if (customerEmail.isNotEmpty) {
      parts.add('Customer email: $customerEmail');
    }

    final requestedAddress = _addressCtrl.text.trim();
    if (requestedAddress.isNotEmpty) {
      parts.add('Customer requested address: $requestedAddress');
    }

    final requestedCoords = _customerRequestedCoordinatesLabel();
    if (requestedCoords != null) {
      parts.add('Customer requested coordinates: $requestedCoords');
    }

    parts.add('');
    parts.add('=== DELIVERY COMPANY ===');

    if (selectedCompany != null) {
      parts.add('Assigned delivery company: ${selectedCompany.name}');
      parts.add(
        'Assignment mode: ${_recommendedDeliveryCompanyId == selectedCompany.id ? 'auto_recommended' : 'manual_selection'}',
      );
    }

    if (normalizedWindowLabel != null) {
      parts.add('Preferred time window: $normalizedWindowLabel');
    }

    if (merchantNotes.isNotEmpty) {
      parts.add('');
      parts.add('=== MERCHANT NOTES ===');
      parts.add(merchantNotes);
    }

    return parts.isEmpty ? null : parts.join('\n');
  }

  String? _normalizedPreferredTimeWindowLabel(String raw) {
    final parsed = _parsePreferredTimeWindow(raw);
    if (parsed == null) {
      final fallback = raw.trim();
      return fallback.isEmpty ? null : fallback;
    }
    final start = parsed.$1.toLocal();
    final end = parsed.$2.toLocal();
    return '${_fmtLocalDateTime(start)} - ${_fmtLocalDateTime(end)}';
  }

  (DateTime, DateTime)? _parsePreferredTimeWindow(String raw) {
    final text = raw.trim().toLowerCase();
    if (text.isEmpty) return null;

    final nowLocal = DateTime.now();
    final rangePattern = RegExp(
      r'(.+?)\s*(?:-|to|until|->|–)\s*(.+)',
      caseSensitive: false,
    );
    final rangeMatch = rangePattern.firstMatch(text);
    if (rangeMatch != null) {
      final startMinutes = _parseClockMinutes(rangeMatch.group(1)!);
      final endMinutes = _parseClockMinutes(rangeMatch.group(2)!);
      if (startMinutes == null || endMinutes == null) return null;
      final start = _nextLocalDateTimeForClock(nowLocal, startMinutes);
      var end = _localDateTimeForClock(start, endMinutes);
      if (!end.isAfter(start)) end = end.add(const Duration(days: 1));
      return (start, end);
    }

    final singleMinutes = _parseClockMinutes(text);
    if (singleMinutes == null) return null;
    final when = _nextLocalDateTimeForClock(nowLocal, singleMinutes);
    return (when, when.add(const Duration(minutes: 30)));
  }

  int? _parseClockMinutes(String raw) {
    final text = raw.trim().toLowerCase();
    if (text.isEmpty) return null;

    final ampmPattern = RegExp(r'^(\d{1,2})(?::(\d{2}))?\s*([ap])\.?m?\.?$');
    final ampm = ampmPattern.firstMatch(text);
    if (ampm != null) {
      final hourRaw = int.tryParse(ampm.group(1)!);
      final minuteRaw = int.tryParse(ampm.group(2) ?? '0');
      final marker = ampm.group(3);
      if (hourRaw == null ||
          minuteRaw == null ||
          hourRaw < 1 ||
          hourRaw > 12 ||
          minuteRaw < 0 ||
          minuteRaw > 59 ||
          marker == null) {
        return null;
      }
      var hour24 = hourRaw % 12;
      if (marker == 'p') hour24 += 12;
      return hour24 * 60 + minuteRaw;
    }

    final hhmmPattern = RegExp(r'^(\d{1,2})(?::(\d{2}))$');
    final hhmm = hhmmPattern.firstMatch(text);
    if (hhmm != null) {
      final hour = int.tryParse(hhmm.group(1)!);
      final minute = int.tryParse(hhmm.group(2)!);
      if (hour == null ||
          minute == null ||
          hour < 0 ||
          hour > 23 ||
          minute < 0 ||
          minute > 59) {
        return null;
      }
      return hour * 60 + minute;
    }

    final hourOnly = int.tryParse(text);
    if (hourOnly == null || hourOnly < 0 || hourOnly > 23) return null;
    return hourOnly * 60;
  }

  DateTime _nextLocalDateTimeForClock(DateTime nowLocal, int minutes) {
    final candidate = _localDateTimeForClock(nowLocal, minutes);
    if (!candidate.isBefore(nowLocal)) return candidate;
    return candidate.add(const Duration(days: 1));
  }

  DateTime _localDateTimeForClock(DateTime date, int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  String _fmtLocalDateTime(DateTime dt) {
    final yyyy = dt.year.toString().padLeft(4, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd $hh:$min';
  }

  String? _sourceAddressLabel() {
    if (_pickupSourceType == _pickupFromStore) {
      final address = _merchantBranchAddress?.trim();
      if (address != null && address.isNotEmpty) return address;
      return null;
    }

    final sourcePickup = _selectedSourcePickupPoint();
    final address = sourcePickup?.addressText.trim();
    if (address != null && address.isNotEmpty) return address;

    return null;
  }

  String? _sourceCoordinatesLabel() {
    if (_pickupSourceType == _pickupFromStore) {
      if (_merchantBranchLat != null && _merchantBranchLng != null) {
        return _formatCoordinates(_merchantBranchLat!, _merchantBranchLng!);
      }
      return null;
    }

    final sourcePickup = _selectedSourcePickupPoint();
    if (sourcePickup?.lat != null && sourcePickup?.lng != null) {
      return _formatCoordinates(sourcePickup!.lat!, sourcePickup.lng!);
    }

    return null;
  }

  String? _destinationAddressLabel() {
    switch (_dropoffType) {
      case _dropoffHome:
        final address = _addressCtrl.text.trim();
        return address.isEmpty ? null : address;

      case _dropoffPickupSpecific:
        final destinationPickup = _destinationPickupPoint();
        final pickupAddress = destinationPickup?.addressText.trim();
        if (pickupAddress != null && pickupAddress.isNotEmpty) {
          return pickupAddress;
        }

        final fallback = _addressCtrl.text.trim();
        return fallback.isEmpty ? null : fallback;

      default:
        final address = _addressCtrl.text.trim();
        return address.isEmpty ? null : address;
    }
  }

  String? _destinationCoordinatesLabel() {
    switch (_dropoffType) {
      case _dropoffHome:
        if (_selectedCustomerLat != null && _selectedCustomerLng != null) {
          return _formatCoordinates(
            _selectedCustomerLat!,
            _selectedCustomerLng!,
          );
        }
        return null;

      case _dropoffPickupSpecific:
        final destinationPickup = _destinationPickupPoint();
        if (destinationPickup?.lat != null && destinationPickup?.lng != null) {
          return _formatCoordinates(
            destinationPickup!.lat!,
            destinationPickup.lng!,
          );
        }
        return null;

      default:
        return null;
    }
  }

  String? _customerRequestedCoordinatesLabel() {
    if (_selectedCustomerLat != null && _selectedCustomerLng != null) {
      return _formatCoordinates(_selectedCustomerLat!, _selectedCustomerLng!);
    }
    return null;
  }

  String _formatCoordinates(double lat, double lng) {
    return '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
  }

  String _sourceLabel({
    String? sourcePickupId,
    List<_PickupPointOption>? sourceCandidates,
  }) {
    if (_pickupSourceType == _pickupFromStore) {
      return _merchantBranchName?.isNotEmpty == true
          ? _merchantBranchName!
          : _pickupFromStore;
    }

    final selectedId = sourcePickupId ?? _selectedSourcePickupPointId;
    final point =
        _pickupPointByIdFrom(
          selectedId,
          sourceCandidates ?? _sourcePickupPoints,
        ) ??
        _pickupPointById(selectedId);
    return point?.displayName ?? 'Pickup Point';
  }

  String _destinationLabel({
    List<_PickupPointOption>? destinationCandidates,
  }) {
    switch (_dropoffType) {
      case _dropoffHome:
        return _dropoffHome;
      case _dropoffPickupSpecific:
        final point =
            _pickupPointByIdFrom(
              _selectedDestinationPickupPointId,
              destinationCandidates ?? _destinationPickupPoints,
            ) ??
            _pickupPointById(_selectedDestinationPickupPointId);
        return point?.displayName ?? 'Specific Pickup Point';
      default:
        return _dropoffHome;
    }
  }

  String _resultValue(Map<String, dynamic> result, List<String> keys) {
    String? readFrom(Map<String, dynamic> map) {
      for (final key in keys) {
        final value = map[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString();
        }
      }
      return null;
    }

    final topLevel = readFrom(result);
    if (topLevel != null) return topLevel;

    for (final nestedKey in ['order', 'data']) {
      final nested = result[nestedKey];
      if (nested is Map) {
        final nestedValue = readFrom(
          nested.map((key, value) => MapEntry(key.toString(), value)),
        );
        if (nestedValue != null) return nestedValue;
      }
    }

    return '-';
  }

  void _resetForm() {
    _customerNameCtrl.clear();
    _phoneCtrl.clear();
    _emailCtrl.clear();
    _addressCtrl.clear();
    _timeWindowCtrl.clear();
    _notesCtrl.clear();
    _pickupPointSearchCtrl.clear();
    _parcelDescriptionCtrl.clear();
    _itemCountCtrl.text = '1';
    _estimatedWeightCtrl.clear();
    _estimatedVolumeCtrl.clear();

    setState(() {
      _pickupSourceType = _pickupFromStore;
      _dropoffType = _dropoffHome;
      _selectedSourcePickupPointId = null;
      _selectedDestinationPickupPointId = null;
      _selectedDeliveryCompanyId = null;
      _recommendedDeliveryCompanyId = null;
      _sourcePickupPoints = const [];
      _destinationPickupPoints = const [];
      _filteredDeliveryCompanies = const [];
      _paymentMethod = PaymentMethod.cashAtPickup;
      _paymentAmount = 0;
      _paymentFieldRevision++;
      _selectedCustomerLat = null;
      _selectedCustomerLng = null;
      _automationHint = null;
    });

    _recomputeAutomation();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? _W.red : null,
      ),
    );
  }

  bool _containsPickup(List<_PickupPointOption> points, String? id) {
    if (id == null || id.isEmpty) return false;
    return points.any((point) => point.id == id);
  }

  _PickupPointOption? _pickupPointById(String? id) {
    return _pickupPointByIdFrom(id, _allPickupPoints);
  }

  _PickupPointOption? _pickupPointByIdFrom(
    String? id,
    List<_PickupPointOption> points,
  ) {
    if (id == null || id.isEmpty) return null;
    for (final point in points) {
      if (point.id == id) return point;
    }
    return null;
  }

  _PickupPointOption? _selectedSourcePickupPoint() {
    return _pickupPointByIdFrom(
          _selectedSourcePickupPointId,
          _sourcePickupPoints,
        ) ??
        _pickupPointById(_selectedSourcePickupPointId);
  }

  _PickupPointOption? _destinationPickupPoint() {
    return _pickupPointByIdFrom(
          _selectedDestinationPickupPointId,
          _destinationPickupPoints,
        ) ??
        _pickupPointById(_selectedDestinationPickupPointId);
  }

  _DeliveryCompanyOption? _selectedCompany() {
    for (final company in _filteredDeliveryCompanies) {
      if (company.id == _selectedDeliveryCompanyId) return company;
    }

    for (final company in _allDeliveryCompanies) {
      if (company.id == _selectedDeliveryCompanyId) return company;
    }

    return null;
  }

  List<_PickupPointOption> get _filteredPickupPoints {
    final query = _pickupPointSearchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return _sourcePickupPoints;

    return _sourcePickupPoints.where((point) {
      final haystack =
          '${point.name} ${point.subtitle ?? ''} ${point.city} ${point.area}'
              .toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  String get _summaryCustomer => _customerNameCtrl.text.trim().isEmpty
      ? '-'
      : _customerNameCtrl.text.trim();

  String get _summaryEmail =>
      _emailCtrl.text.trim().isEmpty ? '-' : _emailCtrl.text.trim();

  String get _summaryPickupSource => _sourceLabel();

  String get _summaryDropoff => _destinationLabel();

  String get _summaryCompany {
    if (_filteredDeliveryCompanies.isEmpty) return 'No recommended companies';
    return _selectedCompany()?.name ?? 'Not selected';
  }

  String get _summaryPaymentAmount {
    if (_paymentAmount <= 0) return '-';
    return '\$${_paymentAmount.toStringAsFixed(2)}';
  }

  String get _summaryPackageType => _parcelDescriptionCtrl.text.trim().isEmpty
      ? '-'
      : _parcelDescriptionCtrl.text.trim();

  String get _summaryItemCount {
    final value = _itemCountCtrl.text.trim();
    return value.isEmpty ? '-' : value;
  }

  String get _summaryWeight {
    final value = _estimatedWeightCtrl.text.trim();
    return value.isEmpty ? '-' : '$value kg';
  }

  String get _summaryVolume {
    final value = _estimatedVolumeCtrl.text.trim();
    return value.isEmpty ? '-' : '$value m³';
  }

  String get _summaryMapLocation {
    if (_selectedCustomerLat == null || _selectedCustomerLng == null) {
      return 'Not selected';
    }
    return '${_selectedCustomerLat!.toStringAsFixed(6)}, ${_selectedCustomerLng!.toStringAsFixed(6)}';
  }

  String get _deliveryCompanySubtitle {
    return 'Nearest 3 to merchant; capacity first';
  }

  String get _submitHint {
    if (_loadingFormData) return 'Loading merchant routing data...';
    if (_submitting) return 'Creating order and payment...';
    if (_loadError != null) {
      return _loadError ?? 'Unable to load merchant data.';
    }
    if (_automationHint != null && _automationHint!.trim().isNotEmpty) {
      return _automationHint!;
    }
    if (_canSubmit) return 'Ready to create the delivery order.';

    if (_customerNameCtrl.text.trim().isEmpty) {
      return 'Add customer name to continue.';
    }
    if (_phoneCtrl.text.trim().isEmpty) {
      return 'Add phone number to continue.';
    }
    if (_pickupSourceType == _pickupFromPickupPoint &&
        _selectedSourcePickupPointId == null) {
      return 'Select a source pickup point to continue.';
    }
    if (_dropoffType == _dropoffHome && _addressCtrl.text.trim().isEmpty) {
      return 'Add dropoff address to continue.';
    }
    if (_dropoffType == _dropoffPickupSpecific &&
        _selectedDestinationPickupPointId == null) {
      return 'Select a destination pickup point to continue.';
    }
    if (_allDeliveryCompanies.isNotEmpty && _filteredDeliveryCompanies.isEmpty) {
      return 'No available recommended delivery company right now.';
    }
    if (_filteredDeliveryCompanies.isNotEmpty &&
        _selectedDeliveryCompanyId == null) {
      return 'Select a recommended delivery company to continue.';
    }
    if (_paymentAmount <= 0) {
      return 'Enter the payment amount to continue.';
    }
    final itemCount = _parseItemCount();
    if (itemCount != null && itemCount <= 0) {
      return 'Item count must be greater than zero.';
    }

    return 'Complete the required fields to continue.';
  }

  Color get _submitHintColor {
    if (_canSubmit) return _W.green;
    if (_loadingFormData || _submitting) return _W.blue;
    if (_loadError != null) return _W.red;
    return _W.gray;
  }

  @override
  void dispose() {
    for (final controller in [
      _customerNameCtrl,
      _phoneCtrl,
      _emailCtrl,
      _addressCtrl,
      _timeWindowCtrl,
      _notesCtrl,
      _pickupPointSearchCtrl,
      _parcelDescriptionCtrl,
      _itemCountCtrl,
      _estimatedWeightCtrl,
      _estimatedVolumeCtrl,
    ]) {
      controller.removeListener(_refresh);
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showSourcePickupSelector =
        _pickupSourceType == _pickupFromPickupPoint;
    final showDestinationPickupSelector =
        _dropoffType == _dropoffPickupSpecific;

    final showAddressField = _dropoffType == _dropoffHome;

    final backupPickup = _dropoffType == _dropoffHome
        ? _destinationPickupPoint()
        : null;

    return Scaffold(
      backgroundColor: _W.bg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              14,
              0,
              14,
              28 + MediaQuery.of(context).padding.bottom,
            ),
            children: [
              const _TopBar(),
              const SizedBox(height: 4),
              const _HeroBanner(),
              const SizedBox(height: 14),
              if (_loadError != null) ...[
                _InfoBox(
                  icon: Icons.error_outline,
                  text: _loadError ?? 'Unable to load merchant data.',
                  color: _W.red,
                  background: _W.redLt,
                ),
                const SizedBox(height: 12),
              ],
              _SectionCard(
                icon: Icons.person_outline,
                iconColor: _W.blue,
                iconBg: _W.blueLt,
                title: 'Customer Information',
                subtitle: 'Recipient details for this delivery',
                child: Column(
                  children: [
                    _FormField(
                      controller: _customerNameCtrl,
                      label: 'Full Name',
                      hint: 'Sarah Johnson',
                      icon: Icons.person_outline,
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'Customer name is required'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    _FormField(
                      controller: _phoneCtrl,
                      label: 'Phone Number',
                      hint: '+961 71 000 000',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'Phone number is required'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    _FormField(
                      controller: _emailCtrl,
                      label: 'Email Address (Optional)',
                      hint: 'customer@email.com',
                      icon: Icons.mail_outline,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null) return null;
                        return _isValidEmail(value)
                            ? null
                            : 'Please enter a valid email address';
                      },
                    ),
                    const SizedBox(height: 12),
                    _FormField(
                      controller: _notesCtrl,
                      label: 'Notes (Optional)',
                      hint: 'Call before arriving',
                      icon: Icons.notes_outlined,
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                icon: Icons.location_on_outlined,
                iconColor: _W.amber,
                iconBg: _W.amberLt,
                title: 'Delivery Routing',
                subtitle: 'Pickup source and dropoff destination',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel('PICKUP SOURCE'),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final buttonWidth = constraints.maxWidth.isFinite
                            ? (constraints.maxWidth - 8) / 2
                            : 160.0;
                        return Row(
                          children: [
                            SizedBox(
                              width: buttonWidth,
                              child: _SegmentButton(
                                icon: Icons.storefront_outlined,
                                label: _pickupFromStore,
                                selected: _pickupSourceType == _pickupFromStore,
                                onTap: () =>
                                    _onPickupSourceChanged(_pickupFromStore),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: buttonWidth,
                              child: _SegmentButton(
                                icon: Icons.store_mall_directory_outlined,
                                label: _pickupFromPickupPoint,
                                selected:
                                    _pickupSourceType == _pickupFromPickupPoint,
                                onTap: () => _onPickupSourceChanged(
                                  _pickupFromPickupPoint,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    if (_pickupSourceType == _pickupFromStore)
                      _InfoBox(
                        icon: Icons.storefront_outlined,
                        text:
                            'Source: ${_merchantBranchName ?? 'Main Branch'}'
                            '${(_merchantBranchAddress ?? '').trim().isEmpty ? '' : ' — ${_merchantBranchAddress!}'}',
                        color: _W.blue,
                        background: _W.blueLt,
                      ),
                    if (showSourcePickupSelector) ...[
                      if (_sourcePickupPoints.isEmpty)
                        const _InfoBox(
                          icon: Icons.info_outline,
                          text: 'No approved pickup points found in the system.',
                          color: _W.blue,
                          background: _W.blueLt,
                        )
                      else ...[
                        _InlineHint(
                          icon: Icons.auto_awesome_outlined,
                          text:
                              'Recommended: ${_sourcePickupPoints.first.displayName}',
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          key: ValueKey(
                            'source-pickup-${_selectedSourcePickupPointId ?? 'none'}-${_sourcePickupPoints.length}',
                          ),
                          initialValue:
                              _sourcePickupPoints.any(
                                (point) =>
                                    point.id == _selectedSourcePickupPointId,
                              )
                              ? _selectedSourcePickupPointId
                              : null,
                          isExpanded: true,
                          decoration: _inputDecor(
                            label: 'Source Pickup Point',
                            hint: 'Choose source pickup point',
                            icon: Icons.store_mall_directory_outlined,
                          ),
                          items: _sourcePickupPoints
                              .map(
                                (point) => DropdownMenuItem<String>(
                                  value: point.id,
                                  child: Text(
                                    point.id == _sourcePickupPoints.first.id
                                        ? 'Recommended • ${point.displayName}'
                                        : point.displayName,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: _t(14, FontWeight.w600),
                                  ),
                                ),
                              )
                              .toList(),
                          validator: (value) =>
                              _pickupSourceType == _pickupFromPickupPoint &&
                                  value == null
                              ? 'Please select a source pickup point'
                              : null,
                          onChanged: _loadingFormData
                              ? null
                              : _onSourcePickupChanged,
                        ),
                      ],
                    ],
                    const SizedBox(height: 18),
                    const _FieldLabel('DROPOFF DESTINATION'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ChoiceChipButton(
                          label: _dropoffHome,
                          selected: _dropoffType == _dropoffHome,
                          onTap: () => _onDropoffTypeChanged(_dropoffHome),
                        ),
                        _ChoiceChipButton(
                          label: _dropoffPickupSpecific,
                          selected: _dropoffType == _dropoffPickupSpecific,
                          onTap: () =>
                              _onDropoffTypeChanged(_dropoffPickupSpecific),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (showAddressField) ...[
                      _FormField(
                        controller: _addressCtrl,
                        label: 'Customer Address',
                        hint: 'Beirut, Hamra St.',
                        icon: Icons.location_on_outlined,
                        validator: (value) {
                          if (!showAddressField) return null;
                          if (_dropoffType == _dropoffHome) {
                            return (value == null || value.trim().isEmpty)
                                ? 'Address is required'
                                : null;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _openMapPicker,
                        icon: const Icon(Icons.map_outlined),
                        label: Text(
                          _selectedCustomerLat == null ||
                                  _selectedCustomerLng == null
                              ? 'Pick on Map'
                              : 'Change Map Location',
                        ),
                      ),
                      if (_selectedCustomerLat != null &&
                          _selectedCustomerLng != null) ...[
                        const SizedBox(height: 10),
                        _InfoBox(
                          icon: Icons.place_outlined,
                          text:
                              'Selected map location: ${_selectedCustomerLat!.toStringAsFixed(6)}, ${_selectedCustomerLng!.toStringAsFixed(6)}',
                          color: _W.blue,
                          background: _W.blueLt,
                        ),
                      ],
                      const SizedBox(height: 12),
                    ],
                    if (_dropoffType == _dropoffHome) ...[
                      if (_selectedCustomerLat == null ||
                          _selectedCustomerLng == null)
                        const _InlineHint(
                          icon: Icons.map_outlined,
                          text:
                              'Pick the customer map location to suggest a backup pickup point.',
                        ),
                      if (_selectedCustomerLat == null ||
                          _selectedCustomerLng == null)
                        const SizedBox(height: 10),
                      if (_destinationPickupPoints.isEmpty)
                        const _InfoBox(
                          icon: Icons.info_outline,
                          text: 'No approved pickup points found in the system.',
                          color: _W.blue,
                          background: _W.blueLt,
                        )
                      else ...[
                        if (_selectedCustomerLat != null &&
                            _selectedCustomerLng != null &&
                            backupPickup != null) ...[
                          _InlineHint(
                            icon: Icons.auto_awesome_outlined,
                            text: 'Recommended backup: ${backupPickup.displayName}',
                          ),
                          const SizedBox(height: 10),
                        ],
                        DropdownButtonFormField<String>(
                          key: ValueKey(
                            'backup-pickup-${_selectedDestinationPickupPointId ?? 'none'}',
                          ),
                          initialValue: _selectedDestinationPickupPointId,
                          isExpanded: true,
                          decoration: _inputDecor(
                            label: 'Backup Pickup Point',
                            hint: 'Choose backup pickup point',
                            icon: Icons.pin_drop_outlined,
                          ),
                          items: _destinationPickupPoints
                              .map(
                                (point) => DropdownMenuItem<String>(
                                  value: point.id,
                                  child: Text(
                                    (_selectedCustomerLat != null &&
                                            _selectedCustomerLng != null &&
                                            point.id == _destinationPickupPoints.first.id)
                                        ? 'Recommended • ${point.displayName}'
                                        : point.displayName,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: _t(14, FontWeight.w600),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: _loadingFormData ? null : _onDestinationPickupChanged,
                        ),
                      ],
                    ],
                    if (showDestinationPickupSelector) ...[
                      if (_destinationPickupPoints.isEmpty)
                        const _InfoBox(
                          icon: Icons.info_outline,
                          text: 'No approved pickup points found in the system.',
                          color: _W.blue,
                          background: _W.blueLt,
                        )
                      else
                        DropdownButtonFormField<String>(
                          key: ValueKey(
                            'destination-pickup-${_selectedDestinationPickupPointId ?? 'none'}',
                          ),
                          initialValue: _selectedDestinationPickupPointId,
                          isExpanded: true,
                          decoration: _inputDecor(
                            label: 'Specific Pickup Point Destination',
                            hint: 'Choose destination pickup point',
                            icon: Icons.pin_drop_outlined,
                          ),
                          items: _destinationPickupPoints
                              .map(
                                (point) => DropdownMenuItem<String>(
                                  value: point.id,
                                  child: Text(
                                    point.displayName,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: _t(14, FontWeight.w500),
                                  ),
                                ),
                              )
                              .toList(),
                          validator: (value) =>
                              _dropoffType == _dropoffPickupSpecific && value == null
                              ? 'Please select a destination pickup point'
                              : null,
                          onChanged: _loadingFormData ? null : _onDestinationPickupChanged,
                        ),
                    ],
                    const SizedBox(height: 12),
                    _FormField(
                      controller: _timeWindowCtrl,
                      label: 'Preferred Time Window (Optional)',
                      hint: '4 PM - 6 PM',
                      icon: Icons.access_time_outlined,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                icon: Icons.inventory_2_outlined,
                iconColor: _W.slate,
                iconBg: _W.slateLt,
                title: 'Package Information',
                subtitle: 'Optional shipment details',
                child: Column(
                  children: [
                    _FormField(
                      controller: _parcelDescriptionCtrl,
                      label: 'Package Description',
                      hint: 'Documents, clothes, electronics...',
                      icon: Icons.inventory_2_outlined,
                    ),
                    const SizedBox(height: 12),
                    _FormField(
                      controller: _itemCountCtrl,
                      label: 'Item Count',
                      hint: '1',
                      icon: Icons.format_list_numbered_outlined,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        final raw = value?.trim() ?? '';
                        if (raw.isEmpty) return null;
                        final parsed = int.tryParse(raw);
                        if (parsed == null || parsed <= 0) {
                          return 'Enter a valid item count';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _FormField(
                            controller: _estimatedWeightCtrl,
                            label: 'Weight (kg)',
                            hint: '2.5',
                            icon: Icons.scale_outlined,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: (value) {
                              final raw = value?.trim() ?? '';
                              if (raw.isEmpty) return null;
                              final parsed = double.tryParse(raw);
                              if (parsed == null || parsed <= 0) {
                                return 'Invalid weight';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _FormField(
                            controller: _estimatedVolumeCtrl,
                            label: 'Volume (m³)',
                            hint: '0.02',
                            icon: Icons.straighten_outlined,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: (value) {
                              final raw = value?.trim() ?? '';
                              if (raw.isEmpty) return null;
                              final parsed = double.tryParse(raw);
                              if (parsed == null || parsed <= 0) {
                                return 'Invalid volume';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                icon: Icons.local_shipping_outlined,
                iconColor: _W.blue,
                iconBg: _W.blueLt,
                title: 'Delivery Company',
                subtitle: 'Recommended companies only',
                child: _allDeliveryCompanies.isEmpty
                    ? const _InfoBox(
                        icon: Icons.info_outline,
                        text:
                            'No linked delivery companies found for this merchant.',
                        color: _W.blue,
                        background: _W.blueLt,
                      )
                    : _filteredDeliveryCompanies.isEmpty
                    ? Column(
                        children: [
                          if (_automationHint != null)
                            _InfoBox(
                              icon: Icons.info_outline,
                              text: _automationHint!,
                              color: _W.blue,
                              background: _W.blueLt,
                            ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _InlineHint(
                            icon: Icons.auto_awesome_outlined,
                            text: 'Recommended companies only.',
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            key: ValueKey(
                              'company-${_selectedDeliveryCompanyId ?? 'none'}',
                            ),
                            initialValue: _selectedDeliveryCompanyId,
                            isExpanded: true,
                            decoration: _inputDecor(
                              label: 'Select Delivery Company',
                              hint: 'Choose recommended company',
                              icon: Icons.local_shipping_outlined,
                            ),
                            items: _filteredDeliveryCompanies
                                .map(
                                  (company) => DropdownMenuItem<String>(
                                    value: company.id,
                                    child: Text(
                                      company.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: _t(14, FontWeight.w500),
                                    ),
                                  ),
                                )
                                .toList(),
                            validator: (value) =>
                                _filteredDeliveryCompanies.isNotEmpty &&
                                    value == null
                                ? 'Please select a delivery company'
                                : null,
                            onChanged: _loadingFormData
                                ? null
                                : (value) => setState(
                                    () => _selectedDeliveryCompanyId = value,
                                  ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                icon: Icons.payments_outlined,
                iconColor: _W.green,
                iconBg: _W.greenLt,
                title: 'Payment',
                subtitle: 'Payment method and amount',
                child: PaymentMethodSelector(
                  key: ValueKey(_paymentFieldRevision),
                  selected: _paymentMethod,
                  amount: _paymentAmount,
                  onMethodChanged: (method) =>
                      setState(() => _paymentMethod = method),
                  onAmountChanged: (amount) =>
                      setState(() => _paymentAmount = amount),
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                icon: Icons.checklist_outlined,
                iconColor: _W.slate,
                iconBg: _W.slateLt,
                title: 'Order Summary',
                subtitle: 'Review before submitting',
                child: Column(
                  children: [
                    _SummaryRow(label: 'Customer', value: _summaryCustomer),
                    _SummaryRow(label: 'Email', value: _summaryEmail),
                    _SummaryRow(label: 'Source', value: _summaryPickupSource),
                    _SummaryRow(label: 'Destination', value: _summaryDropoff),
                    _SummaryRow(label: 'Company', value: _summaryCompany),
                    _SummaryRow(label: 'Map', value: _summaryMapLocation),
                    _SummaryRow(label: 'Package', value: _summaryPackageType),
                    _SummaryRow(label: 'Items', value: _summaryItemCount),
                    _SummaryRow(label: 'Weight', value: _summaryWeight),
                    _SummaryRow(label: 'Volume', value: _summaryVolume),
                    _SummaryRow(
                      label: 'Payment',
                      value: _paymentMethod.displayName,
                    ),
                    _SummaryRow(
                      label: 'Amount',
                      value: _summaryPaymentAmount,
                      valueColor: _W.blue,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _submitHint,
                style: _t(
                  12.5,
                  FontWeight.w600,
                  color: _submitHintColor,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              _SubmitButton(
                onTap: _submitOrder,
                loading: _submitting,
                enabled: _canSubmit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static double? _asDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().trim());
  }

  static int? _asInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().trim());
  }

  static double _distanceKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadiusKm = 6371.0;

    final dLat = _degToRad(lat2 - lat1);
    final dLng = _degToRad(lng2 - lng1);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  static double _degToRad(double degree) => degree * math.pi / 180.0;
}

class _DeliveryCompanyBasicOption {
  final String id;
  final String name;

  const _DeliveryCompanyBasicOption({required this.id, required this.name});
}

class _DeliveryCompanyOption {
  final String id;
  final String name;
  final List<_CompanyHub> hubs;
  final _CompanyCapacity? capacity;

  const _DeliveryCompanyOption({
    required this.id,
    required this.name,
    required this.hubs,
    required this.capacity,
  });
}

class _CompanyHub {
  final String id;
  final String name;
  final String addressText;
  final String city;
  final String area;
  final double? lat;
  final double? lng;
  final bool isActive;

  const _CompanyHub({
    required this.id,
    required this.name,
    required this.addressText,
    required this.city,
    required this.area,
    required this.lat,
    required this.lng,
    required this.isActive,
  });

  bool get isUsable => isActive && lat != null && lng != null;
}

class _CompanyCapacity {
  final int? maxActiveOrders;
  final int? maxDailyOrders;
  final int currentActiveOrders;
  final int currentDailyOrders;
  final bool isActive;

  const _CompanyCapacity({
    required this.maxActiveOrders,
    required this.maxDailyOrders,
    required this.currentActiveOrders,
    required this.currentDailyOrders,
    required this.isActive,
  });

  int get remainingActiveOrders {
    if (maxActiveOrders == null) return 999999;
    return maxActiveOrders! - currentActiveOrders;
  }

  int get remainingDailyOrders {
    if (maxDailyOrders == null) return 999999;
    return maxDailyOrders! - currentDailyOrders;
  }
}

class _MerchantNearestCompany {
  final _DeliveryCompanyOption company;
  final _CompanyHub nearestHub;
  final double merchantDistanceKm;

  const _MerchantNearestCompany({
    required this.company,
    required this.nearestHub,
    required this.merchantDistanceKm,
  });
}

class _RankedCompanyForMerchant {
  final _DeliveryCompanyOption company;
  final _CompanyHub? bestHub;
  final double merchantDistanceKm;
  final double destinationDistanceKm;
  final int remainingActiveOrders;
  final int remainingDailyOrders;

  const _RankedCompanyForMerchant({
    required this.company,
    required this.bestHub,
    required this.merchantDistanceKm,
    required this.destinationDistanceKm,
    required this.remainingActiveOrders,
    required this.remainingDailyOrders,
  });
}

class _MerchantBranchOption {
  final String id;
  final String name;
  final String addressText;
  final double? lat;
  final double? lng;

  const _MerchantBranchOption({
    required this.id,
    required this.name,
    required this.addressText,
    required this.lat,
    required this.lng,
  });
}

class _PickupPointOption {
  final String id;
  final String name;
  final String? subtitle;
  final String addressText;
  final double? lat;
  final double? lng;
  final String city;
  final String area;
  final int usageCount;
  final double averageRating;
  final int reviewCount;

  const _PickupPointOption({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.addressText,
    required this.lat,
    required this.lng,
    required this.city,
    required this.area,
    this.usageCount = 0,
    this.averageRating = 0,
    this.reviewCount = 0,
  });

  String get displayName {
    final detail = subtitle?.trim();
    if (detail == null || detail.isEmpty) return name;
    return '$name - $detail';
  }

  String get starsLabel =>
      reviewCount <= 0 ? '' : averageRating.toStringAsFixed(1);
}

class _LatLngOption {
  final double lat;
  final double lng;

  const _LatLngOption({required this.lat, required this.lng});
}

class _PickedMapLocation {
  final double lat;
  final double lng;
  final String address;

  const _PickedMapLocation({
    required this.lat,
    required this.lng,
    required this.address,
  });
}

class _MapPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final String initialAddress;

  const _MapPickerScreen({
    required this.initialLat,
    required this.initialLng,
    required this.initialAddress,
  });

  @override
  State<_MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<_MapPickerScreen> {
  late final TextEditingController _addressController;
  late LatLng _selectedLatLng;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController(text: widget.initialAddress);
    _selectedLatLng = LatLng(
      widget.initialLat ?? 33.8938,
      widget.initialLng ?? 35.5018,
    );
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _zoomIn() async {
    final controller = _mapController;
    if (controller == null) return;
    await controller.animateCamera(CameraUpdate.zoomIn());
  }

  Future<void> _zoomOut() async {
    final controller = _mapController;
    if (controller == null) return;
    await controller.animateCamera(CameraUpdate.zoomOut());
  }

  void _confirm() {
    Navigator.of(context).pop(
      _PickedMapLocation(
        lat: _selectedLatLng.latitude,
        lng: _selectedLatLng.longitude,
        address: _addressController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _W.bg,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: _W.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text('Pick Location on Map', style: _t(18, FontWeight.w900)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: TextField(
                controller: _addressController,
                decoration: _inputDecor(
                  label: 'Address',
                  hint: 'Optional address text',
                  icon: Icons.location_on_outlined,
                ),
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _selectedLatLng,
                      zoom: 16,
                    ),
                    onMapCreated: (controller) {
                      _mapController = controller;
                    },
                    markers: {
                      Marker(
                        markerId: const MarkerId('selected_location'),
                        position: _selectedLatLng,
                      ),
                    },
                    onTap: (latLng) {
                      setState(() {
                        _selectedLatLng = latLng;
                      });
                    },
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    zoomGesturesEnabled: true,
                    scrollGesturesEnabled: true,
                    rotateGesturesEnabled: true,
                    tiltGesturesEnabled: true,
                    mapToolbarEnabled: true,
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Column(
                      children: [
                        _MapZoomButton(icon: Icons.add, onTap: _zoomIn),
                        const SizedBox(height: 8),
                        _MapZoomButton(icon: Icons.remove, onTap: _zoomOut),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(
                14,
                12,
                14,
                16 + MediaQuery.of(context).padding.bottom,
              ),
              decoration: const BoxDecoration(
                color: _W.white,
                border: Border(top: BorderSide(color: _W.border, width: 1.2)),
              ),
              child: Column(
                children: [
                  _InfoBox(
                    icon: Icons.place_outlined,
                    text:
                        'Selected: ${_selectedLatLng.latitude.toStringAsFixed(6)}, ${_selectedLatLng.longitude.toStringAsFixed(6)}',
                    color: _W.blue,
                    background: _W.blueLt,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _confirm,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Use This Location'),
                    ),
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

class _MapZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MapZoomButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: _W.navy),
        ),
      ),
    );
  }
}

class _ChoiceChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(
        label,
        style: _t(
          12.5,
          FontWeight.w700,
          color: selected ? Colors.white : _W.navy,
        ),
      ),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: _W.blue,
      backgroundColor: _W.bg,
      side: BorderSide(color: selected ? _W.blue : _W.border, width: 1.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
  static const redLt = Color(0xFFFFECEF);
  static const amber = Color(0xFFD4800A);
  static const amberLt = Color(0xFFFEF4E2);
  static const slate = Color(0xFF94A3B8);
  static const slateLt = Color(0xFFF1F4FC);
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
    letterSpacing: 0,
  );
}

InputDecoration _inputDecor({
  required String label,
  required String hint,
  required IconData icon,
}) {
  return InputDecoration(
    labelText: label,
    labelStyle: _t(12, FontWeight.w700, color: _W.gray),
    hintText: hint,
    hintStyle: _t(14, FontWeight.w400, color: _W.slate),
    prefixIcon: Icon(icon, size: 17, color: _W.slate),
    filled: true,
    fillColor: _W.bg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: _W.border, width: 1.5),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: _W.border, width: 1.5),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: _W.blue, width: 1.8),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: _W.red, width: 1.5),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: _W.red, width: 1.8),
    ),
  );
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _W.blue,
                  borderRadius: BorderRadius.circular(8),
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
                  style: _t(22, FontWeight.w900),
                  children: const [
                    TextSpan(text: 'wa'),
                    TextSpan(
                      text: 'sle',
                      style: TextStyle(color: _W.blue),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (Navigator.canPop(context))
            IconButton.filledTonal(
              tooltip: 'Back',
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.chevron_left),
            ),
        ],
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _W.blueDark,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create Order',
            style: _t(22, FontWeight.w900, color: Colors.white),
          ),
          const SizedBox(height: 5),
          Text(
            'Customer, routing, payment, and package details in one flow.',
            style: _t(
              13,
              FontWeight.w500,
              color: const Color(0xCCFFFFFF),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          const Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _StepChip(number: '1', label: 'Customer'),
              _StepChip(number: '2', label: 'Routing'),
              _StepChip(number: '3', label: 'Package'),
              _StepChip(number: '4', label: 'Payment'),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepChip extends StatelessWidget {
  final String number;
  final String label;

  const _StepChip({required this.number, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x1AFFFFFF),
        border: Border.all(color: const Color(0x33FFFFFF)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0x22FFFFFF),
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: _t(10, FontWeight.w800, color: Colors.white),
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: _t(12, FontWeight.w700, color: Colors.white)),
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
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _W.border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final textWidth = constraints.maxWidth.isFinite
                  ? (constraints.maxWidth > 46
                        ? constraints.maxWidth - 46
                        : 0.0)
                  : 220.0;
              return Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 17, color: iconColor),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: textWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _t(15, FontWeight.w800),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: _t(12, FontWeight.w500, color: _W.gray),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: _W.border),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _FormField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: _t(14, FontWeight.w500),
      decoration: _inputDecor(label: label, hint: hint, icon: icon),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String value;

  const _FieldLabel(this.value);

  @override
  Widget build(BuildContext context) {
    return Text(value, style: _t(11, FontWeight.w700, color: _W.gray));
  }
}

class _SegmentButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _W.blueLt : _W.bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? _W.blue : _W.border,
              width: 1.5,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final textWidth = constraints.maxWidth.isFinite
                  ? (constraints.maxWidth > 23
                        ? constraints.maxWidth - 23
                        : 0.0)
                  : 90.0;
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 17, color: selected ? _W.blue : _W.gray),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: textWidth,
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: _t(
                        13,
                        FontWeight.w700,
                        color: selected ? _W.blue : _W.gray,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _InlineHint extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InlineHint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: _W.blue),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _t(12.5, FontWeight.w700, color: _W.blue, height: 1.35),
          ),
        ),
      ],
    );
  }
}

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final Color background;

  const _InfoBox({
    required this.icon,
    required this.text,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.22), width: 1.3),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textWidth = constraints.maxWidth.isFinite
              ? (constraints.maxWidth > 28 ? constraints.maxWidth - 28 : 0.0)
              : 220.0;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 10),
              SizedBox(
                width: textWidth,
                child: Text(
                  text,
                  style: _t(12.5, FontWeight.w600, color: color, height: 1.4),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Table(
        columnWidths: const {0: FixedColumnWidth(92), 1: FlexColumnWidth()},
        children: [
          TableRow(
            children: [
              Text(label, style: _t(13, FontWeight.w600, color: _W.gray)),
              Text(
                value,
                style: _t(13, FontWeight.w700, color: valueColor ?? _W.navy),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool loading;
  final bool enabled;

  const _SubmitButton({
    required this.onTap,
    required this.loading,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = enabled && !loading;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: isEnabled ? 1 : 0.96,
      child: Material(
        color: isEnabled ? _W.blue : const Color(0xFFD7DDEA),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: isEnabled ? onTap : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isEnabled
                    ? _W.blueDark.withOpacity(0.18)
                    : const Color(0xFFC7D0E0),
                width: 1.2,
              ),
              boxShadow: isEnabled
                  ? [
                      BoxShadow(
                        color: _W.blue.withOpacity(0.18),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final textWidth = constraints.maxWidth.isFinite
                          ? (constraints.maxWidth > 30
                                ? constraints.maxWidth - 30
                                : 0.0)
                          : 180.0;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_circle_outline,
                            color: isEnabled
                                ? Colors.white
                                : const Color(0xFF6C7790),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: textWidth,
                            child: Text(
                              'Create Delivery Order',
                              overflow: TextOverflow.ellipsis,
                              style: _t(
                                15,
                                FontWeight.w800,
                                color: isEnabled
                                    ? Colors.white
                                    : const Color(0xFF6C7790),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

class _SuccessDialog extends StatelessWidget {
  final String orderId;
  final String trackingCode;
  final String pickupMethod;
  final String dropoffMethod;
  final String paymentMethod;
  final String amount;
  final String packageType;
  final String itemCount;
  final String weight;
  final String volume;
  final String mapLocation;
  final String company;

  const _SuccessDialog({
    required this.orderId,
    required this.trackingCode,
    required this.pickupMethod,
    required this.dropoffMethod,
    required this.paymentMethod,
    required this.amount,
    required this.packageType,
    required this.itemCount,
    required this.weight,
    required this.volume,
    required this.mapLocation,
    required this.company,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _W.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: _W.greenLt,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: _W.green,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text('Order Created', style: _t(20, FontWeight.w900)),
              const SizedBox(height: 6),
              Text(
                'The delivery order and payment record were created successfully.',
                style: _t(13, FontWeight.w500, color: _W.gray, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _W.bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _W.border),
                ),
                child: Column(
                  children: [
                    _DialogRow(label: 'Tracking', value: trackingCode),
                    const SizedBox(height: 8),
                    _DialogRow(label: 'Order ID', value: orderId),
                    const SizedBox(height: 8),
                    _DialogRow(label: 'Source', value: pickupMethod),
                    const SizedBox(height: 8),
                    _DialogRow(label: 'Destination', value: dropoffMethod),
                    const SizedBox(height: 8),
                    _DialogRow(label: 'Company', value: company),
                    const SizedBox(height: 8),
                    _DialogRow(label: 'Map', value: mapLocation),
                    const SizedBox(height: 8),
                    _DialogRow(label: 'Package', value: packageType),
                    const SizedBox(height: 8),
                    _DialogRow(label: 'Items', value: itemCount),
                    const SizedBox(height: 8),
                    _DialogRow(label: 'Weight', value: weight),
                    const SizedBox(height: 8),
                    _DialogRow(label: 'Volume', value: volume),
                    const SizedBox(height: 8),
                    _DialogRow(label: 'Payment', value: paymentMethod),
                    const SizedBox(height: 8),
                    _DialogRow(label: 'Amount', value: amount),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogRow extends StatelessWidget {
  final String label;
  final String value;

  const _DialogRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const {0: FixedColumnWidth(92), 1: FlexColumnWidth()},
      children: [
        TableRow(
          children: [
            Text(label, style: _t(12.5, FontWeight.w600, color: _W.gray)),
            Text(value, style: _t(13, FontWeight.w800, color: _W.navy)),
          ],
        ),
      ],
    );
  }
}
