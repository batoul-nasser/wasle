import 'package:flutter/material.dart';
import 'package:wasle/features/auth/presentation/pages/company_sign_up_screen.dart';
import 'package:wasle/features/auth/presentation/pages/customer_sign_up_screen.dart';
import 'package:wasle/features/auth/presentation/pages/driver_sign_up_screen.dart';
import 'package:wasle/features/auth/presentation/pages/login_screen.dart';
import 'package:wasle/features/auth/presentation/pages/sign_up_role_screen.dart';
import 'package:wasle/features/auth/presentation/pages/welcome_screen.dart';
import 'package:wasle/features/company/presentation/pages/company_dashboard_screen.dart';
import 'package:wasle/features/customer/presentation/pages/customer_dashboard_screen.dart';
import 'package:wasle/features/driver/presentation/pages/driver_dashboard_screen.dart';
import 'package:wasle/features/merchant/presentation/widgets/merchant_dashboard_shell.dart';

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/welcome':
        return MaterialPageRoute(builder: (_) => const WelcomeScreen());

      case '/login':
        return MaterialPageRoute(builder: (_) => const LoginScreen());

      case '/sign-up-role':
        return MaterialPageRoute(builder: (_) => const SignUpRoleScreen());

      case '/driver-signup':
        return MaterialPageRoute(builder: (_) => const DriverSignUpScreen());

      case '/company-signup':
        return MaterialPageRoute(builder: (_) => const CompanySignUpScreen());

      case '/customer-signup':
        return MaterialPageRoute(builder: (_) => const CustomerSignUpScreen());

      case '/driver-dashboard':
        return MaterialPageRoute(builder: (_) => const DriverDashboardScreen());

      case '/company-dashboard':
        return MaterialPageRoute(
          builder: (_) => const CompanyDashboardScreen(),
        );

      case '/customer-dashboard':
        return MaterialPageRoute(
          builder: (_) => const CustomerDashboardScreen(),
        );

      case '/merchant-dashboard':
        return MaterialPageRoute(
          builder: (_) => const MerchantDashboardShell(),
        );

      default:
        return MaterialPageRoute(
          builder: (_) =>
              const Scaffold(body: Center(child: Text('Route not found'))),
        );
    }
  }
}
