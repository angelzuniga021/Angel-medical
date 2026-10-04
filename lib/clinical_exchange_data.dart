import 'dart:convert';

/// Binary cells retain their bytes in a portable, encrypted JSON snapshot.
Map<String, Object?> exchangeRow(Map<String, Object?> row) => {
  for (final entry in row.entries)
    entry.key: entry.value is List<int>
        ? {r'$binary': base64Encode(entry.value as List<int>)}
        : entry.value,
};
