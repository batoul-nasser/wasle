import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wasle/core/ui/ui.dart';

class MerchantCreateOrderScreen extends StatefulWidget {
  const MerchantCreateOrderScreen({super.key});

  @override
  State<MerchantCreateOrderScreen> createState() =>
      _MerchantCreateOrderScreenState();
}

class _MerchantCreateOrderScreenState extends State<MerchantCreateOrderScreen> {
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

  Future<void> _createOrder() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      setState(() => errorText = 'You must be logged in.');
      return;
    }

    final customerName = customerNameController.text.trim();
    final customerPhone = customerPhoneController.text.trim();
    final pickupAddress = pickupAddressController.text.trim();
    final deliveryAddress = deliveryAddressController.text.trim();
    final notes = notesController.text.trim();

    if (customerName.isEmpty ||
        customerPhone.isEmpty ||
        pickupAddress.isEmpty ||
        deliveryAddress.isEmpty) {
      setState(() => errorText = 'Please fill all required fields.');
      return;
    }

    try {
      setState(() {
        isLoading = true;
        errorText = null;
        successText = null;
      });

      await _client.from('orders').insert({
        'merchant_id': user.id,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'pickup_address': pickupAddress,
        'delivery_address': deliveryAddress,
        'notes': notes.isEmpty ? null : notes,
        'status': 'pending',
      });

      customerNameController.clear();
      customerPhoneController.clear();
      pickupAddressController.clear();
      deliveryAddressController.clear();
      notesController.clear();

      setState(() {
        successText = 'Order created successfully.';
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
