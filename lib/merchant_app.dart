import 'package:flutter/material.dart';
import 'package:wasle/core/app_theme.dart';
import 'ui/auth/auth_gate.dart';

class MerchantApp extends StatelessWidget {
  const MerchantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WASLE Merchant',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthGate(),
    );
  }
}