// File: lib/features/merchant/presentation/pages/merchant_create_order_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wasle/core/services/payment_service.dart';
import 'package:wasle/core/ui/ui.dart';
import 'package:wasle/features/orders/data/order_assignment_service.dart';
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

  final _customerNameCtrl = TextEditingController();
  final _customerPhoneCtrl = TextEditingController();
  final _deliveryAddressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _itemCountCtrl = TextEditingController(text: '1');
  final _weightCtrl = TextEditingController(text: '1.0');
  final _volumeCtrl = TextEditingController(text: '500');

  bool isLoading = false;
  String? errorText;
  String? successText;
  PaymentMethod _paymentMethod = PaymentMethod.cashAtPickup;
  double _paymentAmount = 0.0;

  @override
  void dispose() {
    _customerNameCtrl.dispose();
    _customerPhoneCtrl.dispose();
    _deliveryAddressCtrl.dispose();
    _notesCtrl.dispose();
    _itemCountCtrl.dispose();
    _weightCtrl.dispose();
    _volumeCtrl.dispose();
    super.dispose();
  }

  Future<void> _createOrder() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      setState(() => errorText = 'You must be logged in.');
      return;
    }

    final customerName = _customerNameCtrl.text.trim();
    final customerPhone = _customerPhoneCtrl.text.trim();
    final deliveryAddress = _deliveryAddressCtrl.text.trim();
    final notes = _notesCtrl.text.trim();

    if (customerName.isEmpty ||
        customerPhone.isEmpty ||
        deliveryAddress.isEmpty) {
      setState(() => errorText = 'Please fill all required fields.');
      return;
    }

    if (_paymentAmount <= 0) {
      setState(() => errorText = 'Please enter a valid payment amount.');
      return;
    }

    final itemCount = int.tryParse(_itemCountCtrl.text.trim()) ?? 0;
    final weight = double.tryParse(_weightCtrl.text.trim()) ?? 0.0;
    final volume = double.tryParse(_volumeCtrl.text.trim()) ?? 0.0;

    if (itemCount <= 0) {
      setState(() => errorText = 'Item count must be at least 1.');
      return;
    }
    if (weight <= 0) {
      setState(() => errorText = 'Weight must be greater than 0.');
      return;
    }
    if (volume <= 0) {
      setState(() => errorText = 'Volume must be greater than 0.');
      return;
    }

    try {
      setState(() {
        isLoading = true;
        errorText = null;
        successText = null;
      });

      // Fetch the real merchant_id from merchant_users.
      // orders.merchant_id references merchant_businesses.id, not profiles.id.
      final merchantRow = await _client
          .from('merchant_users')
          .select('merchant_id')
          .eq('profile_id', user.id)
          .maybeSingle();

      if (merchantRow == null) {
        setState(
          () =>
              errorText = 'Merchant profile not found. Please contact support.',
        );
        return;
      }

      final merchantId = merchantRow['merchant_id'] as String;
      final paymentService = PaymentService();
      final assignmentService = OrderAssignmentService();

      final createdOrder = await paymentService.createOrderWithPayment(
        merchantId: merchantId,
        branchId: null,
        customerName: customerName,
        customerPhone: customerPhone,
        customerEmail: null,
        address: deliveryAddress,
        amount: _paymentAmount,
        paymentMethod: _paymentMethod,
        pickupPointId: null,
        deliveryCompanyId: null,
        notes: notes.isEmpty ? null : notes,
        itemCount: itemCount,
        estimatedWeightKg: weight,
        estimatedVolumeCm3: volume,
      );

      final assignmentResult = await assignmentService
          .autoAssignOrderFromCreationResponse(
            createdOrder,
            merchantId: merchantId,
          );

      _customerNameCtrl.clear();
      _customerPhoneCtrl.clear();
      _deliveryAddressCtrl.clear();
      _notesCtrl.clear();
      _itemCountCtrl.text = '1';
      _weightCtrl.text = '1.0';
      _volumeCtrl.text = '500';

      setState(() {
        successText = assignmentResult.assigned
            ? 'Order created and assigned automatically.'
            : 'Order created. Automatic assignment pending: ${assignmentResult.reason}';
        _paymentAmount = 0.0;
        _paymentMethod = PaymentMethod.cashAtPickup;
      });
    } catch (e) {
      setState(() => errorText = 'Failed to create order: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? prefixText,
    String? suffixText,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefixText,
        suffixText: suffixText,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Order')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          // â”€â”€ Customer info â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          const SectionHeader(
            title: 'Customer Details',
            subtitle: 'Who is receiving the order?',
          ),
          const SizedBox(height: AppSpacing.md),
          _field(_customerNameCtrl, 'Customer Name *'),
          const SizedBox(height: AppSpacing.md),
          _field(
            _customerPhoneCtrl,
            'Customer Phone *',
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: AppSpacing.md),
          _field(_deliveryAddressCtrl, 'Delivery Address *', maxLines: 2),

          const SizedBox(height: AppSpacing.xl),

          // â”€â”€ Package info (required by routing algorithm) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          const SectionHeader(
            title: 'Package Details',
            subtitle: 'Required for driver capacity matching (PDF Â§4)',
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _field(
                  _itemCountCtrl,
                  'Item Count *',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _field(
                  _weightCtrl,
                  'Weight *',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  suffixText: 'kg',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _field(
            _volumeCtrl,
            'Estimated Volume',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            suffixText: 'cmÂ³',
          ),

          const SizedBox(height: AppSpacing.xs),
          Text(
            'Volume helps match the right vehicle type for this order.',
            style: AppTextStyles.caption,
          ),

          const SizedBox(height: AppSpacing.xl),

          // â”€â”€ Notes â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          _field(_notesCtrl, 'Notes (optional)', maxLines: 3),

          const SizedBox(height: AppSpacing.xl),

          // â”€â”€ Payment â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          PaymentMethodSelector(
            selected: _paymentMethod,
            amount: _paymentAmount,
            onMethodChanged: (m) => setState(() => _paymentMethod = m),
            onAmountChanged: (a) => setState(() => _paymentAmount = a),
          ),

          const SizedBox(height: AppSpacing.lg),

          if (errorText != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.dangerSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.danger.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.danger,
                    size: 18,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      errorText!,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          if (successText != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.successSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.success.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: AppColors.success,
                    size: 18,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      successText!,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          PrimaryButton(
            label: 'Create Order',
            icon: Icons.check_circle_outline,
            onPressed: isLoading ? null : _createOrder,
            isLoading: isLoading,
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
