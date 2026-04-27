import 'package:flutter/foundation.dart';

class AutomationTestLogger {
  static Future<void> log(
    String tag,
    String message, {
    Map<String, dynamic>? data,
  }) async {
    if (!kDebugMode) return;
    final payload = data == null || data.isEmpty ? '' : ' $data';
    debugPrint('[AUTOMATION][$tag] $message$payload');
  }
}
