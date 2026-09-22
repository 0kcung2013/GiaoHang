import 'package:flutter/material.dart';
import 'package:giaohang_storage/giaohang_storage.dart';

/// Hiển thị cả URL HTTP cũ và `r2://` mới mà không để lộ R2 credential.
class StoredMediaImage extends StatefulWidget {
  const StoredMediaImage({
    super.key,
    required this.storedValue,
    required this.fallback,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.imageKey,
    this.r2Client,
  });

  final String? storedValue;
  final Widget fallback;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Key? imageKey;
  final R2MediaClient? r2Client;

  @override
  State<StoredMediaImage> createState() => _StoredMediaImageState();
}

class _StoredMediaImageState extends State<StoredMediaImage> {
  Future<String?>? _url;

  @override
  void initState() {
    super.initState();
    _url = _resolve();
  }

  @override
  void didUpdateWidget(covariant StoredMediaImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storedValue != widget.storedValue ||
        oldWidget.r2Client != widget.r2Client) {
      _url = _resolve();
    }
  }

  Future<String?> _resolve() async {
    final value = widget.storedValue?.trim();
    if (value == null || value.isEmpty) return null;
    if (!R2ObjectReference.isR2(value)) return value;
    return (widget.r2Client ?? R2MediaClient.supabase()).resolveUrl(value);
  }

  @override
  Widget build(BuildContext context) {
    final storedValue = widget.storedValue?.trim();
    if (storedValue == null || storedValue.isEmpty) return widget.fallback;
    if (!R2ObjectReference.isR2(storedValue)) {
      return _buildNetworkImage(storedValue);
    }
    return FutureBuilder<String?>(
      future: _url,
      builder: (context, snapshot) {
        final url = snapshot.data;
        if (snapshot.connectionState != ConnectionState.done ||
            snapshot.hasError ||
            url == null ||
            url.isEmpty) {
          return widget.fallback;
        }
        return _buildNetworkImage(url);
      },
    );
  }

  Widget _buildNetworkImage(String url) => Image.network(
    url,
    key: widget.imageKey,
    fit: widget.fit,
    width: widget.width,
    height: widget.height,
    errorBuilder: (_, _, _) => widget.fallback,
  );
}
