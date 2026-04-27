import 'package:flutter_test/flutter_test.dart';
import 'package:wasle/features/auth/presentation/utils/auth_error_mapper.dart';

void main() {
  test('maps existing-email signup conflict during OTP request', () {
    final message = AuthErrorMapper.map(
      const EmailAlreadyRegisteredException(),
      context: AuthErrorContext.otpRequest,
    );

    expect(message, EmailAlreadyRegisteredException.defaultMessage);
  });

  test(
    'maps existing-email signup conflict without masking it as OTP expiry',
    () {
      final message = AuthErrorMapper.map(
        const EmailAlreadyRegisteredException(),
        context: AuthErrorContext.otpVerification,
      );

      expect(message, EmailAlreadyRegisteredException.defaultMessage);
      expect(
        message,
        isNot('This code has expired. Please request a new one.'),
      );
    },
  );
}
