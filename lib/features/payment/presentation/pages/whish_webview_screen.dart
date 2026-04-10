// lib/features/payment/presentation/pages/whish_webview_screen.dart
//
// Opens the Whish payment URL in a WebView.
// Polls for payment status and auto-closes on success.
// Add webview_flutter to pubspec.yaml: webview_flutter: ^4.10.0
 
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:wasle/core/services/payment_service.dart';
import 'package:wasle/features/payment/data/payment_model.dart';
 
class WhishWebViewScreen extends StatefulWidget {
  final String url;
  final String orderId;
 
  const WhishWebViewScreen({
    super.key,
    required this.url,
    required this.orderId,
  });
 
  @override
  State<WhishWebViewScreen> createState() => _WhishWebViewScreenState();
}
 
class _WhishWebViewScreenState extends State<WhishWebViewScreen> {
  late final WebViewController _controller;
  final _paymentService = PaymentService();
  StreamSubscription<PaymentModel?>? _paymentSub;
  bool _paid = false;
 
  @override
  void initState() {
    super.initState();
 
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (url) => _checkIfSuccessUrl(url),
      ))
      ..loadRequest(Uri.parse(widget.url));
 
    // Watch for payment confirmation via Supabase real-time
    // Whish webhook hits the Edge Function → updates DB → stream fires here
    _paymentSub = _paymentService.watchPayment(widget.orderId).listen((payment) {
      if (payment?.isPaid == true && !_paid) {
        _paid = true;
        _onPaymentSuccess();
      }
    });
  }
 
  @override
  void dispose() {
    _paymentSub?.cancel();
    super.dispose();
  }
 
  void _checkIfSuccessUrl(String url) {
    // Adjust this to match your Whish redirect success URL
    if (url.contains('payment-success') || url.contains('whish_callback_success')) {
      _paid = true;
      _onPaymentSuccess();
    }
  }
 
  void _onPaymentSuccess() {
    if (!mounted) return;
 
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: Color(0xFF0BA360), size: 28),
            SizedBox(width: 10),
            Text('Payment Successful!'),
          ],
        ),
        content: const Text('Your Whish payment has been confirmed.'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // close WebView
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Payment'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
 