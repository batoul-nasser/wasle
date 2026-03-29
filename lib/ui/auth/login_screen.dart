// lib/ui/auth/login_screen.dart

import 'package:flutter/material.dart';

import 'auth_controller.dart';
import 'auth_widgets.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  final String? initialError;

  const LoginScreen({super.key, this.initialError});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _otpFocus = FocusNode();

  bool _loading = false;
  bool _obscurePassword = true;
  bool _canResendConfirmation = false;
  bool _otpSent = false;

  String? _errorMessage;
  String? _infoMessage;

  @override
  void initState() {
    super.initState();
    _errorMessage = widget.initialError;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _otpCtrl.dispose();

    _emailFocus.dispose();
    _passwordFocus.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) return 'Please enter your email address.';

    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(email)) {
      return 'Please enter a valid email address.';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    if (!_otpSent) {
      final password = value ?? '';
      if (password.isEmpty) return 'Please enter your password.';
    }
    return null;
  }

  String? _validateOtp(String? value) {
    if (_otpSent) {
      final otp = (value ?? '').trim();
      if (otp.isEmpty) return 'Please enter the OTP code.';
    }
    return null;
  }

  Future<void> _loginWithPassword() async {
    if (_loading) return;

    FocusScope.of(context).unfocus();

    final emailError = _validateEmail(_emailCtrl.text);
    final passwordError = _validatePassword(_passwordCtrl.text);

    if (emailError != null || passwordError != null) {
      setState(() {
        _errorMessage = emailError ?? passwordError;
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
      _infoMessage = null;
      _canResendConfirmation = false;
    });

    try {
      await authController.login(
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
      );
    } on MerchantAuthException catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _errorMessage = e.message;
        _canResendConfirmation =
            e.code == MerchantAuthErrorCode.emailNotConfirmed;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _errorMessage = 'An unexpected error occurred. Please try again.';
        _canResendConfirmation = false;
      });
    }
  }

  Future<void> _sendOtp() async {
    if (_loading) return;

    final emailError = _validateEmail(_emailCtrl.text);
    if (emailError != null) {
      setState(() {
        _errorMessage = emailError;
      });
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
      _errorMessage = null;
      _infoMessage = null;
      _canResendConfirmation = false;
    });

    try {
      await authController.sendLoginOtp(
        email: _emailCtrl.text,
      );

      if (!mounted) return;

      setState(() {
        _loading = false;
        _otpSent = true;
        _infoMessage = 'OTP sent. Check your email inbox.';
      });

      _otpFocus.requestFocus();
    } on MerchantAuthException catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _errorMessage = 'Failed to send OTP.';
      });
    }
  }

  Future<void> _verifyOtp() async {
    if (_loading) return;

    final emailError = _validateEmail(_emailCtrl.text);
    final otpError = _validateOtp(_otpCtrl.text);

    if (emailError != null || otpError != null) {
      setState(() {
        _errorMessage = emailError ?? otpError;
      });
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      await authController.verifyLoginOtp(
        email: _emailCtrl.text,
        token: _otpCtrl.text,
      );
    } on MerchantAuthException catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _errorMessage = 'Failed to verify OTP.';
      });
    }
  }

  Future<void> _openSignup() async {
    FocusScope.of(context).unfocus();

    final signedUpEmail = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const SignupScreen()),
    );

    if (!mounted || signedUpEmail == null) return;

    _emailCtrl.text = signedUpEmail;

    setState(() {
      _errorMessage = null;
      _infoMessage =
          'Account created. Please confirm your email, then sign in.';
      _canResendConfirmation = true;
      _otpSent = false;
      _otpCtrl.clear();
    });
  }

  Future<void> _resendConfirmationEmail() async {
    if (_loading) return;

    final emailError = _validateEmail(_emailCtrl.text);
    if (emailError != null) {
      setState(() {
        _errorMessage = emailError;
      });
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      await authController.resendSignupConfirmation(
        email: _emailCtrl.text,
      );

      if (!mounted) return;

      setState(() {
        _loading = false;
        _infoMessage =
            'Confirmation email sent again. Please check your inbox and spam folder.';
        _canResendConfirmation = true;
      });
    } on MerchantAuthException catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _errorMessage = 'Failed to resend confirmation email.';
      });
    }
  }

  void _resetOtpMode() {
    setState(() {
      _otpSent = false;
      _otpCtrl.clear();
      _errorMessage = null;
      _infoMessage = null;
    });
  }

  void _clearMessages() {
    if (_errorMessage != null || _infoMessage != null) {
      setState(() {
        _errorMessage = null;
        _infoMessage = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: W.bg,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 32),
            children: [
              const AuthBrandBar(),
              const SizedBox(height: 4),

              AuthHeroBanner(
                icon: _otpSent
                    ? Icons.verified_user_outlined
                    : Icons.local_shipping_outlined,
                title: _otpSent ? 'Verify OTP' : 'Merchant Login',
                subtitle: _otpSent
                    ? 'Enter the one-time code sent to your email.'
                    : 'Sign in with password or use a one-time code sent to your email.',
              ),
              const SizedBox(height: 14),

              if (_errorMessage != null) ...[
                AuthErrorBanner(message: _errorMessage!),
                const SizedBox(height: 12),
              ],

              if (_infoMessage != null) ...[
                AuthInfoBanner(message: _infoMessage!),
                const SizedBox(height: 12),
              ],

              Form(
                key: _formKey,
                child: AutofillGroup(
                  child: AuthSectionCard(
                    icon: Icons.person_outline,
                    iconColor: W.blue,
                    iconBg: W.blueLt,
                    title: _otpSent ? 'OTP Verification' : 'Account Credentials',
                    child: Column(
                      children: [
                        AuthField(
                          controller: _emailCtrl,
                          label: 'Email Address',
                          hint: 'merchant@company.com',
                          icon: Icons.mail_outline,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction:
                              _otpSent ? TextInputAction.next : TextInputAction.next,
                          autofillHints: const [AutofillHints.username],
                          enabled: !_loading,
                          validator: _validateEmail,
                          focusNode: _emailFocus,
                          onFieldSubmitted: (_) {
                            if (_otpSent) {
                              _otpFocus.requestFocus();
                            } else {
                              _passwordFocus.requestFocus();
                            }
                          },
                          onChanged: (_) => _clearMessages(),
                        ),
                        const SizedBox(height: 12),

                        if (!_otpSent) ...[
                          AuthField(
                            controller: _passwordCtrl,
                            label: 'Password',
                            hint: 'Enter your password',
                            icon: Icons.lock_outline,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            enabled: !_loading,
                            validator: _validatePassword,
                            focusNode: _passwordFocus,
                            onToggleObscure: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            onFieldSubmitted: (_) => _loginWithPassword(),
                            onChanged: (_) => _clearMessages(),
                          ),
                        ],

                        if (_otpSent) ...[
                          AuthField(
                            controller: _otpCtrl,
                            label: 'OTP Code',
                            hint: 'Enter your code',
                            icon: Icons.password_outlined,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            enabled: !_loading,
                            validator: _validateOtp,
                            focusNode: _otpFocus,
                            onFieldSubmitted: (_) => _verifyOtp(),
                            onChanged: (_) => _clearMessages(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              if (!_otpSent) ...[
                AuthSubmitButton(
                  label: _loading ? 'Signing in…' : 'Sign In',
                  loading: _loading,
                  icon: Icons.login_outlined,
                  onTap: _loginWithPassword,
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _sendOtp,
                  icon: const Icon(Icons.verified_user_outlined),
                  label: const Text('Sign In with OTP'),
                ),
              ],

              if (_otpSent) ...[
                AuthSubmitButton(
                  label: _loading ? 'Verifying…' : 'Verify OTP',
                  loading: _loading,
                  icon: Icons.verified_outlined,
                  onTap: _verifyOtp,
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _sendOtp,
                  icon: const Icon(Icons.refresh_outlined),
                  label: const Text('Resend OTP'),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _loading ? null : _resetOtpMode,
                  child: const Text('Back to password login'),
                ),
              ],

              if (_canResendConfirmation) ...[
                const SizedBox(height: 10),
                Center(
                  child: TextButton.icon(
                    onPressed: _loading ? null : _resendConfirmationEmail,
                    icon: const Icon(Icons.mark_email_read_outlined, size: 18),
                    label: const Text('Resend confirmation email'),
                    style: TextButton.styleFrom(
                      foregroundColor: W.blue,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              AuthFooterRow(
                text: "Don't have a merchant account?",
                actionLabel: 'Create one →',
                onTap: _loading ? () {} : _openSignup,
              ),
              const SizedBox(height: 20),

              Center(
                child: Text(
                  'Secure merchant access · Powered by Supabase',
                  style: authText(11.5, FontWeight.w500, color: W.slate),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}