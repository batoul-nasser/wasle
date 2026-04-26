import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wasle/features/auth/data/auth_service.dart';

enum AuthErrorContext { passwordLogin, otpRequest, otpVerification }

class AuthErrorMapper {
  static String map(Object error, {required AuthErrorContext context}) {
    if (error is EmailAlreadyRegisteredException) {
      return error.message;
    }

    if (error is PendingSignupException) {
      return error.message;
    }

    if (error is EmailOtpException) {
      return error.message;
    }

    final code = _extractCode(error);
    final message = _extractMessage(error).toLowerCase();

    if (_isNetworkError(error, message)) {
      return 'Please check your internet connection and try again.';
    }

    switch (context) {
      case AuthErrorContext.passwordLogin:
        if (code == 'invalid_credentials' ||
            message.contains('invalid login credentials') ||
            message.contains('invalid_credentials')) {
          return 'Invalid email or password.';
        }
        return 'Unable to log in right now. Please try again.';

      case AuthErrorContext.otpRequest:
        if (_isEmailAlreadyRegistered(code, message)) {
          return EmailAlreadyRegisteredException.defaultMessage;
        }
        if (_isInvalidEmail(code, message)) {
          return 'Please enter a valid email address.';
        }
        if (_isOtpNotEligible(code, message)) {
          return 'This account is not eligible for OTP login.';
        }
        if (_isAccountMissing(code, message)) {
          return "We couldn't send a code to this email.";
        }
        if (message.contains('rate limit') ||
            message.contains('too many requests')) {
          return 'Too many attempts. Please try again in a moment.';
        }
        return "We couldn't send a code to this email.";

      case AuthErrorContext.otpVerification:
        if (_isEmailAlreadyRegistered(code, message)) {
          return EmailAlreadyRegisteredException.defaultMessage;
        }
        if (_isOtpExpired(code, message)) {
          return 'This code has expired. Please request a new one.';
        }
        if (_isOtpInvalid(code, message)) {
          return 'The code you entered is incorrect.';
        }
        return "We couldn't verify this code. Please try again.";
    }
  }

  static void log(String stage, Object error, [StackTrace? stackTrace]) {
    debugPrint('AUTH [$stage] $error');
    if (stackTrace != null) {
      debugPrint('AUTH [$stage] $stackTrace');
    }
  }

  static String _extractCode(Object error) {
    if (error is AuthApiException) {
      return (error.code ?? '').toLowerCase();
    }

    final raw = error.toString();
    final match = RegExp(r'code:\s*([a-zA-Z0-9_]+)').firstMatch(raw);
    return (match?.group(1) ?? '').toLowerCase();
  }

  static String _extractMessage(Object error) {
    if (error is AuthException) {
      return error.message;
    }

    if (error is PostgrestException) {
      return error.message;
    }

    return error.toString();
  }

  static bool _isNetworkError(Object error, String message) {
    final runtimeType = error.runtimeType.toString();
    return runtimeType == 'SocketException' ||
        message.contains('socketexception') ||
        message.contains('failed host lookup') ||
        message.contains('connection reset') ||
        message.contains('network') ||
        message.contains('connection closed');
  }

  static bool _isInvalidEmail(String code, String message) {
    return code == 'email_address_invalid' ||
        code == 'invalid_email' ||
        code == 'email_invalid' ||
        message.contains('invalid email') ||
        message.contains('email address is invalid');
  }

  static bool _isEmailAlreadyRegistered(String code, String message) {
    return code == 'email_exists' ||
        code == 'user_already_exists' ||
        code == 'email_already_registered' ||
        message.contains('already registered') ||
        message.contains('already exists') && message.contains('email') ||
        message.contains('user already exists');
  }

  static bool _isOtpNotEligible(String code, String message) {
    return code == 'otp_disabled' ||
        code == 'otp_not_enabled' ||
        code == 'signups_not_allowed' ||
        code == 'signup_disabled' ||
        message.contains('signups not allowed for otp') ||
        message.contains('otp login') && message.contains('not allowed') ||
        message.contains('not eligible for otp');
  }

  static bool _isAccountMissing(String code, String message) {
    return code == 'user_not_found' ||
        code == 'email_not_found' ||
        message.contains('user not found') ||
        message.contains('account not found');
  }

  static bool _isOtpExpired(String code, String message) {
    return code == 'otp_expired' ||
        message.contains('otp_expired') ||
        message.contains('token has expired') ||
        message.contains('expired');
  }

  static bool _isOtpInvalid(String code, String message) {
    return code == 'invalid_otp' ||
        code == 'otp_invalid' ||
        code == 'invalid_grant' ||
        message.contains('invalid otp') ||
        message.contains('otp is invalid') ||
        message.contains('token is invalid') ||
        message.contains('token has expired or is invalid') ||
        message.contains('invalid token');
  }
}
