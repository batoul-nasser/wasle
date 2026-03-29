// lib/ui/auth/auth_widgets.dart
//
// Wasle — Shared Auth UI Components
// Used by: login_screen.dart, signup_screen.dart
//
// BUG 2 FIXED: AuthField now wraps TextFormField instead of TextField.
//              Adds: validator, focusNode, onFieldSubmitted,
//                    textInputAction, autofillHints, enabled.
//              All parameters used by login_screen and signup_screen.
//
// BUG 3 FIXED: AuthInfoBanner added.
//              login_screen.dart uses it for post-signup and resend messages.

import 'package:flutter/material.dart';

// ─── Brand tokens ─────────────────────────────────────────────────────────────
class W {
  W._();
  static const bg       = Color(0xFFF4F7FF);
  static const white    = Color(0xFFFFFFFF);
  static const blue     = Color(0xFF1A56DB);
  static const blueDark = Color(0xFF1044C4);
  static const blueLt   = Color(0xFFEBF0FD);
  static const navy     = Color(0xFF0B1D3F);
  static const gray     = Color(0xFF6B7A99);
  static const border   = Color(0xFFDDE5F7);
  static const green    = Color(0xFF0BA360);
  static const greenLt  = Color(0xFFE6F7EF);
  static const red      = Color(0xFFE53054);
  static const redLt    = Color(0xFFFDEAED);
  static const slate    = Color(0xFF94A3B8);
  static const slateLt  = Color(0xFFF1F4FC);
  // Semi-transparent whites — gradient surfaces
  static const white13  = Color(0x22FFFFFF);
  static const white20  = Color(0x33FFFFFF);
  static const white70  = Color(0xB3FFFFFF);
  static const white07  = Color(0x12FFFFFF);
}

// ─── Typography helper ────────────────────────────────────────────────────────
TextStyle authText(
  double size,
  FontWeight w, {
  Color color = W.navy,
  double? height,
  double? spacing,
}) {
  return TextStyle(
    fontSize: size,
    fontWeight: w,
    color: color,
    height: height,
    letterSpacing: spacing,
  );
}

// ─── Card decoration ──────────────────────────────────────────────────────────
BoxDecoration authCardDecor({double radius = 20}) {
  return BoxDecoration(
    color: W.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: W.border, width: 1.5),
  );
}

