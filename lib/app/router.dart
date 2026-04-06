import 'package:flutter/material.dart';
import 'package:wasle/features/auth/presentation/pages/login_screen.dart';
import 'package:wasle/features/auth/presentation/pages/sign_up_role_screen.dart';
import 'package:wasle/features/auth/presentation/pages/welcome_screen.dart';
import 'package:wasle/features/company/presentation/pages/company_dashboard_screen.dart';
import 'package:wasle/features/driver/presentation/pages/driver_dashboard_screen.dart';

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/welcome':
        return MaterialPageRoute(builder: (_) => const WelcomeScreen());

      case '/login':
        return MaterialPageRoute(builder: (_) => const LoginScreen());

      case '/sign-up-role':
        return MaterialPageRoute(builder: (_) => const SignUpRoleScreen());

      case '/driver-dashboard':
        return MaterialPageRoute(builder: (_) => const DriverDashboardScreen());

      case '/company-dashboard':
        return MaterialPageRoute(
          builder: (_) => const CompanyDashboardScreen(),
        );

      default:
        return MaterialPageRoute(
          builder: (_) =>
              const Scaffold(body: Center(child: Text('Route not found'))),
        );
    }
  }
}
