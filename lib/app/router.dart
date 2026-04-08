import 'package:flutter/material.dart';

import 'package:wasle/app/startup/startup_gate.dart';
import 'package:wasle/features/auth/presentation/pages/welcome_screen.dart';
import 'package:wasle/features/shared/presentation/role_placeholder_screen.dart';
import 'package:wasle/ui/auth/auth_gate.dart';
import 'package:wasle/ui/auth/login_screen.dart';

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(builder: (_) => const StartupGate());

      case '/welcome':
        return MaterialPageRoute(builder: (_) => const WelcomeScreen());

      case '/merchant-login':
        return MaterialPageRoute(builder: (_) => const LoginScreen());

      case '/merchant':
        return MaterialPageRoute(builder: (_) => const AuthGate());

      case '/driver':
        return MaterialPageRoute(
          builder: (_) => const RolePlaceholderScreen(
            title: 'Driver',
            description:
                'Driver flow will be connected here later. The app structure is now ready for it.',
          ),
        );

      case '/customer':
        return MaterialPageRoute(
          builder: (_) => const RolePlaceholderScreen(
            title: 'Customer',
            description:
                'Customer flow will be connected here later. The app structure is now ready for it.',
          ),
        );

      case '/company':
        return MaterialPageRoute(
          builder: (_) => const RolePlaceholderScreen(
            title: 'Delivery Company',
            description:
                'Company flow will be connected here later. The app structure is now ready for it.',
          ),
        );

      case '/admin':
        return MaterialPageRoute(
          builder: (_) => const RolePlaceholderScreen(
            title: 'Admin',
            description:
                'Admin flow will be connected here later. The app structure is now ready for it.',
          ),
        );

      default:
        return MaterialPageRoute(
          builder: (_) => const Scaffold(
            body: Center(child: Text('Route not found')),
          ),
        );
    }
  }
}
