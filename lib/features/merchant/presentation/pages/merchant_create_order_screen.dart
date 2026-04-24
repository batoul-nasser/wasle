import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wasle/core/services/payment_service.dart';
import 'package:wasle/features/payment/data/payment_model.dart';
import 'package:wasle/features/payment/presentation/widgets/payment_method_selector.dart';

class MerchantCreateOrderScreen extends StatefulWidget {
  const MerchantCreateOrderScreen({super.key});

  @override
  State<MerchantCreateOrderScreen> createState() =>
      _MerchantCreateOrderScreenState();
}

class _MerchantCreateOrderScreenState extends State<MerchantCreateOrderScreen> {
  final SupabaseClient _client = Supabase.instance.client;
  final PaymentService _paymentService = PaymentService();
  final _formKey = GlobalKey<FormState>();

  final _customerNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _timeWindowCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  final _parcelDescriptionCtrl = TextEditingController();
  final _itemCountCtrl = TextEditingController(text: '1');
  final _estimatedWeightCtrl = TextEditingController();
  final _estimatedVolumeCtrl = TextEditingController();

  String? _merchantId;
  String? _loadError;
  bool _loadingFormData = false;
  bool _submitting = false;

  String _pickupMethod = _pickupFromStore;
  String? _selectedPickupPointId;
  String? _selectedDeliveryCompanyId;
  List<_SelectOption> _pickupPoints = const [];
  List<_SelectOption> _deliveryCompanies = const [];

  PaymentMethod _paymentMethod = PaymentMethod.cashAtPickup;
  double _paymentAmount = 0;
  int _paymentFieldRevision = 0;

