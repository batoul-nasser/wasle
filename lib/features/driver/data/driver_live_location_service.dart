import 'dart:async';
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';

import 'package:wasle/core/debug/automation_test_logger.dart';
import 'package:wasle/features/auth/data/auth_service.dart';

class DriverLiveLocationService {
  DriverLiveLocationService._();

  static final DriverLiveLocationService instance =
      DriverLiveLocationService._();

  final AuthService _authService = AuthService();
  Timer? _timer;
  String? _driverId;
  double? _lastSentLat;
  double? _lastSentLng;

  static const Duration pingInterval = Duration(seconds: 60);
  static const double minMovedMetersForCoordinateUpdate = 25;

  void configure(String driverId) {
    _driverId = _normalizeDriverId(driverId);
  }

  Future<bool> startTracking({
    required String driverId,
    bool requestPermissionIfNeeded = true,
    bool syncImmediately = true,
  }) async {
    final normalizedDriverId = _normalizeDriverId(driverId);
    if (normalizedDriverId == null) {
      await AutomationTestLogger.log(
        'driver_location',
        'Location tracking not started',
        data: {'driver_id': driverId, 'reason': 'invalid_driver_id'},
      );
      return false;
    }
    _driverId = normalizedDriverId;

    final hasPermission = await _ensurePermission(
      requestPermissionIfNeeded: requestPermissionIfNeeded,
    );
    if (!hasPermission) {
      await AutomationTestLogger.log(
        'driver_location',
        'Location tracking not started',
        data: {'driver_id': driverId, 'reason': 'permission_not_granted'},
      );
      return false;
    }

    _timer?.cancel();
    if (syncImmediately) {
      await _safeSyncNow(
        driverId: normalizedDriverId,
        requestPermissionIfNeeded: false,
      );
    }

    _timer = Timer.periodic(pingInterval, (_) {
      unawaited(
        _safeSyncNow(
          driverId: normalizedDriverId,
          requestPermissionIfNeeded: false,
        ),
      );
    });

    await AutomationTestLogger.log(
      'driver_location',
      'Started working mode location tracking',
      data: {'driver_id': normalizedDriverId},
    );
    return true;
  }

  Future<void> stopTracking() async {
    final driverId = _driverId;
    _timer?.cancel();
    _timer = null;

    await AutomationTestLogger.log(
      'driver_location',
      'Stopped working mode location tracking',
      data: {'driver_id': driverId},
    );
  }

  Future<Map<String, double>?> syncNow({
    String? driverId,
    bool requestPermissionIfNeeded = true,
  }) async {
    try {
      final effectiveDriverId = _normalizeDriverId(driverId ?? _driverId);
      if (effectiveDriverId == null || effectiveDriverId.isEmpty) {
        return null;
      }

      final hasPermission = await _ensurePermission(
        requestPermissionIfNeeded: requestPermissionIfNeeded,
      );
      if (!hasPermission) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final movedEnough = _shouldUpdateCoordinates(
        position.latitude,
        position.longitude,
      );

      if (movedEnough) {
        await _authService.upsertDriverLocation(
          driverId: effectiveDriverId,
          lat: position.latitude,
          lng: position.longitude,
          heading: position.heading.isFinite ? position.heading : null,
          speed: position.speed.isFinite ? position.speed : null,
        );
        _lastSentLat = position.latitude;
        _lastSentLng = position.longitude;
      } else {
        await _authService.touchDriverLocationPing(driverId: effectiveDriverId);
      }

      await AutomationTestLogger.log(
        'driver_location',
        'Live location synced successfully',
        data: {
          'driver_id': effectiveDriverId,
          'lat': position.latitude,
          'lng': position.longitude,
        },
      );

      return {'lat': position.latitude, 'lng': position.longitude};
    } catch (error) {
      await AutomationTestLogger.log(
        'driver_location',
        'Live location sync failed',
        data: {
          'driver_id': _normalizeDriverId(driverId ?? _driverId),
          'error': error.toString(),
        },
      );
      return null;
    }
  }

  Future<Map<String, double>?> _safeSyncNow({
    required String driverId,
    required bool requestPermissionIfNeeded,
  }) async {
    return syncNow(
      driverId: driverId,
      requestPermissionIfNeeded: requestPermissionIfNeeded,
    );
  }

  String? _normalizeDriverId(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return null;
    // Guard against malformed IDs accidentally injected into requests/logs.
    const uuidPattern = r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$';
    return RegExp(uuidPattern).hasMatch(text) ? text : null;
  }

  bool _shouldUpdateCoordinates(double lat, double lng) {
    final previousLat = _lastSentLat;
    final previousLng = _lastSentLng;
    if (previousLat == null || previousLng == null) return true;
    return _distanceMeters(previousLat, previousLng, lat, lng) >=
        minMovedMetersForCoordinateUpdate;
  }

  double _distanceMeters(double lat1, double lng1, double lat2, double lng2) {
    const earthRadiusMeters = 6371000.0;
    final dLat = _radians(lat2 - lat1);
    final dLng = _radians(lng2 - lng1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_radians(lat1)) *
            math.cos(_radians(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  double _radians(double degrees) => degrees * math.pi / 180;

  Future<bool> _ensurePermission({
    required bool requestPermissionIfNeeded,
  }) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && requestPermissionIfNeeded) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }
}
