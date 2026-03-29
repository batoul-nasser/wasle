import 'package:flutter/material.dart';
import 'models/order_model.dart';
import 'services/order_service.dart';

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
  static const amber = Color(0xFFD4800A);
  static const amberLt = Color(0xFFFEF4E2);
  static const slate = Color(0xFF94A3B8);
  static const slateLt = Color(0xFFF1F4FC);
  static const white60 = Color(0x99FFFFFF);
  static const white70 = Color(0xB3FFFFFF);
  static const white13 = Color(0x22FFFFFF);
  static const white20 = Color(0x33FFFFFF);
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

InputDecoration _inputDecor({
  required String label,
  required String hint,
  required IconData icon,
}) {
  return InputDecoration(
    labelText: label,
    labelStyle: _t(12, FontWeight.w700, color: _W.gray, spacing: 0.3),
    hintText: hint,
    hintStyle: _t(14, FontWeight.w400, color: _W.slate),
    prefixIcon: Icon(icon, size: 17, color: _W.slate),
    filled: true,
    fillColor: _W.bg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _W.border, width: 1.5),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _W.border, width: 1.5),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _W.blue, width: 1.8),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _W.red, width: 1.5),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _W.red, width: 1.8),
    ),
  );
}

class CreateOrderScreen extends StatefulWidget {
  final VoidCallback? onOrderCreatedNavigate;

  const CreateOrderScreen({super.key, this.onOrderCreatedNavigate});

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _codCtrl = TextEditingController();
  final _timeWindowCtrl = TextEditingController();

  String _pickupMethod = 'From Store';
  String? _selectedPickupPointId;
  bool _loading = false;

  List<Map<String, String>> _deliveryCompanies = const [];
  String? _selectedDeliveryCompanyId;

  List<Map<String, String>> _pickupPoints = const [];

