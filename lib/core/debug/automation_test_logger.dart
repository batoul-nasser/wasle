import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

class AutomationTestLogger {
  AutomationTestLogger._();

  static Future<void> log(
    String area,
    String message, {
    Map<String, dynamic>? data,
  }) async {
    final payload = <String, dynamic>{
      'ts': DateTime.now().toUtc().toIso8601String(),
      'area': area,
      'message': message,
      if (data != null && data.isNotEmpty) 'data': data,
    };
    final encoded = jsonEncode(payload);
    developer.log(encoded, name: 'AutomationTestLogger');
    debugPrint('[AUTOMATION][$area] $message ${data ?? const {}}');
  }

  static Future<void> clear() async {}

  static Future<String> getLogPath() async => 'debug console';
}
