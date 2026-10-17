import 'dart:convert';

/// Repairs text whose UTF-8 bytes were accidentally decoded as Latin-1 or
/// Windows-1252. Valid Unicode text is returned unchanged.
String repairUtf8Mojibake(String value) {
  var current = value;

  for (var attempt = 0; attempt < 3; attempt++) {
    final currentScore = _mojibakeScore(current);
    if (currentScore == 0) break;

    final bytes = _windows1252Bytes(_restoreLossyByteCharacters(current));
    if (bytes == null) break;

    late final String decoded;
    try {
      decoded = utf8.decode(bytes);
    } on FormatException {
      break;
    }

    final decodedScore = _mojibakeScore(decoded);
    if (decoded == current || decodedScore >= currentScore) break;
    current = decoded;
  }

  return current;
}

bool containsUtf8Mojibake(String value) => _mojibakeScore(value) > 0;

String _restoreLossyByteCharacters(String value) {
  // UTF-8 byte A0 is often normalized from a non-breaking space to a regular
  // space after a Windows-1252 decoding mistake. In Vietnamese this commonly
  // appears as "hÃ ng", "thÃ nh" or "TÃ i" instead of hàng/thành/Tài.
  return value.replaceAll('Ã ', 'Ã\u00A0');
}

int _mojibakeScore(String value) {
  var score = 0;

  for (final codePoint in value.runes) {
    if (codePoint >= 0x80 && codePoint <= 0x9F) {
      score += 3;
    }
    if (codePoint == 0xFFFD) {
      score += 4;
    }
  }

  const suspiciousFragments = [
    'Ã',
    'Â',
    'Ä',
    'Æ',
    'â€',
    'áº',
    'á»',
    'ï¿½',
    'ðŸ',
  ];
  for (final fragment in suspiciousFragments) {
    score += _occurrenceCount(value, fragment) * 2;
  }

  return score;
}

int _occurrenceCount(String value, String fragment) {
  var count = 0;
  var offset = 0;

  while (true) {
    final index = value.indexOf(fragment, offset);
    if (index == -1) return count;
    count++;
    offset = index + fragment.length;
  }
}

List<int>? _windows1252Bytes(String value) {
  final bytes = <int>[];
  for (final codePoint in value.runes) {
    final byte = codePoint <= 0xFF ? codePoint : _windows1252Reverse[codePoint];
    if (byte == null) return null;
    bytes.add(byte);
  }
  return bytes;
}

const _windows1252Reverse = <int, int>{
  0x20AC: 0x80,
  0x201A: 0x82,
  0x0192: 0x83,
  0x201E: 0x84,
  0x2026: 0x85,
  0x2020: 0x86,
  0x2021: 0x87,
  0x02C6: 0x88,
  0x2030: 0x89,
  0x0160: 0x8A,
  0x2039: 0x8B,
  0x0152: 0x8C,
  0x017D: 0x8E,
  0x2018: 0x91,
  0x2019: 0x92,
  0x201C: 0x93,
  0x201D: 0x94,
  0x2022: 0x95,
  0x2013: 0x96,
  0x2014: 0x97,
  0x02DC: 0x98,
  0x2122: 0x99,
  0x0161: 0x9A,
  0x203A: 0x9B,
  0x0153: 0x9C,
  0x017E: 0x9E,
  0x0178: 0x9F,
};
