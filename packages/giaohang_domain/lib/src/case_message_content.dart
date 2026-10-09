/// Ảnh riêng tư được tham chiếu trong body hiện có; không lưu URL tải có hạn.
class CaseMessageContent {
  const CaseMessageContent({required this.text, this.images = const []});

  final String text;
  final List<String> images;
  static const maxImages = 3;
  static const imageLabel = 'Ảnh đính kèm';
  static const _marker = '\n\n[$imageLabel](';
  static final _imageLine = RegExp(r'^\[Ảnh đính kèm\]\(([^\s)]+)\)$');
  static final _privateImage = RegExp(
    r'^r2://media/users/[A-Za-z0-9_-]+/order-cargo/[A-Za-z0-9_-]+/support-chat/[A-Za-z0-9_.-]+\.(jpg|png|webp)$',
  );

  static bool isSupportedImage(String value) => _privateImage.hasMatch(value);

  String encode() {
    if (images.isEmpty) return text.trim();
    if (images.length > maxImages ||
        images.any((uri) => !isSupportedImage(uri))) {
      throw ArgumentError('Invalid support chat images');
    }
    final caption = text.trim().isEmpty ? imageLabel : text.trim();
    return '$caption\n\n${images.map((uri) => '[$imageLabel]($uri)').join('\n')}';
  }

  factory CaseMessageContent.decode(String body) {
    final start = body.lastIndexOf(_marker);
    if (start < 0) return CaseMessageContent(text: body);
    final lines = body.substring(start + 2).split('\n');
    if (lines.length > maxImages) return CaseMessageContent(text: body);
    final images = <String>[];
    for (final line in lines) {
      final uri = _imageLine.firstMatch(line)?.group(1);
      if (uri == null || !isSupportedImage(uri)) {
        return CaseMessageContent(text: body);
      }
      images.add(uri);
    }
    return CaseMessageContent(
      text: body.substring(0, start),
      images: List.unmodifiable(images),
    );
  }
}
