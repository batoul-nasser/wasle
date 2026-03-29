// lib/merchant/auth/signup_screen.dart
//
// Wasle — Merchant Signup Screen
// Improved for Supabase merchant onboarding flow.

import 'package:flutter/material.dart';

import 'auth_controller.dart';
import 'auth_widgets.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameCtrl = TextEditingController();
  final _storeNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  final _fullNameFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _storeFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _errorMessage;

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _storeNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();

    _fullNameFocus.dispose();
    _phoneFocus.dispose();
    _storeFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();

    super.dispose();
  }

  String? _validateFullName(String? value) {
    final fullName = (value ?? '').trim();
    if (fullName.isEmpty) return 'Please enter your full name.';
    if (fullName.length < 3) return 'Full name is too short.';
    return null;
  }

  String? _validateStoreName(String? value) {
    final storeName = (value ?? '').trim();
    if (storeName.isEmpty) return 'Please enter your store name.';
    if (storeName.length < 2) return 'Store name is too short.';
    return null;
  }

  String? _validatePhone(String? value) {
    final phone = (value ?? '').trim();
    if (phone.isEmpty) return 'Please enter your phone number.';

    final digitsOnly = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length < 8) {
      return 'Please enter a valid phone number.';
    }

    return null;
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
    final password = value ?? '';
    if (password.isEmpty) return 'Please enter a password.';
    if (password.length < 8) {
      return 'Password must be at least 8 characters.';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    final confirm = value ?? '';
    if (confirm.isEmpty) return 'Please confirm your password.';
    if (confirm != _passwordCtrl.text) {
      return 'Passwords do not match.';
    }
    return null;
  }

  Future<void> _signUp() async {
    if (_loading) return;

    FocusScope.of(context).unfocus();

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      await authController.signUpMerchant(
        fullName: _fullNameCtrl.text.trim(),
        storeName: _storeNameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        emailRedirectTo: AuthController.merchantRedirectUrl,
      );

      if (!mounted) return;

      Navigator.pop(
        context,
        _emailCtrl.text.trim().toLowerCase(),
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
        _errorMessage = 'An unexpected error occurred. Please try again.';
      });
    }
  }

  void _clearError() {
    if (_errorMessage != null) {
      setState(() {
        _errorMessage = null;
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

              const AuthHeroBanner(
                icon: Icons.storefront_outlined,
                title: 'Create Merchant Account',
                subtitle:
                    'Register your store, confirm your email, then sign in to complete secure merchant setup.',
              ),
              const SizedBox(height: 14),

              if (_errorMessage != null) ...[
                AuthErrorBanner(message: _errorMessage!),
                const SizedBox(height: 12),
              ],

              Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                    children: [
                      AuthSectionCard(
                        icon: Icons.person_outline,
                        iconColor: W.blue,
                        iconBg: W.blueLt,
                        title: 'Personal Info',
                        child: Column(
                          children: [
                            AuthField(
                              controller: _fullNameCtrl,
                              label: 'Full Name',
                              hint: 'e.g. Mohamad Ali',
                              icon: Icons.person_outline,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.name],
                              enabled: !_loading,
                              validator: _validateFullName,
                              focusNode: _fullNameFocus,
                              onFieldSubmitted: (_) {
                                _phoneFocus.requestFocus();
                              },
                              onChanged: (_) => _clearError(),
                            ),
                            const SizedBox(height: 12),
                            AuthField(
                              controller: _phoneCtrl,
                              label: 'Phone Number',
                              hint: '+961 71 000 000',
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [
                                AutofillHints.telephoneNumber,
                              ],
                              enabled: !_loading,
                              validator: _validatePhone,
                              focusNode: _phoneFocus,
                              onFieldSubmitted: (_) {
                                _storeFocus.requestFocus();
                              },
                              onChanged: (_) => _clearError(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      AuthSectionCard(
                        icon: Icons.storefront_outlined,
                        iconColor: W.green,
                        iconBg: W.greenLt,
                        title: 'Store Details',
                        child: Column(
                          children: [
                            AuthField(
                              controller: _storeNameCtrl,
                              label: 'Store Name',
                              hint: 'e.g. Demo Commerce',
                              icon: Icons.store_outlined,
                              textInputAction: TextInputAction.next,
                              enabled: !_loading,
                              validator: _validateStoreName,
                              focusNode: _storeFocus,
                              onFieldSubmitted: (_) {
                                _emailFocus.requestFocus();
                              },
                              onChanged: (_) => _clearError(),
                            ),
                            const SizedBox(height: 12),
                            AuthField(
                              controller: _emailCtrl,
                              label: 'Email Address',
                              hint: 'merchant@company.com',
                              icon: Icons.mail_outline,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.username],
                              enabled: !_loading,
                              validator: _validateEmail,
                              focusNode: _emailFocus,
                              onFieldSubmitted: (_) {
                                _passwordFocus.requestFocus();
                              },
                              onChanged: (_) => _clearError(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      AuthSectionCard(
                        icon: Icons.lock_outline,
                        iconColor: W.slate,
                        iconBg: W.slateLt,
                        title: 'Security',
                        child: Column(
                          children: [
                            AuthField(
                              controller: _passwordCtrl,
                              label: 'Password',
                              hint: 'At least 8 characters',
                              icon: Icons.lock_outline,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.newPassword],
                              enabled: !_loading,
                              validator: _validatePassword,
                              focusNode: _passwordFocus,
                              onToggleObscure: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                              onFieldSubmitted: (_) {
                                _confirmPasswordFocus.requestFocus();
                              },
                              onChanged: (_) => _clearError(),
                            ),
                            const SizedBox(height: 12),
                            AuthField(
                              controller: _confirmPasswordCtrl,
                              label: 'Confirm Password',
                              hint: 'Re-enter your password',
                              icon: Icons.check_circle_outline,
                              obscureText: _obscureConfirm,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.newPassword],
                              enabled: !_loading,
                              validator: _validateConfirmPassword,
                              focusNode: _confirmPasswordFocus,
                              onToggleObscure: () {
                                setState(() {
                                  _obscureConfirm = !_obscureConfirm;
                                });
                              },
                              onFieldSubmitted: (_) => _signUp(),
                              onChanged: (_) => _clearError(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              const AuthInfoBanner(
                message:
                    'After account creation, check your email and confirm your account before signing in.',
              ),
              const SizedBox(height: 16),

              AuthSubmitButton(
                label: _loading ? 'Creating account…' : 'Create Merchant Account',
                loading: _loading,
                icon: Icons.person_add_outlined,
                onTap: _signUp,
              ),
              const SizedBox(height: 16),

              AuthFooterRow(
                text: 'Already have an account?',
                actionLabel: '← Sign in',
                onTap: _loading ? () {} : () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}