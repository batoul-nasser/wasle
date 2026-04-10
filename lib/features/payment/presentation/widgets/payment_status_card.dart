// lib/features/payment/presentation/widgets/payment_status_card.dart
//
// Shows live payment status in the customer dashboard.
// Uses watchPayment() stream so it auto-updates when Whish webhook fires.
 
import 'package:flutter/material.dart';
import 'package:wasle/core/services/payment_service.dart';
import 'package:wasle/features/payment/data/payment_model.dart';
import 'package:wasle/core/services/supabase_service.dart';

class PaymentStatusCard extends StatelessWidget {

  final String orderId;
  final PaymentService paymentService;
 
  const PaymentStatusCard({
    super.key,
    required this.orderId,
    required this.paymentService,
  });
 
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PaymentModel?>(
      stream: paymentService.watchPayment(orderId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _PaymentCardShell(
            child: const Center(
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
 
        final payment = snapshot.data;
 
        if (payment == null) {
          return _PaymentCardShell(
            child: _InfoRow(
              icon: Icons.info_outline,
              label: 'Payment',
              value: 'No payment record',
              valueColor: Colors.grey,
            ),
          );
        }
 
        return _PaymentCardShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoRow(
                icon: _methodIcon(payment.method),
                label: 'Method',
                value: payment.method.displayName,
              ),
              const SizedBox(height: 12),
              _InfoRow(
                icon: _statusIcon(payment.status),
                label: 'Status',
                value: payment.status.displayName,
                valueColor: _statusColor(payment.status),
                trailing: _StatusChip(status: payment.status),
              ),
              const SizedBox(height: 12),
              _InfoRow(
                icon: Icons.attach_money,
                label: 'Amount',
                value: '\$${payment.amount.toStringAsFixed(2)}',
              ),
              if (payment.transactionRef != null) ...[
                const SizedBox(height: 12),
                _InfoRow(
                  icon: Icons.receipt_outlined,
                  label: 'Ref',
                  value: payment.transactionRef!,
                ),
              ],
 
              // Whish: show pay button if still pending
              if (payment.isWhish && payment.isPending) ...[
                const SizedBox(height: 16),
                _WhishPayButton(orderId: orderId, paymentService: paymentService),
              ],
 
              // Cash: show instructions if pending
              if (payment.isCash && payment.isPending) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFD4800A).withOpacity(0.25),
                    ),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.store_outlined, color: Color(0xFFD4800A), size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Pay cash when you collect your order at the pickup point.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFFD4800A),
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
 
  IconData _methodIcon(PaymentMethod method) {
    return method == PaymentMethod.cashAtPickup
        ? Icons.store_outlined
        : Icons.phone_iphone_outlined;
  }
 
  IconData _statusIcon(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.paid:
        return Icons.check_circle_outline;
      case PaymentStatus.failed:
        return Icons.error_outline;
      case PaymentStatus.refunded:
        return Icons.undo_outlined;
      default:
        return Icons.hourglass_empty;
    }
  }
 
  Color _statusColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.paid:
        return const Color(0xFF0BA360);
      case PaymentStatus.failed:
        return const Color(0xFFE53054);
      case PaymentStatus.refunded:
        return const Color(0xFF6B7A99);
      default:
        return const Color(0xFFD4800A);
    }
  }
}
 
// ─── Sub-widgets ─────────────────────────────────────────────────────────────
 
class _PaymentCardShell extends StatelessWidget {
  final Widget child;
  const _PaymentCardShell({required this.child});
 
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Details',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
 
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final Widget? trailing;
 
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.trailing,
  });
 
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.blue, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: valueColor ?? Colors.black87,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
 
class _StatusChip extends StatelessWidget {
  final PaymentStatus status;
  const _StatusChip({required this.status});
 
  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
 
    switch (status) {
      case PaymentStatus.paid:
        bg = const Color(0xFFE6F7EF);
        fg = const Color(0xFF0BA360);
        break;
      case PaymentStatus.failed:
        bg = const Color(0xFFFFECEC);
        fg = const Color(0xFFE53054);
        break;
      case PaymentStatus.refunded:
        bg = const Color(0xFFF1F4FC);
        fg = const Color(0xFF6B7A99);
        break;
      default:
        bg = const Color(0xFFFEF4E2);
        fg = const Color(0xFFD4800A);
    }
 
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}
 
class _WhishPayButton extends StatefulWidget {
  final String orderId;
  final PaymentService paymentService;
 
  const _WhishPayButton({
    required this.orderId,
    required this.paymentService,
  });
 
  @override
  State<_WhishPayButton> createState() => _WhishPayButtonState();
}
 
class _WhishPayButtonState extends State<_WhishPayButton> {
  bool _loading = false;
 
  Future<void> _openWhishPayment() async {
    setState(() => _loading = true);
    try {
      // Fetch current user phone for Whish
      final user = await _getCurrentUserPhone();
 
      // Fetch payment amount
      final payment = await widget.paymentService.getPaymentByOrderId(widget.orderId);
      if (payment == null) throw Exception('Payment not found');
 
      final result = await widget.paymentService.initWhishPayment(
        orderId: widget.orderId,
        amount: payment.amount,
        customerPhone: user,
      );
 
      final paymentUrl = result['payment_url']?.toString();
      if (paymentUrl == null) throw Exception('No payment URL returned');
 
      if (!mounted) return;
 
      // Navigate to WebView screen with the Whish URL
      Navigator.pushNamed(
        context,
        '/payment/whish-webview',
        arguments: {
          'url': paymentUrl,
          'orderId': widget.orderId,
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: const Color(0xFFE53054),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
 
  Future<String> _getCurrentUserPhone() async {
  final uid = SupabaseService.client.auth.currentUser?.id;
  if (uid == null) return '';

  final row = await SupabaseService.client
      .from('profiles')
      .select('phone')
      .eq('id', uid)
      .maybeSingle();

  return row?['phone']?.toString() ?? '';
}
 
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _loading ? null : _openWhishPayment,
        icon: _loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.payment, size: 18),
        label: Text(_loading ? 'Loading...' : 'Pay with Whish'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A56DB),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}