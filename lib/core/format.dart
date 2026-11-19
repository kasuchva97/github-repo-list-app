/// 1234 → "1.2k", 1500000 → "1.5M".
String compactNumber(int value) {
  if (value < 1000) return '$value';
  if (value < 1000000) return '${_trim(value / 1000)}k';
  return '${_trim(value / 1000000)}M';
}

String _trim(double v) {
  final s = v >= 100 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

/// 1234567 → "1,234,567".
String withSeparators(int value) => value.toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (_) => ',',
);

/// "just now", "5 minutes ago", "3 days ago", "2 years ago".
String relativeTime(DateTime time, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(time);
  if (diff.isNegative || diff.inMinutes < 1) return 'just now';
  String unit(int n, String name) => '$n $name${n == 1 ? '' : 's'} ago';
  if (diff.inMinutes < 60) return unit(diff.inMinutes, 'minute');
  if (diff.inHours < 24) return unit(diff.inHours, 'hour');
  if (diff.inDays < 30) return unit(diff.inDays, 'day');
  if (diff.inDays < 365) return unit(diff.inDays ~/ 30, 'month');
  return unit(diff.inDays ~/ 365, 'year');
}