  @override
  void initState() {
    super.initState();
    _customerNameCtrl.addListener(_refresh);
    _codCtrl.addListener(_refresh);
    _addressCtrl.addListener(_refresh);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadDeliveryCompanies(),
      _loadPickupPoints(),
    ]);
  }

  Future<void> _loadDeliveryCompanies() async {
    final companies = await orderService.loadAvailableDeliveryCompanies();
    if (!mounted) return;

    setState(() {
      _deliveryCompanies = companies;
      if (companies.length == 1) {
        _selectedDeliveryCompanyId = companies.first['id'];
      }
    });
  }

  Future<void> _loadPickupPoints() async {
    final pickupPoints = await orderService.loadAvailablePickupPoints();
    if (!mounted) return;

    setState(() {
      _pickupPoints = pickupPoints;
      if (pickupPoints.length == 1) {
        _selectedPickupPointId = pickupPoints.first['id'];
      }
    });
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _customerNameCtrl.removeListener(_refresh);
    _codCtrl.removeListener(_refresh);
    _addressCtrl.removeListener(_refresh);

    _customerNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _notesCtrl.dispose();
    _addressCtrl.dispose();
    _codCtrl.dispose();
    _timeWindowCtrl.dispose();
    super.dispose();
  }

  bool _isValidEmail(String value) {
    if (value.trim().isEmpty) return true;
    return value.contains('@') && value.contains('.');
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;

    if (_pickupMethod == 'Pickup Point' && _selectedPickupPointId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a pickup point.'),
          backgroundColor: _W.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    if (_deliveryCompanies.isNotEmpty && _selectedDeliveryCompanyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a delivery company.'),
          backgroundColor: _W.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final newOrder = await orderService.createOrder(
        customerName: _customerNameCtrl.text.trim(),
        customerPhone: _phoneCtrl.text.trim(),
        customerEmail:
            _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        pickupMethod: _pickupMethod,
        codAmount: double.tryParse(_codCtrl.text.trim()) ?? 0,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        preferredTimeWindow: _timeWindowCtrl.text.trim().isEmpty
            ? null
            : _timeWindowCtrl.text.trim(),
        pickupPointId: _selectedPickupPointId,
        deliveryCompanyId: _selectedDeliveryCompanyId,
      );

      if (!mounted) return;
      setState(() => _loading = false);

      await showDialog(
        context: context,
        builder: (_) => _SuccessDialog(order: newOrder),
      );

      _resetForm();
      widget.onOrderCreatedNavigate?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: _W.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  void _resetForm() {
    _customerNameCtrl.clear();
    _phoneCtrl.clear();
    _emailCtrl.clear();
    _notesCtrl.clear();
    _addressCtrl.clear();
    _codCtrl.clear();
    _timeWindowCtrl.clear();

    setState(() {
      _pickupMethod = 'From Store';
      _selectedPickupPointId = _pickupPoints.length == 1 ? _pickupPoints.first['id'] : null;
      _selectedDeliveryCompanyId =
          _deliveryCompanies.length == 1 ? _deliveryCompanies.first['id'] : null;
    });
  }

  String get _summaryCustomer =>
      _customerNameCtrl.text.trim().isEmpty ? '—' : _customerNameCtrl.text.trim();

  String get _summaryPickup {
    if (_pickupMethod != 'Pickup Point') return 'From Store';

    final selected = _pickupPoints.cast<Map<String, String>?>().firstWhere(
          (e) => e?['id'] == _selectedPickupPointId,
          orElse: () => null,
        );

    if (selected == null) return 'Not selected';

    final name = selected['name'] ?? 'Pickup Point';
    final address = selected['address'] ?? '';

    return address.trim().isEmpty ? name : '$name — $address';
  }

  String get _summaryCod {
    final raw = _codCtrl.text.trim();
    if (raw.isEmpty) return '—';
    final parsed = double.tryParse(raw);
    return parsed != null ? '\$${parsed.toStringAsFixed(2)}' : raw;
  }

  String get _summaryCompany {
    if (_deliveryCompanies.isEmpty) return 'No linked companies';
    final selected = _deliveryCompanies.cast<Map<String, String>?>().firstWhere(
          (e) => e?['id'] == _selectedDeliveryCompanyId,
          orElse: () => null,
        );
    return selected?['name'] ?? 'Not selected';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _W.bg,
      child: Form(
        key: _formKey,
        child: ListView(
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
                    validator: (v) => (v == null || v.trim().isEmpty)
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
                    validator: (v) => (v == null || v.trim().isEmpty)
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
                    validator: (v) {
                      if (v == null) return null;
                      return _isValidEmail(v)
                          ? null
                          : 'Please enter a valid email address';
                    },
                  ),
                  const SizedBox(height: 12),
                  _FormField(
                    controller: _notesCtrl,
                    label: 'Notes',
                    hint: 'Call before arriving...',
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
                    hint: 'Beirut, Hamra St...',
                    icon: Icons.location_on_outlined,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Address is required'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  _FormField(
                    controller: _timeWindowCtrl,
                    label: 'Preferred Time Window (Optional)',
                    hint: 'e.g. 4 PM – 6 PM',
                    icon: Icons.access_time_outlined,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'PICKUP METHOD',
                    style: _t(
                      11,
                      FontWeight.w700,
                      color: _W.gray,
                      spacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _SegmentBtn(
                          label: '🏪  From Store',
                          selected: _pickupMethod == 'From Store',
                          onTap: () => setState(() {
                            _pickupMethod = 'From Store';
                            _selectedPickupPointId = null;
                          }),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SegmentBtn(
                          label: '📍  Pickup Point',
                          selected: _pickupMethod == 'Pickup Point',
                          onTap: () => setState(() {
                            _pickupMethod = 'Pickup Point';
                            if (_pickupPoints.length == 1) {
                              _selectedPickupPointId = _pickupPoints.first['id'];
                            }
                          }),
                        ),
                      ),
                    ],
                  ),
                  if (_pickupMethod == 'Pickup Point') ...[
                    const SizedBox(height: 12),
                    if (_pickupPoints.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _W.amberLt,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _W.amber.withOpacity(0.20),
                            width: 1.4,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: _W.amber,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'No pickup points found for this merchant.',
                                style: _t(
                                  12.5,
                                  FontWeight.w600,
                                  color: _W.amber,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        value: _selectedPickupPointId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Select Pickup Point',
                          labelStyle: _t(
                            12,
                            FontWeight.w700,
                            color: _W.gray,
                            spacing: 0.3,
                          ),
                          prefixIcon: Icon(
                            Icons.store_mall_directory_outlined,
                            size: 17,
                            color: _W.slate,
                          ),
                          filled: true,
                          fillColor: _W.bg,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: _W.border,
                              width: 1.5,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: _W.border,
                              width: 1.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: _W.blue,
                              width: 1.8,
                            ),
                          ),
                        ),
                        style: _t(14, FontWeight.w500),
                        items: _pickupPoints
                            .map(
                              (p) => DropdownMenuItem(
                                value: p['id'],
                                child: Text(
                                  (p['address']?.trim().isNotEmpty ?? false)
                                      ? '${p['name']} — ${p['address']}'
                                      : (p['name'] ?? 'Pickup Point'),
                                  style: _t(14, FontWeight.w500),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedPickupPointId = v),
                      ),
                  ],
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
                  ? Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _W.amberLt,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _W.amber.withOpacity(0.20),
                          width: 1.4,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: _W.amber,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'No linked delivery companies found for this merchant.',
                              style: _t(
                                12.5,
                                FontWeight.w600,
                                color: _W.amber,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : DropdownButtonFormField<String>(
                      value: _selectedDeliveryCompanyId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Select Delivery Company',
                        labelStyle: _t(
                          12,
                          FontWeight.w700,
                          color: _W.gray,
                          spacing: 0.3,
                        ),
                        prefixIcon: Icon(
                          Icons.business_outlined,
                          size: 17,
                          color: _W.slate,
                        ),
                        filled: true,
                        fillColor: _W.bg,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: _W.border,
                            width: 1.5,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: _W.border,
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: _W.blue,
                            width: 1.8,
                          ),
                        ),
                      ),
                      style: _t(14, FontWeight.w500),
                      items: _deliveryCompanies
                          .map(
                            (c) => DropdownMenuItem(
                              value: c['id'],
                              child: Text(
                                c['name'] ?? 'Unnamed Company',
                                style: _t(14, FontWeight.w500),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedDeliveryCompanyId = v),
                    ),
            ),
            const SizedBox(height: 12),

            _SectionCard(
              icon: Icons.credit_card_outlined,
              iconColor: _W.green,
              iconBg: _W.greenLt,
              title: 'Payment',
              subtitle: 'Cash on delivery configuration',
              child: _FormField(
                controller: _codCtrl,
                label: 'COD Amount (\$)',
                hint: '0.00',
                icon: Icons.attach_money,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) return null;
                  final parsed = double.tryParse(value);
                  if (parsed == null || parsed < 0) {
                    return 'Please enter a valid COD amount';
                  }
                  return null;
                },
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
                  _SummaryRow(label: 'Pickup Method', value: _summaryPickup),
                  _SummaryRow(label: 'Delivery Company', value: _summaryCompany),
                  _SummaryRow(
                    label: 'COD Amount',
                    value: _summaryCod,
                    valueColor: _W.blue,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _SubmitButton(onTap: _submitOrder, loading: _loading),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _W.blue,
              borderRadius: BorderRadius.circular(10),
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
              style: _t(22, FontWeight.w900, spacing: -0.5),
              children: const [
                TextSpan(text: 'wa'),
                TextSpan(
                  text: 'sle',
                  style: TextStyle(color: _W.blue),
                ),
              ],
            ),
          ),
          const Spacer(),
          if (Navigator.canPop(context))
            GestureDetector(
              onTap: () => Navigator.maybePop(context),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _W.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _W.border, width: 1.5),
                ),
                child: const Icon(
                  Icons.chevron_left,
                  size: 22,
                  color: _W.navy,
                ),
              ),
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
                'NEW DELIVERY',
                style: _t(
                  10,
                  FontWeight.w700,
                  color: _W.white60,
                  spacing: 1.4,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Create Order',
                style: _t(22, FontWeight.w900, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                'Fill in the details below to generate a tracking code.',
                style: _t(
                  13,
                  FontWeight.w500,
                  color: _W.white70,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: const [
                  _StepChip(number: '1', label: 'Customer'),
                  _StepChip(number: '2', label: 'Delivery'),
                  _StepChip(number: '3', label: 'Payment'),
                ],
              ),
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

  const _StepChip({
    required this.number,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: _W.white13,
        border: Border.all(color: _W.white20),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: _W.white20,
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: _t(10, FontWeight.w800, color: Colors.white),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: _t(12, FontWeight.w700, color: Colors.white),
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

class _SegmentBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentBtn({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _W.blueLt : _W.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _W.blue : _W.border,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: _t(
            13,
            FontWeight.w700,
            color: selected ? _W.blue : _W.gray,
          ),
        ),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: _t(13, FontWeight.w600, color: _W.gray),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: _t(
                13,
                FontWeight.w700,
                color: valueColor ?? _W.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool loading;

  const _SubmitButton({
    required this.onTap,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: loading ? _W.slate : _W.blue,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          alignment: Alignment.center,
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.add_circle_outline,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Create Delivery Order',
                      style: _t(
                        15,
                        FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _SuccessDialog extends StatelessWidget {
  final OrderModel order;

  const _SuccessDialog({required this.order});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _W.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: Color(0xFFE6F7EF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: _W.green,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text('Order Created!', style: _t(20, FontWeight.w900)),
            const SizedBox(height: 6),
            Text(
              'Your delivery request has been created successfully.',
              style: _t(
                13,
                FontWeight.w500,
                color: _W.gray,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _W.bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _W.border),
              ),
              child: Column(
                children: [
                  _DialogRow(label: 'Tracking Code', value: order.trackingCode),
                  const SizedBox(height: 8),
                  _DialogRow(label: 'Order ID', value: order.id),
                  const SizedBox(height: 8),
                  _DialogRow(label: 'Pickup', value: order.pickupMethod),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: Material(
                color: _W.blue,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    child: Text(
                      'Done',
                      style: _t(
                        15,
                        FontWeight.w800,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogRow extends StatelessWidget {
  final String label;
  final String value;

  const _DialogRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: _t(12.5, FontWeight.w600, color: _W.gray),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: _t(13, FontWeight.w800, color: _W.navy),
          ),
        ),
      ],
    );
  }
}