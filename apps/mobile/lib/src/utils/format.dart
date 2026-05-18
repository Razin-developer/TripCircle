String formatRelativeTime(String? isoDate) {
  if (isoDate == null || isoDate.isEmpty) {
    return 'just now';
  }

  final parsed = DateTime.tryParse(isoDate)?.toLocal();
  if (parsed == null) {
    return 'just now';
  }

  final difference = DateTime.now().difference(parsed);

  if (difference.inSeconds < 60) {
    return 'just now';
  }
  if (difference.inMinutes < 60) {
    final minutes = difference.inMinutes;
    return '$minutes min ago';
  }
  if (difference.inHours < 24) {
    final hours = difference.inHours;
    return '$hours hr ago';
  }
  if (difference.inDays < 7) {
    final days = difference.inDays;
    return '$days day${days == 1 ? '' : 's'} ago';
  }

  return '${parsed.day}/${parsed.month}/${parsed.year}';
}

String initialsFromName(String value, {String fallback = 'TC'}) {
  final pieces = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((piece) => piece.isNotEmpty)
      .toList();

  if (pieces.isEmpty) {
    return fallback;
  }

  if (pieces.length == 1) {
    return pieces.first.substring(0, pieces.first.length >= 2 ? 2 : 1).toUpperCase();
  }

  return '${pieces.first[0]}${pieces[1][0]}'.toUpperCase();
}

String maskPhoneNumber(String value) {
  if (value.length <= 4) {
    return value;
  }

  return '${value.substring(0, 2)}${'*' * (value.length - 4)}${value.substring(value.length - 2)}';
}
