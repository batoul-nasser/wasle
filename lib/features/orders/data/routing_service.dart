import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:wasle/env.dart';

import 'assignment_models.dart';

class TravelEstimate {
  final int durationSeconds;
  final double distanceMeters;
  final String source;

  const TravelEstimate({
    required this.durationSeconds,
    required this.distanceMeters,
    required this.source,
  });
}

abstract class RoutingService {
  Future<TravelEstimate> getTravelEstimate({
    required AssignmentLocation origin,
    required AssignmentLocation destination,
    DateTime? departureTime,
    String? vehicleType,
  });
}

class SupabaseEdgeRoutingService implements RoutingService {
  static final Uri _routeEstimateUri = Uri.parse(
    '${Env.supabaseUrl}/functions/v1/route-estimate',
  );

  final http.Client _httpClient;
  final RoutingService _fallback;

  SupabaseEdgeRoutingService({
    http.Client? httpClient,
    RoutingService? fallback,
  }) : _httpClient = httpClient ?? http.Client(),
       _fallback = fallback ?? CachedMockRoutingService();

  @override
  Future<TravelEstimate> getTravelEstimate({
    required AssignmentLocation origin,
    required AssignmentLocation destination,
    DateTime? departureTime,
    String? vehicleType,
  }) async {
    if (!origin.hasCoordinates || !destination.hasCoordinates) {
      return _fallback.getTravelEstimate(
        origin: origin,
        destination: destination,
        departureTime: departureTime,
        vehicleType: vehicleType,
      );
    }

    try {
      final response = await _httpClient
          .post(
            _routeEstimateUri,
            headers: {
              'Content-Type': 'application/json',
              'apikey': Env.supabaseAnonKey,
            },
            body: jsonEncode({
              'origin': {'lat': origin.lat, 'lng': origin.lng},
              'destination': {
                'lat': destination.lat,
                'lng': destination.lng,
              },
              'vehicleType': vehicleType ?? 'motorcycle',
              if (departureTime != null)
                'departureTime': departureTime.toUtc().toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('route-estimate failed with ${response.statusCode}');
      }

      final payload = jsonDecode(response.body);
      if (payload is! Map<String, dynamic>) {
        throw Exception('route-estimate returned a non-object payload');
      }

      final data = _normalizePayload(payload);
      final durationSeconds = _toInt(data['durationSeconds']);
      final distanceMeters = _toDouble(data['distanceMeters']);
      final source = data['source']?.toString();

      if (durationSeconds == null || distanceMeters == null || source == null) {
        throw Exception('route-estimate response is missing required fields');
      }

      return TravelEstimate(
        durationSeconds: durationSeconds,
        distanceMeters: distanceMeters,
        source: source,
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[auto-assign] route-estimate failed, using fallback: $error');
      }
      return _fallback.getTravelEstimate(
        origin: origin,
        destination: destination,
        departureTime: departureTime,
        vehicleType: vehicleType,
      );
    }
  }

  Map<String, dynamic> _normalizePayload(Map<String, dynamic> payload) {
    final nestedData = payload['data'];
    if (nestedData is Map<String, dynamic>) {
      return nestedData;
    }
    if (nestedData is Map) {
      return Map<String, dynamic>.from(nestedData);
    }
    return payload;
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value.toString());
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

class CachedMockRoutingService implements RoutingService {
  static final Map<String, TravelEstimate> _sharedCache =
      <String, TravelEstimate>{};

  @override
  Future<TravelEstimate> getTravelEstimate({
    required AssignmentLocation origin,
    required AssignmentLocation destination,
    DateTime? departureTime,
    String? vehicleType,
  }) async {
    final key = _cacheKey(
      origin: origin,
      destination: destination,
      departureTime: departureTime,
      vehicleType: vehicleType,
    );

    final cached = _sharedCache[key];
    if (cached != null) return cached;

    final estimate = _estimateTravel(
      origin: origin,
      destination: destination,
      vehicleType: vehicleType,
    );
    _sharedCache[key] = estimate;
    return estimate;
  }

  String _cacheKey({
    required AssignmentLocation origin,
    required AssignmentLocation destination,
    required DateTime? departureTime,
    required String? vehicleType,
  }) {
    final bucket = _timeBucket(departureTime ?? DateTime.now().toUtc());
    return [
      origin.cacheIdentity,
      destination.cacheIdentity,
      vehicleType?.toLowerCase() ?? 'default',
      bucket,
    ].join('>');
  }

  String _timeBucket(DateTime time) {
    final utc = time.toUtc();
    final minuteBucket = (utc.minute ~/ 15) * 15;
    return '${utc.year}-${utc.month}-${utc.day}-${utc.hour}-$minuteBucket';
  }

  TravelEstimate _estimateTravel({
    required AssignmentLocation origin,
    required AssignmentLocation destination,
    required String? vehicleType,
  }) {
    if (origin.cacheIdentity == destination.cacheIdentity) {
      return const TravelEstimate(
        durationSeconds: 60,
        distanceMeters: 0,
        source: 'cached_mock',
      );
    }

    if (origin.hasCoordinates && destination.hasCoordinates) {
      final straightLineMeters = _haversineMeters(
        origin.lat!,
        origin.lng!,
        destination.lat!,
        destination.lng!,
      );
      final roadDistanceMeters = straightLineMeters * 1.35;
      final speedMetersPerSecond = _averageSpeedMetersPerSecond(vehicleType);
      final duration = math.max(
        120,
        (roadDistanceMeters / speedMetersPerSecond).round(),
      );
      return TravelEstimate(
        durationSeconds: duration,
        distanceMeters: roadDistanceMeters,
        source: 'cached_mock',
      );
    }

    final hash = _stableHash(
      '${origin.cacheIdentity}|${destination.cacheIdentity}',
    );
    final minutes = 8 + (hash % 17);
    final duration = minutes * 60;
    return TravelEstimate(
      durationSeconds: duration,
      distanceMeters: duration * _averageSpeedMetersPerSecond(vehicleType),
      source: 'cached_mock',
    );
  }

  double _averageSpeedMetersPerSecond(String? vehicleType) {
    switch (vehicleType?.toLowerCase()) {
      case 'motorcycle':
        return 32 * 1000 / 3600;
      case 'van':
        return 24 * 1000 / 3600;
      case 'car':
        return 28 * 1000 / 3600;
      default:
        return 26 * 1000 / 3600;
    }
  }

  double _haversineMeters(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusMeters = 6371000.0;
    final dLat = _radians(lat2 - lat1);
    final dLon = _radians(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_radians(lat1)) *
            math.cos(_radians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  double _radians(double degrees) => degrees * math.pi / 180;

  int _stableHash(String value) {
    var hash = 0;
    for (final codeUnit in value.codeUnits) {
      hash = 0x1fffffff & (hash + codeUnit);
      hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
      hash ^= hash >> 6;
    }
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    hash ^= hash >> 11;
    hash = 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
    return hash.abs();
  }
}
