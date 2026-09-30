DateTime? parseBirthDate(String text, {DateTime? now}) {
  final value = text.trim();
  final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  final local = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(value);
  if (iso == null && local == null) return null;
  final year = int.parse(iso?.group(1) ?? local!.group(3)!);
  final month = int.parse(iso?.group(2) ?? local!.group(2)!);
  final day = int.parse(iso?.group(3) ?? local!.group(1)!);
  final d = DateTime(year, month, day);
  final today = now ?? DateTime.now();
  if (d.year != year ||
      d.month != month ||
      d.day != day ||
      year < 1850 ||
      d.isAfter(DateTime(today.year, today.month, today.day)))
    return null;
  return d;
}

String birthDateIso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
String birthDateDisplay(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year.toString().padLeft(4, '0')}';
