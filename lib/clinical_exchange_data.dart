import 'dart:convert';

/// SQL identifier accepted by both the Android exporter and desktop reader.
/// Digits are allowed after the first character (e.g. the real cie10 table).
bool isExchangeTableName(String name) => RegExp(r'^[a-z_][a-z0-9_]*$').hasMatch(name);

/// Binary cells retain their bytes in a portable, encrypted JSON snapshot.
Map<String, Object?> exchangeRow(Map<String, Object?> row) => {
  for (final entry in row.entries)
    entry.key: entry.value is List<int>
        ? {r'$binary': base64Encode(entry.value as List<int>)}
        : entry.value,
};