  static const _pickupFromStore = 'From Store';
  static const _pickupPoint = 'Pickup Point';

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
    });

    try {
      final merchantId = await _resolveMerchantId();
      final results = await Future.wait([
        _loadPickupPoints(merchantId),
        _loadDeliveryCompanies(merchantId),
      ]);

      if (!mounted) return;

      final pickupPoints = results[0];
      final deliveryCompanies = results[1];

      setState(() {
        _merchantId = merchantId;
        _pickupPoints = pickupPoints;
        _deliveryCompanies = deliveryCompanies;
        _selectedPickupPointId = pickupPoints.length == 1
            ? pickupPoints.first.id
            : null;
        _selectedDeliveryCompanyId = deliveryCompanies.length == 1
            ? deliveryCompanies.first.id
            : null;
        _loadingFormData = false;
      });
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

  Future<List<_SelectOption>> _loadPickupPoints(String merchantId) async {
    try {
      final rows = await _client
          .from('pickup_points')
          .select('id, name, address_text')
          .eq('merchant_id', merchantId)
          .eq('is_active', true)
          .order('name');

      return _optionsFromRows(rows, subtitleKey: 'address_text');
    } catch (_) {
      return const [];
    }
  }

  Future<List<_SelectOption>> _loadDeliveryCompanies(String merchantId) async {
    try {
      final mappingRows = await _client
          .from('merchant_delivery_companies')
          .select('company_id')
          .eq('merchant_id', merchantId)
          .eq('is_active', true);

      final companyIds = List<Map<String, dynamic>>.from(mappingRows)
          .map((row) => row['company_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      if (companyIds.isEmpty) return const [];

      final companyRows = await _client
          .from('delivery_companies')
          .select('id, name')
          .inFilter('id', companyIds);

      return _optionsFromRows(companyRows);
    } catch (_) {
      try {
        final companyRows = await _client
            .from('delivery_companies')
            .select('id, name')
            .order('name');
        return _optionsFromRows(companyRows);
      } catch (_) {
        return const [];
      }
    }
  }

  List<_SelectOption> _optionsFromRows(
    Object? rows, {
    String subtitleKey = '',
  }) {
    final options = List<Map<String, dynamic>>.from(rows as List)
        .map(
          (row) => _SelectOption(
            id: row['id']?.toString() ?? '',
            name: row['name']?.toString() ?? '',
            subtitle: subtitleKey.isEmpty ? null : row[subtitleKey]?.toString(),
          ),
        )
        .where((option) => option.id.isNotEmpty && option.name.isNotEmpty)
        .toList();

    options.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    return options;
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

  bool get _canSubmit {
    final hasCustomer = _customerNameCtrl.text.trim().isNotEmpty;
    final hasPhone = _phoneCtrl.text.trim().isNotEmpty;
    final hasAddress = _addressCtrl.text.trim().isNotEmpty;
    final hasPaymentAmount = _paymentAmount > 0;
    final pickupOk =
        _pickupMethod != _pickupPoint || _selectedPickupPointId != null;
    final companyOk =
        _deliveryCompanies.isEmpty || _selectedDeliveryCompanyId != null;
    final itemCount = _parseItemCount();
    final itemCountOk = itemCount == null || itemCount > 0;

    return !_loadingFormData &&
        !_submitting &&
        _merchantId != null &&
        hasCustomer &&
        hasPhone &&
        hasAddress &&
        hasPaymentAmount &&
        pickupOk &&
        companyOk &&
        itemCountOk;
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

    if (_pickupMethod == _pickupPoint && _selectedPickupPointId == null) {
      _showSnackBar('Please select a pickup point.', isError: true);
      return;
    }

    if (_deliveryCompanies.isNotEmpty && _selectedDeliveryCompanyId == null) {
      _showSnackBar('Please select a delivery company.', isError: true);
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

    setState(() => _submitting = true);

    try {
      final result = await _paymentService.createOrderWithPayment(
        merchantId: merchantId,
        branchId: null,
        customerName: _customerNameCtrl.text.trim(),
        customerPhone: _phoneCtrl.text.trim(),
        customerEmail: _emailCtrl.text.trim().isEmpty
            ? null
            : _emailCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        amount: _paymentAmount,
        paymentMethod: _paymentMethod,
        pickupPointId: _pickupMethod == _pickupPoint
            ? _selectedPickupPointId
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
          pickupMethod: _summaryPickup,
          paymentMethod: _paymentMethod.displayName,
          amount: _summaryPaymentAmount,
          packageType: _summaryPackageType,
          itemCount: _summaryItemCount,
          weight: _summaryWeight,
          volume: _summaryVolume,
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

    await _client.from('orders').update({
      'parcel_description': _parcelDescriptionCtrl.text.trim().isEmpty
          ? null
          : _parcelDescriptionCtrl.text.trim(),
      'item_count': _parseItemCount(),
      'estimated_weight': _parsePositiveDouble(_estimatedWeightCtrl.text),
      'estimated_volume': _parsePositiveDouble(_estimatedVolumeCtrl.text),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', orderId);
  }

  String? _mergedNotes() {
    final parts = <String>[];
    final notes = _notesCtrl.text.trim();
    final timeWindow = _timeWindowCtrl.text.trim();

    parts.add('Pickup method: $_pickupMethod');
    if (timeWindow.isNotEmpty) {
      parts.add('Preferred time window: $timeWindow');
    }
    if (notes.isNotEmpty) parts.add(notes);

    return parts.isEmpty ? null : parts.join('\n');
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
    _parcelDescriptionCtrl.clear();
    _itemCountCtrl.text = '1';
    _estimatedWeightCtrl.clear();
    _estimatedVolumeCtrl.clear();

    setState(() {
      _pickupMethod = _pickupFromStore;
      _selectedPickupPointId = _pickupPoints.length == 1
          ? _pickupPoints.first.id
          : null;
      _selectedDeliveryCompanyId = _deliveryCompanies.length == 1
          ? _deliveryCompanies.first.id
          : null;
      _paymentMethod = PaymentMethod.cashAtPickup;
      _paymentAmount = 0;
      _paymentFieldRevision++;
    });
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

  _SelectOption? _selectedPickupPoint() {
    for (final point in _pickupPoints) {
      if (point.id == _selectedPickupPointId) return point;
    }
    return null;
  }

  _SelectOption? _selectedCompany() {
    for (final company in _deliveryCompanies) {
      if (company.id == _selectedDeliveryCompanyId) return company;
    }
    return null;
  }

  String get _summaryCustomer => _customerNameCtrl.text.trim().isEmpty
      ? '-'
      : _customerNameCtrl.text.trim();

  String get _summaryEmail =>
      _emailCtrl.text.trim().isEmpty ? '-' : _emailCtrl.text.trim();

  String get _summaryPickup {
    if (_pickupMethod != _pickupPoint) return _pickupFromStore;

    final selected = _selectedPickupPoint();
    if (selected == null) return 'Not selected';
    return selected.displayName;
  }

  String get _summaryCompany {
    if (_deliveryCompanies.isEmpty) return 'No linked companies';
    return _selectedCompany()?.name ?? 'Not selected';
  }

  String get _summaryPaymentAmount {
    if (_paymentAmount <= 0) return '-';
    return '\$${_paymentAmount.toStringAsFixed(2)}';
  }

  String get _summaryPackageType =>
      _parcelDescriptionCtrl.text.trim().isEmpty
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

  String get _submitHint {
    if (_loadingFormData) return 'Loading merchant delivery data...';
    if (_submitting) return 'Creating order and payment...';
    if (_loadError != null) {
      return _loadError ?? 'Unable to load merchant data.';
    }
    if (_canSubmit) return 'Ready to create the delivery order.';

    if (_customerNameCtrl.text.trim().isEmpty) {
      return 'Add customer name to continue.';
    }
    if (_phoneCtrl.text.trim().isEmpty) {
      return 'Add phone number to continue.';
    }
    if (_addressCtrl.text.trim().isEmpty) {
      return 'Add dropoff address to continue.';
    }
    if (_pickupMethod == _pickupPoint && _selectedPickupPointId == null) {
      return 'Select a pickup point to continue.';
    }
    if (_deliveryCompanies.isNotEmpty && _selectedDeliveryCompanyId == null) {
      return 'Select a delivery company to continue.';
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
                title: 'Delivery Information',
                subtitle: 'Address and pickup configuration',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FormField(
                      controller: _addressCtrl,
                      label: 'Dropoff Address',
                      hint: 'Beirut, Hamra St.',
                      icon: Icons.location_on_outlined,
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'Address is required'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    _FormField(
                      controller: _timeWindowCtrl,
                      label: 'Preferred Time Window (Optional)',
                      hint: '4 PM - 6 PM',
                      icon: Icons.access_time_outlined,
                    ),
                    const SizedBox(height: 14),
                    const _FieldLabel('PICKUP METHOD'),
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
                                selected: _pickupMethod == _pickupFromStore,
                                onTap: () => setState(() {
                                  _pickupMethod = _pickupFromStore;
                                  _selectedPickupPointId = null;
                                }),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: buttonWidth,
                              child: _SegmentButton(
                                icon: Icons.store_mall_directory_outlined,
                                label: _pickupPoint,
                                selected: _pickupMethod == _pickupPoint,
                                onTap: () => setState(() {
                                  _pickupMethod = _pickupPoint;
                                  if (_pickupPoints.length == 1) {
                                    _selectedPickupPointId =
                                        _pickupPoints.first.id;
                                  }
                                }),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    if (_pickupMethod == _pickupPoint) ...[
                      const SizedBox(height: 12),
                      if (_pickupPoints.isEmpty)
                        const _InfoBox(
                          icon: Icons.info_outline,
                          text: 'No pickup points found for this merchant.',
                          color: _W.amber,
                          background: _W.amberLt,
                        )
                      else
                        DropdownButtonFormField<String>(
                          key: ValueKey(
                            'pickup-${_selectedPickupPointId ?? 'none'}',
                          ),
                          initialValue: _selectedPickupPointId,
                          isExpanded: true,
                          decoration: _inputDecor(
                            label: 'Select Pickup Point',
                            hint: 'Choose pickup point',
                            icon: Icons.store_mall_directory_outlined,
                          ),
                          items: _pickupPoints
                              .map(
                                (point) => DropdownMenuItem<String>(
                                  value: point.id,
                                  child: Text(
                                    point.displayName,
                                    overflow: TextOverflow.ellipsis,
                                    style: _t(14, FontWeight.w500),
                                  ),
                                ),
                              )
                              .toList(),
                          validator: (value) =>
                              _pickupMethod == _pickupPoint && value == null
                              ? 'Please select a pickup point'
                              : null,
                          onChanged: _loadingFormData
                              ? null
                              : (value) => setState(
                                  () => _selectedPickupPointId = value,
                                ),
                        ),
                    ],
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
                subtitle: 'Select the company that will handle this order',
                child: _deliveryCompanies.isEmpty
                    ? const _InfoBox(
                        icon: Icons.info_outline,
                        text:
                            'No linked delivery companies found. The order can still be created.',
                        color: _W.amber,
                        background: _W.amberLt,
                      )
                    : DropdownButtonFormField<String>(
                        key: ValueKey(
                          'company-${_selectedDeliveryCompanyId ?? 'none'}',
                        ),
                        initialValue: _selectedDeliveryCompanyId,
                        isExpanded: true,
                        decoration: _inputDecor(
                          label: 'Select Delivery Company',
                          hint: 'Choose delivery company',
                          icon: Icons.local_shipping_outlined,
                        ),
                        items: _deliveryCompanies
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
                            _deliveryCompanies.isNotEmpty && value == null
                            ? 'Please select a delivery company'
                            : null,
                        onChanged: _loadingFormData
                            ? null
                            : (value) => setState(
                                () => _selectedDeliveryCompanyId = value,
                              ),
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
                    _SummaryRow(label: 'Pickup', value: _summaryPickup),
                    _SummaryRow(label: 'Company', value: _summaryCompany),
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
}

class _SelectOption {
  final String id;
  final String name;
  final String? subtitle;

  const _SelectOption({required this.id, required this.name, this.subtitle});

  String get displayName {
    final detail = subtitle?.trim();
    if (detail == null || detail.isEmpty) return name;
    return '$name - $detail';
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
            'Customer, delivery, payment, and package details in one flow.',
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
              _StepChip(number: '2', label: 'Delivery'),
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
                  ? (constraints.maxWidth > 46 ? constraints.maxWidth - 46 : 0.0)
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
                  ? (constraints.maxWidth > 23 ? constraints.maxWidth - 23 : 0.0)
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
        border: Border.all(color: color.withValues(alpha: 0.22), width: 1.3),
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
        columnWidths: const {0: FixedColumnWidth(86), 1: FlexColumnWidth()},
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
                    ? _W.blueDark.withValues(alpha: 0.18)
                    : const Color(0xFFC7D0E0),
                width: 1.2,
              ),
              boxShadow: isEnabled
                  ? [
                      BoxShadow(
                        color: _W.blue.withValues(alpha: 0.18),
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
                          ? (constraints.maxWidth > 30 ? constraints.maxWidth - 30 : 0.0)
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
  final String paymentMethod;
  final String amount;
  final String packageType;
  final String itemCount;
  final String weight;
  final String volume;

  const _SuccessDialog({
    required this.orderId,
    required this.trackingCode,
    required this.pickupMethod,
    required this.paymentMethod,
    required this.amount,
    required this.packageType,
    required this.itemCount,
    required this.weight,
    required this.volume,
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
                    _DialogRow(label: 'Pickup', value: pickupMethod),
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
      columnWidths: const {0: FixedColumnWidth(82), 1: FlexColumnWidth()},
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