import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/ui/ui.dart';
import 'env.dart';
import 'features/auth/presentation/pages/welcome_screen.dart';
import 'features/auth/presentation/pages/login_screen.dart';
import 'features/auth/presentation/pages/sign_up_role_screen.dart';
import 'features/auth/presentation/pages/driver_sign_up_screen.dart';
import 'features/auth/presentation/pages/company_sign_up_screen.dart';
import 'features/auth/presentation/pages/waiting_approval_screen.dart';
import 'features/auth/presentation/pages/rejected_screen.dart';
import 'features/auth/presentation/pages/driver_dashboard_screen.dart';
import 'features/deliveries/presentation/pages/my_deliveries_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );

  runApp(const WasleDriverApp());
}

class WasleDriverApp extends StatelessWidget {
  const WasleDriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Wasle Driver',
      theme: AppTheme.light,
      initialRoute: '/',
      routes: {
        '/': (context) => const WelcomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/sign-up-role': (context) => const SignUpRoleScreen(),
        '/driver-sign-up': (context) => const DriverSignUpScreen(),
        '/company-sign-up': (context) => const CompanySignUpScreen(),
        '/waiting': (context) => const WaitingApprovalScreen(),
        '/rejected': (context) => const RejectedScreen(),
        '/dashboard': (context) => const DriverDashboardScreen(),
        '/my-deliveries': (context) => const MyDeliveriesScreen(),
      },
    );
  }
}
