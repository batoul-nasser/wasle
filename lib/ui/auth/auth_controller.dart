import 'package:supabase_flutter/supabase_flutter.dart';

// Global singleton
final authController = AuthController._();

enum MerchantAuthErrorCode {
  generic,
  invalidCredentials,
  emailNotConfirmed,
  invalidOtp,
  rateLimited,
  network,
  notMerchant,
  onboardingFailed,
}

class MerchantAuthException implements Exception {
  final String message;
  final MerchantAuthErrorCode code;

  const MerchantAuthException(
    this.message, [
    this.code = MerchantAuthErrorCode.generic,
  ]);

  @override
  String toString() => message;
}

class AuthGateDecision {
  final bool allowAccess;
  final String? errorMessage;

  const AuthGateDecision._({
    required this.allowAccess,
    this.errorMessage,
  });

  const AuthGateDecision.allow() : this._(allowAccess: true);

  const AuthGateDecision.deny(String message)
      : this._(
          allowAccess: false,
          errorMessage: message,
        );
}

class _MerchantSeed {
  final String fullName;
  final String storeName;
  final String phone;

  const _MerchantSeed({
    required this.fullName,
    required this.storeName,
    required this.phone,
  });
}

class AuthController {
  AuthController._();

  static const String merchantRedirectUrl = 'wasle-merchant://login-callback';

  SupabaseClient get _client => Supabase.instance.client;

  Session? get currentSession => _client.auth.currentSession;
  User? get currentUser => _client.auth.currentUser;
  bool get isLoggedIn => currentSession != null;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  String? _pendingFullName;
  String? _pendingStoreName;
  String? _pendingPhone;

  Future<void>? _ensureMerchantFuture;

  Future<void> login({
    required String email,
    required String password,
  }) async {
    final cleanEmail = _normalizeEmail(email);

    try {
      final response = await _client.auth.signInWithPassword(
        email: cleanEmail,
        password: password,
      );

      if (response.session == null || response.user == null) {
        throw const MerchantAuthException('Login failed. Please try again.');
      }

      await ensureMerchantAccess();
    } on MerchantAuthException {
      rethrow;
    } on AuthApiException catch (e) {
      throw _mapSupabaseError(e.message);
    } catch (_) {
      throw const MerchantAuthException(
        'An unexpected error occurred. Please try again.',
      );
    }
  }

  Future<void> sendLoginOtp({
    required String email,
  }) async {
    final cleanEmail = _normalizeEmail(email);

    try {
      await _client.auth.signInWithOtp(
        email: cleanEmail,
        shouldCreateUser: false,
        emailRedirectTo: merchantRedirectUrl,
      );
    } on AuthApiException catch (e) {
      throw _mapSupabaseError(e.message);
    } catch (_) {
      throw const MerchantAuthException(
        'Failed to send OTP. Please try again.',
      );
    }
  }

  Future<void> verifyLoginOtp({
    required String email,
    required String token,
  }) async {
    final cleanEmail = _normalizeEmail(email);
    final cleanToken = token.trim();

    if (cleanToken.isEmpty) {
      throw const MerchantAuthException(
        'Please enter the OTP code.',
        MerchantAuthErrorCode.invalidOtp,
      );
    }

    try {
      final response = await _client.auth.verifyOTP(
        email: cleanEmail,
        token: cleanToken,
        type: OtpType.email,
      );

      if (response.session == null || response.user == null) {
        throw const MerchantAuthException(
          'Invalid or expired OTP code.',
          MerchantAuthErrorCode.invalidOtp,
        );
      }

      await ensureMerchantAccess();
    } on MerchantAuthException {
      rethrow;
    } on AuthApiException catch (e) {
      throw _mapSupabaseError(e.message);
    } catch (_) {
      throw const MerchantAuthException(
        'Failed to verify OTP. Please try again.',
      );
    }
  }

