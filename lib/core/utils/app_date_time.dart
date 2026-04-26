class AppDateTime {
  AppDateTime._();

  static String format(dynamic value, {String fallback = '-'}) {
    final raw = value?.toString();
    if (raw == null || raw.trim().isEmpty) return fallback;

    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;

    final local = parsed.toLocal();

    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '$day/$month/$year  $hour:$minute';
  }
}
