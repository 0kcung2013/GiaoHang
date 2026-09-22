final class R2ObjectReference {
  const R2ObjectReference._();

  static const scheme = 'r2';

  static bool isR2(String? value) {
    if (value == null) return false;
    return Uri.tryParse(value.trim())?.scheme.toLowerCase() == scheme;
  }

  static String? bucket(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.scheme.toLowerCase() != scheme) return null;
    return uri.host.isEmpty ? null : uri.host;
  }

  static String? key(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.scheme.toLowerCase() != scheme) return null;
    final key = uri.pathSegments.map(Uri.decodeComponent).join('/');
    return key.isEmpty ? null : key;
  }
}