  Future<void> signUpMerchant({
    required String fullName,
    required String storeName,
    required String phone,
    required String email,
    required String password,
    String? emailRedirectTo,
  }) async {
    final cleanEmail = _normalizeEmail(email);
    final cleanFullName = fullName.trim();
    final cleanStoreName = storeName.trim();
    final cleanPhone = phone.trim();

    try {
      final response = await _client.auth.signUp(
        email: cleanEmail,
        password: password,
        emailRedirectTo: emailRedirectTo ?? merchantRedirectUrl,
        data: {
          'full_name': cleanFullName,
          'store_name': cleanStoreName,
          'phone': cleanPhone,
          'role': 'merchant',
        },
      );

      if (response.user == null) {
        throw const MerchantAuthException(
          'Account creation failed. Please try again.',
        );
      }

      _pendingFullName = cleanFullName;
      _pendingStoreName = cleanStoreName;
      _pendingPhone = cleanPhone;
    } on MerchantAuthException {
      rethrow;
    } on AuthApiException catch (e) {
      throw _mapSupabaseError(e.message);
    } catch (_) {
      throw const MerchantAuthException(
        'An unexpected error occurred. Please try again.',
      );
    }
  }

  Future<void> resendSignupConfirmation({
    required String email,
  }) async {
    final cleanEmail = _normalizeEmail(email);

    try {
      await _client.auth.resend(
        type: OtpType.signup,
        email: cleanEmail,
        emailRedirectTo: merchantRedirectUrl,
      );
    } on AuthApiException catch (e) {
      throw _mapSupabaseError(e.message);
    } catch (_) {
      throw const MerchantAuthException(
        'Failed to resend confirmation email. Please try again.',
      );
    }
  }

  Future<AuthGateDecision> resolveMerchantGate() async {
    if (currentSession == null) {
      return const AuthGateDecision.deny('Please sign in first.');
    }

    try {
      await ensureMerchantAccess();
      return const AuthGateDecision.allow();
    } on MerchantAuthException catch (e) {
      return AuthGateDecision.deny(e.message);
    } catch (_) {
      return const AuthGateDecision.deny(
        'Could not verify your merchant account. Please sign in again.',
      );
    }
  }

  Future<void> ensureMerchantAccess() {
    final existing = _ensureMerchantFuture;
    if (existing != null) return existing;

    final future = _ensureMerchantAccessInternal();
    _ensureMerchantFuture = future;

    return future.whenComplete(() {
      if (identical(_ensureMerchantFuture, future)) {
        _ensureMerchantFuture = null;
      }
    });
  }

  Future<void> _ensureMerchantAccessInternal() async {
    final uid = currentUser?.id;
    if (uid == null) {
      throw const MerchantAuthException(
        'No authenticated user found.',
        MerchantAuthErrorCode.onboardingFailed,
      );
    }

    if (await hasCompleteMerchantAccess()) {
      _clearPendingSignupData();
      return;
    }

    final seed = _readMerchantSeed();
    if (seed == null) {
      throw const MerchantAuthException(
        'This account is not registered as a merchant.',
        MerchantAuthErrorCode.notMerchant,
      );
    }

    try {
      await _client.rpc(
        'setup_merchant_account',
        params: {
          'p_full_name': seed.fullName,
          'p_phone': seed.phone,
          'p_store_name': seed.storeName,
        },
      );
    } on PostgrestException catch (e) {
      throw MerchantAuthException(
        'Profile setup failed: ${e.message}',
        MerchantAuthErrorCode.onboardingFailed,
      );
    } catch (_) {
      throw const MerchantAuthException(
        'Failed to complete merchant account setup.',
        MerchantAuthErrorCode.onboardingFailed,
      );
    }

    final ok = await hasCompleteMerchantAccess();
    if (!ok) {
      throw const MerchantAuthException(
        'We could not verify your merchant access after setup.',
        MerchantAuthErrorCode.onboardingFailed,
      );
    }

    _clearPendingSignupData();
  }

