import 'package:flutter/material.dart';
import 'package:wasle/features/auth/presentation/pages/company_sign_up_screen.dart';
import 'package:wasle/features/auth/presentation/pages/customer_sign_up_screen.dart';
import 'package:wasle/features/auth/presentation/pages/driver_sign_up_screen.dart';
import 'package:wasle/features/auth/presentation/pages/login_screen.dart';
import 'package:wasle/features/auth/presentation/pages/pickup_point_sign_up_screen.dart';
import 'package:wasle/features/auth/presentation/pages/sign_up_role_screen.dart';
import 'package:wasle/features/auth/presentation/pages/welcome_screen.dart';
import 'package:wasle/features/company/presentation/pages/company_dashboard_screen.dart';
import 'package:wasle/features/customer/presentation/pages/customer_dashboard_screen.dart';
import 'package:wasle/features/driver/presentation/pages/driver_dashboard_screen.dart';
import 'package:wasle/features/driver/presentation/pages/rejected_screen.dart';
import 'package:wasle/features/driver/presentation/pages/select_company_screen.dart';
import 'package:wasle/features/driver/presentation/pages/waiting_approval_screen.dart';
import 'package:wasle/features/merchant/presentation/widgets/merchant_dashboard_shell.dart';
import 'package:wasle/features/payment/presentation/pages/whish_webview_screen.dart';
import 'package:wasle/features/pickup_point/presentation/pages/pickup_dashboard_screen.dart';
import 'package:wasle/features/pickup_point/presentation/pages/pickup_point_dashboard_screen.dart';
import 'package:wasle/features/pickup_point/presentation/pages/pickup_application_pending_screen.dart';
import 'package:wasle/features/pickup_point/presentation/pages/pickup_application_rejected_screen.dart';

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
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

      case '/pickup-point-signup':
        return MaterialPageRoute(builder: (_) => const PickupPointSignUpScreen());

      case '/driver-dashboard':
        return MaterialPageRoute(builder: (_) => const DriverDashboardScreen());

      case '/company-dashboard':
        return MaterialPageRoute(builder: (_) => const CompanyDashboardScreen());

      case '/customer-dashboard':
        return MaterialPageRoute(builder: (_) => const CustomerDashboardScreen());

      case '/merchant-dashboard':
        return MaterialPageRoute(builder: (_) => const MerchantDashboardShell());

      case '/pickup-dashboard':
        return MaterialPageRoute(builder: (_) => const PickupDashboardScreen());

      case '/waiting-approval':
        return MaterialPageRoute(builder: (_) => const WaitingApprovalScreen());

      case '/rejected':
        return MaterialPageRoute(builder: (_) => const RejectedScreen());

      case '/select-company':
        return MaterialPageRoute(builder: (_) => const SelectCompanyScreen());

      case '/pickup-point-dashboard':
        return MaterialPageRoute(
          builder: (_) => const PickupPointDashboardScreen(),
        );
      case '/pickup-application-pending':


        return MaterialPageRoute(
          builder: (_) => const PickupApplicationPendingScreen(),
        );

      case '/pickup-application-rejected':
        return MaterialPageRoute(
          builder: (_) => const PickupApplicationRejectedScreen(),
        );


      case '/payment/whish-webview':
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => WhishWebViewScreen(
            url: args['url'] as String,
            orderId: args['orderId'] as String,
          ),
        );

      default:
        return MaterialPageRoute(builder: (_) => const WelcomeScreen());
    }
  }
}
