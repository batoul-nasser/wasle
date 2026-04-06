import 'package:flutter/material.dart';
import 'package:wasle/features/auth/presentation/pages/login_screen.dart';
import 'package:wasle/features/driver/presentation/pages/driver_dashboard_screen.dart';
import 'package:wasle/features/auth/presentation/pages/welcome_screen.dart';

class WasleApp extends StatelessWidget {
  const WasleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const WelcomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/driver-dashboard': (context) => const DriverDashboardScreen(),
      },
    );
  }
}
