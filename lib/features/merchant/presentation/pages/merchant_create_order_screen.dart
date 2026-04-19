import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wasle/core/services/payment_service.dart';
import 'package:wasle/core/ui/ui.dart';
import 'package:wasle/features/payment/data/payment_model.dart';
import 'package:wasle/features/payment/presentation/widgets/payment_method_selector.dart';
 
class MerchantCreateOrderScreen extends StatefulWidget {
  const MerchantCreateOrderScreen({super.key});
 
  @override
  State<MerchantCreateOrderScreen> createState() =>
      _MerchantCreateOrderScreenState();
}
 
class _MerchantCreateOrderScreenState
    extends State<MerchantCreateOrderScreen> {
  final SupabaseClient _client = Supabase.instance.client;
 
  final TextEditingController customerNameController = TextEditingController();
  final TextEditingController customerPhoneController = TextEditingController();
  final TextEditingController pickupAddressController = TextEditingController();
  final TextEditingController deliveryAddressController =
      TextEditingController();
  final TextEditingController notesController = TextEditingController();
 
  bool isLoading = false;
  String? errorText;
  String? successText;
  PaymentMethod _paymentMethod = PaymentMethod.cashAtPickup;
  double _paymentAmount = 0.0;
 
  Future<void> _createOrder() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      setState(() => errorText = 'You must be logged in.');
      return;
    }
 
    final customerName = customerNameController.text.trim();
    final customerPhone = customerPhoneController.text.trim();
    final deliveryAddress = deliveryAddressController.text.trim();
    final notes = notesController.text.trim();
 
    if (customerName.isEmpty ||
        customerPhone.isEmpty ||
        deliveryAddress.isEmpty) {
      setState(() => errorText = 'Please fill all required fields.');
      return;
    }
 
    if (_paymentAmount <= 0) {
      setState(() => errorText = 'Please enter a payment amount.');
      return;
    }
 
    try {
      setState(() {
        isLoading = true;
        errorText = null;
        successText = null;
      });
 
      // ✅ FIX: Fetch the real merchant_id from merchant_users
      // user.id is the profile ID, NOT the merchant business ID.
      // orders.merchant_id references merchant_businesses.id, so we
      // must look it up first.
      final merchantRow = await _client
          .from('merchant_users')
          .select('merchant_id')
          .eq('profile_id', user.id)
          .maybeSingle();
 
      if (merchantRow == null) {
        setState(() =>
            errorText = 'Merchant profile not found. Please contact support.');
        return;
      }
 
      final merchantId = merchantRow['merchant_id'] as String;
 
      final paymentService = PaymentService();
 
      await paymentService.createOrderWithPayment(
        merchantId: merchantId, // ✅ now correctly uses merchant_businesses.id
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
      );
 
      customerNameController.clear();
      customerPhoneController.clear();
      pickupAddressController.clear();
      deliveryAddressController.clear();
      notesController.clear();
 
      setState(() {
        successText = 'Order created successfully.';
        _paymentAmount = 0.0;
        _paymentMethod = PaymentMethod.cashAtPickup;
      });
    } catch (e) {
      setState(() => errorText = 'Failed to create order: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }
 
  @override
  void dispose() {
    customerNameController.dispose();
    customerPhoneController.dispose();
    pickupAddressController.dispose();
    deliveryAddressController.dispose();
    notesController.dispose();
    super.dispose();
  }
 
  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
    );
  }
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Order')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          _field(customerNameController, 'Customer Name'),
          const SizedBox(height: AppSpacing.md),
          _field(customerPhoneController, 'Customer Phone'),
          const SizedBox(height: AppSpacing.md),
          _field(pickupAddressController, 'Pickup Address'),
          const SizedBox(height: AppSpacing.md),
          _field(deliveryAddressController, 'Delivery Address'),
          const SizedBox(height: AppSpacing.md),
          _field(notesController, 'Notes (optional)', maxLines: 3),
          const SizedBox(height: 16),
          PaymentMethodSelector(
            selected: _paymentMethod,
            amount: _paymentAmount,
            onMethodChanged: (m) => setState(() => _paymentMethod = m),
            onAmountChanged: (a) => setState(() => _paymentAmount = a),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (errorText != null)
            Text(errorText!, style: const TextStyle(color: Colors.red)),
          if (successText != null)
            Text(successText!, style: const TextStyle(color: Colors.green)),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: 'Create Order',
            onPressed: isLoading ? null : _createOrder,
            isLoading: isLoading,
          ),
        ],
      ),
    );
  }
}