  Future<Map<String, dynamic>?> getMyProfile() async {
    final uid = currentUser?.id;
    if (uid == null) return null;

    try {
      return await _client
          .from('profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();
    } catch (_) {
      return null;
    }
  }


  Future<Map<String, dynamic>> loadMerchantSecuritySnapshot() async {
    final uid = currentUser?.id;

    try {
      final profile = await getMyProfile();
      final memberships = uid == null
          ? const []
          : await _client
              .from('merchant_users')
              .select('id, merchant_id')
              .eq('profile_id', uid);

      return {
        'hasSession': currentSession != null,
        'userId': uid,
        'profileRole': profile?['role']?.toString(),
        'profileStatus': profile?['status']?.toString(),
        'merchantMembershipCount': (memberships as List).length,
      };
    } catch (_) {
      return {
        'hasSession': currentSession != null,
        'userId': uid,
        'profileRole': null,
        'profileStatus': null,
        'merchantMembershipCount': 0,
      };
    }
  }

  Future<bool> isMerchant() => hasCompleteMerchantAccess();

  Future<bool> hasCompleteMerchantAccess() async {
    try {
      final uid = currentUser?.id;
      if (uid == null) return false;

      final profile = await getMyProfile();
      if (profile == null) return false;

      final isActiveMerchant =
          profile['role'] == 'merchant' && profile['status'] == 'active';

      if (!isActiveMerchant) return false;

      final membership = await _client
          .from('merchant_users')
          .select('id')
          .eq('profile_id', uid)
          .maybeSingle();

      return membership != null;
    } catch (_) {
      return false;
    }
  }

  _MerchantSeed? _readMerchantSeed() {
    final meta = currentUser?.userMetadata ?? const {};

    final metaRole = (meta['role']?.toString() ?? '').trim().toLowerCase();
    final hasPendingSeed =
        (_pendingFullName?.trim().isNotEmpty ?? false) ||
        (_pendingStoreName?.trim().isNotEmpty ?? false);

    final shouldBeMerchant = metaRole == 'merchant' || hasPendingSeed;
    if (!shouldBeMerchant) return null;

    final fullName =
        (_pendingFullName ?? meta['full_name']?.toString() ?? '').trim();
    final storeName =
        (_pendingStoreName ?? meta['store_name']?.toString() ?? '').trim();
    final phone = (_pendingPhone ?? meta['phone']?.toString() ?? '').trim();

    if (fullName.isEmpty || storeName.isEmpty) return null;

    return _MerchantSeed(
      fullName: fullName,
      storeName: storeName,
      phone: phone,
    );
  }

  void _clearPendingSignupData() {
    _pendingFullName = null;
    _pendingStoreName = null;
    _pendingPhone = null;
  }

  Future<void> logout() async {
    try {
      _clearPendingSignupData();
      await _client.auth.signOut();
    } catch (_) {}
  }

  String _normalizeEmail(String email) => email.trim().toLowerCase();

  MerchantAuthException _mapSupabaseError(String raw) {
    final msg = raw.toLowerCase();

    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid password')) {
      return const MerchantAuthException(
        'Incorrect email or password. Please try again.',
        MerchantAuthErrorCode.invalidCredentials,
      );
    }

    if (msg.contains('email not confirmed')) {
      return const MerchantAuthException(
        'Please confirm your email first, then sign in.',
        MerchantAuthErrorCode.emailNotConfirmed,
      );
    }

    if (msg.contains('otp') ||
        msg.contains('token') ||
        msg.contains('expired')) {
      return const MerchantAuthException(
        'Invalid or expired OTP code.',
        MerchantAuthErrorCode.invalidOtp,
      );
    }

    if (msg.contains('user already registered') ||
        msg.contains('already been registered')) {
      return const MerchantAuthException(
        'An account with this email already exists.',
      );
    }

    if (msg.contains('rate limit') || msg.contains('too many requests')) {
      return const MerchantAuthException(
        'Too many attempts. Please wait a moment and try again.',
        MerchantAuthErrorCode.rateLimited,
      );
    }

    if (msg.contains('network') ||
        msg.contains('connection') ||
        msg.contains('socket')) {
      return const MerchantAuthException(
        'Network error. Please check your connection.',
        MerchantAuthErrorCode.network,
      );
    }

    return const MerchantAuthException(
      'Something went wrong. Please try again.',
    );
  }
}