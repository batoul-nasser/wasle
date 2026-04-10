// lib/features/payment/presentation/widgets/payment_method_selector.dart
//
// Drop-in widget for the CreateOrderScreen payment section.
// Replace the plain COD amount field with this.
 
import 'package:flutter/material.dart';
import 'package:wasle/features/payment/data/payment_model.dart';
 
class PaymentMethodSelector extends StatelessWidget {
  final PaymentMethod selected;
  final double amount;
  final ValueChanged<PaymentMethod> onMethodChanged;
  final ValueChanged<double> onAmountChanged;
 
  const PaymentMethodSelector({
    super.key,
    required this.selected,
    required this.amount,
    required this.onMethodChanged,
    required this.onAmountChanged,
  });
 
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PAYMENT METHOD',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6B7A99),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _MethodCard(
                method: PaymentMethod.cashAtPickup,
                selected: selected == PaymentMethod.cashAtPickup,
                onTap: () => onMethodChanged(PaymentMethod.cashAtPickup),
                icon: Icons.store_outlined,
                label: 'Cash at Pickup',
                sublabel: 'Pay when collected',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MethodCard(
                method: PaymentMethod.whishOnline,
                selected: selected == PaymentMethod.whishOnline,
                onTap: () => onMethodChanged(PaymentMethod.whishOnline),
                icon: Icons.phone_iphone_outlined,
                label: 'Whish Online',
                sublabel: 'Pay via Whish app',
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _AmountField(
          amount: amount,
          onChanged: onAmountChanged,
          label: selected == PaymentMethod.cashAtPickup
              ? 'COD Amount (\$)'
              : 'Payment Amount (\$)',
        ),
        if (selected == PaymentMethod.whishOnline) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F7FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF1A56DB).withOpacity(0.15),
                width: 1.4,
              ),
            ),
            child: Row(
              children: const [
                Icon(Icons.info_outline, color: Color(0xFF1A56DB), size: 17),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Customer will receive a Whish payment link after order is created.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A56DB),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
 
class _MethodCard extends StatelessWidget {
  final PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;
  final IconData icon;
  final String label;
  final String sublabel;
 
  const _MethodCard({
    required this.method,
    required this.selected,
    required this.onTap,
    required this.icon,
    required this.label,
    required this.sublabel,
  });
 
  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF1A56DB);
    const blueLt = Color(0xFFEBF0FD);
    const border = Color(0xFFDDE5F7);
    const gray = Color(0xFF6B7A99);
    const navy = Color(0xFF0B1D3F);
 
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? blueLt : const Color(0xFFF4F7FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? blue : border,
            width: selected ? 2 : 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: selected ? blue : gray),
                const Spacer(),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? blue : border,
                      width: 2,
                    ),
                    color: selected ? blue : Colors.transparent,
                  ),
                  child: selected
                      ? const Icon(Icons.check, size: 11, color: Colors.white)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? blue : navy,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sublabel,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: gray,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
 
class _AmountField extends StatelessWidget {
  final double amount;
  final ValueChanged<double> onChanged;
  final String label;
 
  const _AmountField({
    required this.amount,
    required this.onChanged,
    required this.label,
  });
 
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: amount > 0 ? amount.toStringAsFixed(2) : '',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Color(0xFF0B1D3F),
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF6B7A99),
          letterSpacing: 0.3,
        ),
        hintText: '0.00',
        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
        prefixIcon: const Icon(
          Icons.attach_money,
          size: 17,
          color: Color(0xFF94A3B8),
        ),
        filled: true,
        fillColor: const Color(0xFFF4F7FF),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDDE5F7), width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDDE5F7), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1A56DB), width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE53054), width: 1.5),
        ),
      ),
      onChanged: (v) {
        final parsed = double.tryParse(v.trim()) ?? 0.0;
        onChanged(parsed);
      },
      validator: (v) {
        final value = (v ?? '').trim();
        if (value.isEmpty) return null;
        final parsed = double.tryParse(value);
        if (parsed == null || parsed < 0) {
          return 'Please enter a valid amount';
        }
        return null;
      },
    );
  }
}
