import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wasle/features/pickup_point/data/pickup_point_service.dart';

// PUT WASLE'S REAL WHISH NUMBER HERE
const String kWasleWhishNumber = '+961XXXXXXXX';

class SendToWasleScreen extends StatefulWidget {
  final String orderId;
  final String paymentId;
  final double amount;
  final String trackingCode;

  const SendToWasleScreen({
    super.key,
    required this.orderId,
    required this.paymentId,
    required this.amount,
    required this.trackingCode,
  });

  @override
  State<SendToWasleScreen> createState() => _SendToWasleScreenState();
}

class _SendToWasleScreenState extends State<SendToWasleScreen> {
  final _service = PickupPointService();
  final _refCtrl = TextEditingController();
  bool _whishOpened = false;
  bool _loading = false;

  @override
  void dispose() {
    _refCtrl.dispose();
    super.dispose();
  }

  Future<void> _openWhish() async {
    // Try to open Whish app directly
    final whishUri = Uri.parse(
        'whish://send?phone=$kWasleWhishNumber&amount=${widget.amount.toStringAsFixed(2)}');
    if (await canLaunchUrl(whishUri)) {
      await launchUrl(whishUri);
    } else {
      // Whish app not installed — open phone dialer as fallback
      final telUri = Uri.parse('tel:$kWasleWhishNumber');
      await launchUrl(telUri);
    }
    setState(() => _whishOpened = true);
  }

  Future<void> _confirm() async {
    final ref = _refCtrl.text.trim();
    if (ref.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please enter the Whish transaction reference.'),
        backgroundColor: Color(0xFFE53054),
      ));
      return;
    }
    setState(() => _loading = true);
    try {
      await _service.confirmSentToWasle(
        orderId: widget.orderId,
        paymentId: widget.paymentId,
        amount: widget.amount,
        whishRef: ref,
      );
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: Row(children: const [
            Icon(Icons.check_circle, color: Color(0xFF0BA360), size: 28),
            SizedBox(width: 10),
            Text('Sent!'),
          ]),
          content: Text(
              '\$${widget.amount.toStringAsFixed(2)} marked as sent to Wasle.\nRef: $ref'),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString()),
        backgroundColor: const Color(0xFFE53054),
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(title: const Text('Send to Wasle'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Order + amount display
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [BoxShadow(
                  color: Color(0x14000000), blurRadius: 10,
                  offset: Offset(0, 4))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              const Text('Order',
                  style: TextStyle(color: Colors.black54, fontSize: 13)),
              const SizedBox(height: 4),
              Text(widget.trackingCode,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text('Amount to send to Wasle',
                  style: TextStyle(color: Colors.black54, fontSize: 13)),
              const SizedBox(height: 4),
              Text('\$${widget.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2563EB))),
            ]),
          ),
          const SizedBox(height: 20),

          // Step 1 — open Whish and send
          _stepCard(
            step: '1',
            title: 'Send via Whish',
            done: _whishOpened,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              const Text(
                'Open your Whish app and send the amount to Wasle:',
                style: TextStyle(fontSize: 13, color: Colors.black54,
                    height: 1.4),
              ),
              const SizedBox(height: 10),
              Row(children: [
                const Text('Wasle Whish number: ',
                    style: TextStyle(fontSize: 14, color: Colors.black54)),
                Text(kWasleWhishNumber,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(
                        ClipboardData(text: kWasleWhishNumber));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Number copied!')),
                    );
                  },
                  child: const Icon(Icons.copy,
                      size: 18, color: Color(0xFF2563EB)),
                ),
              ]),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openWhish,
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Open Whish App'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'After sending, come back here and complete step 2.',
                style: TextStyle(
                    fontSize: 12, color: Colors.black45, height: 1.4),
              ),
            ]),
          ),
          const SizedBox(height: 14),

          // Step 2 — enter ref and confirm
          _stepCard(
            step: '2',
            title: 'Enter Whish reference and confirm',
            done: false,
            locked: !_whishOpened,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              const Text(
                'After sending, find the transaction reference in your Whish app and enter it here.',
                style: TextStyle(
                    fontSize: 13, color: Colors.black54, height: 1.4),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _refCtrl,
                enabled: _whishOpened,
                decoration: InputDecoration(
                  labelText: 'Whish transaction reference',
                  hintText: 'e.g. WH-2026-XXXXXX',
                  filled: true,
                  fillColor: _whishOpened
                      ? const Color(0xFFF4F7FF)
                      : Colors.grey.shade100,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: Color(0xFFDDE5F7), width: 1.5)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: Color(0xFFDDE5F7), width: 1.5)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: Color(0xFF2563EB), width: 1.8)),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_whishOpened && !_loading) ? _confirm : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0BA360),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Confirm — I sent the money',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _stepCard({
    required String step,
    required String title,
    required bool done,
    bool locked = false,
    required Widget child,
  }) {
    return Opacity(
      opacity: locked ? 0.4 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: done
              ? Border.all(color: const Color(0xFF0BA360), width: 1.5)
              : null,
          boxShadow: const [BoxShadow(
              color: Color(0x10000000), blurRadius: 8, offset: Offset(0, 3))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: done
                    ? const Color(0xFF0BA360)
                    : const Color(0xFF2563EB),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: done
                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                    : Text(step,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15))),
          ]),
          const SizedBox(height: 14),
          child,
        ]),
      ),
    );
  }
}