// ─── AuthBrandBar ─────────────────────────────────────────────────────────────
class AuthBrandBar extends StatelessWidget {
  const AuthBrandBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: W.blue,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.local_shipping_outlined,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          RichText(
            text: TextSpan(
              style: authText(22, FontWeight.w900, spacing: -0.5),
              children: const [
                TextSpan(text: 'wa'),
                TextSpan(
                  text: 'sle',
                  style: TextStyle(color: W.blue),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── AuthHeroBanner ───────────────────────────────────────────────────────────
class AuthHeroBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const AuthHeroBanner({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [W.blueDark, W.blue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                color: W.white07,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: W.white13,
                  border: Border.all(color: W.white20, width: 1.5),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: authText(22, FontWeight.w900, color: Colors.white),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: authText(13, FontWeight.w500,
                    color: W.white70, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── AuthErrorBanner ──────────────────────────────────────────────────────────
class AuthErrorBanner extends StatelessWidget {
  final String message;

  const AuthErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: W.redLt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: W.red.withOpacity(0.25), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: W.red, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: authText(13, FontWeight.w600, color: W.red),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── AuthInfoBanner ───────────────────────────────────────────────────────────
// BUG 3 FIX: This widget was missing. Used by login_screen.dart for:
//   - post-signup success message
//   - resend confirmation email confirmation
class AuthInfoBanner extends StatelessWidget {
  final String message;

  const AuthInfoBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: W.blueLt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: W.blue.withOpacity(0.25), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: W.blue, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: authText(13, FontWeight.w600, color: W.blue),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── AuthSectionCard ──────────────────────────────────────────────────────────
class AuthSectionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final Widget child;

  const AuthSectionCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: authCardDecor(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 15, color: iconColor),
              ),
              const SizedBox(width: 9),
              Text(title, style: authText(14, FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: W.border),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ─── AuthField ────────────────────────────────────────────────────────────────
// BUG 2 FIX: Completely rewritten.
//
// BEFORE: Wrapped TextField — no validator, focusNode, onFieldSubmitted,
//         textInputAction, autofillHints, or enabled support.
//
// AFTER:  Wraps TextFormField — all parameters used by login_screen.dart
//         and signup_screen.dart are now supported.
//
// The AnimatedContainer handles the focus border (blue when focused).
// TextFormField handles validation error text (shows below the field).
// The widget manages its own internal FocusNode unless one is passed in,
// so it can track focus state for the border animation independently.
class AuthField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final VoidCallback? onToggleObscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final String? Function(String?)? validator;
  final FocusNode? focusNode;
  final List<String>? autofillHints;
  final bool enabled;

  const AuthField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.onToggleObscure,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onFieldSubmitted,
    this.validator,
    this.focusNode,
    this.autofillHints,
    this.enabled = true,
  });

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  // We either use the caller's FocusNode or create our own.
  // We only dispose the one we created.
  late final FocusNode _effectiveFocus;
  bool _ownsFocus = false;
  bool _focused   = false;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode != null) {
      _effectiveFocus = widget.focusNode!;
    } else {
      _effectiveFocus = FocusNode();
      _ownsFocus = true;
    }
    _effectiveFocus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) setState(() => _focused = _effectiveFocus.hasFocus);
  }

  @override
  void dispose() {
    _effectiveFocus.removeListener(_onFocusChange);
    if (_ownsFocus) _effectiveFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: _focused ? W.white : W.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _focused ? W.blue : W.border,
          width: 1.5,
        ),
      ),
      child: TextFormField(
        controller:       widget.controller,
        focusNode:        _effectiveFocus,
        obscureText:      widget.obscureText,
        keyboardType:     widget.keyboardType,
        textInputAction:  widget.textInputAction,
        enabled:          widget.enabled,
        autofillHints:    widget.autofillHints,
        validator:        widget.validator,
        onChanged:        widget.onChanged,
        onFieldSubmitted: widget.onFieldSubmitted,
        style:            authText(14, FontWeight.w500),
        decoration: InputDecoration(
          labelText:  widget.label,
          labelStyle: authText(
            12,
            FontWeight.w700,
            color:   _focused ? W.blue : W.gray,
            spacing: 0.3,
          ),
          hintText:  widget.hint,
          hintStyle: authText(14, FontWeight.w400, color: W.slate),
          prefixIcon: Icon(
            widget.icon,
            size:  17,
            color: _focused ? W.blue : W.slate,
          ),
          suffixIcon: widget.onToggleObscure != null
              ? IconButton(
                  onPressed: widget.onToggleObscure,
                  icon: Icon(
                    widget.obscureText
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size:  18,
                    color: W.slate,
                  ),
                )
              : null,
          // All borders are none — AnimatedContainer handles the border.
          filled:               false,
          border:               InputBorder.none,
          enabledBorder:        InputBorder.none,
          focusedBorder:        InputBorder.none,
          errorBorder:          InputBorder.none,
          focusedErrorBorder:   InputBorder.none,
          disabledBorder:       InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 13),
          // Validation error text appears below the field in red.
          errorStyle:    authText(11.5, FontWeight.w600, color: W.red),
          errorMaxLines: 2,
        ),
      ),
    );
  }
}

// ─── AuthSubmitButton ─────────────────────────────────────────────────────────
class AuthSubmitButton extends StatelessWidget {
  final String label;
  final bool loading;
  final IconData icon;
  final VoidCallback onTap;

  const AuthSubmitButton({
    super.key,
    required this.label,
    required this.loading,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: loading ? W.slate : W.blue,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: Colors.white.withOpacity(0.10),
        child: Container(
          width:     double.infinity,
          height:    52,
          alignment: Alignment.center,
          child: loading
              ? const SizedBox(
                  width:  22,
                  height: 22,
                  child:  CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color:       Colors.white,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Colors.white, size: 19),
                    const SizedBox(width: 9),
                    Text(
                      label,
                      style: authText(15, FontWeight.w800,
                          color: Colors.white),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─── AuthFooterRow ────────────────────────────────────────────────────────────
class AuthFooterRow extends StatelessWidget {
  final String text;
  final String actionLabel;
  final VoidCallback onTap;

  const AuthFooterRow({
    super.key,
    required this.text,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(text, style: authText(13, FontWeight.w500, color: W.gray)),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: onTap,
          child: Text(
            actionLabel,
            style: authText(13, FontWeight.w800, color: W.blue),
          ),
        ),
      ],
    );
  }
}