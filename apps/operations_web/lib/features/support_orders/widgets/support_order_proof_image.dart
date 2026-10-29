import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../utils/support_order_proof_strings.dart';

/// Resolves a fresh private URL when mounted or retried, including in the viewer.
class SupportOrderProofImage extends StatefulWidget {
  const SupportOrderProofImage({
    required this.loadUrl,
    required this.semanticLabel,
    super.key,
  });

  final Future<String> Function() loadUrl;
  final String semanticLabel;

  @override
  State<SupportOrderProofImage> createState() => _SupportOrderProofImageState();
}

class _SupportOrderProofImageState extends State<SupportOrderProofImage> {
  late Future<String?> _url;

  @override
  void initState() {
    super.initState();
    _url = _loadUrl();
  }

  Future<String?> _loadUrl() async {
    try {
      return await widget.loadUrl();
    } catch (_) {
      return null;
    }
  }

  void _retry() => setState(() {
    _url = _loadUrl();
  });

  Widget _failure() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.broken_image_outlined, color: AppColors.textSecondary),
        const SizedBox(height: AppSpacing.xs),
        Text(
          SupportOrderProofStrings.imageError,
          style: AppTextStyles.bodySmall,
        ),
        TextButton.icon(
          onPressed: _retry,
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 48),
            foregroundColor: AppColors.primary,
            textStyle: AppTextStyles.labelMedium,
          ),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text(SupportOrderProofStrings.retry),
        ),
      ],
    ),
  );

  Widget _loading() => const Center(
    child: SizedBox.square(
      dimension: 24,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: AppColors.accent,
        semanticsLabel: SupportOrderProofStrings.loading,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => FutureBuilder<String?>(
    future: _url,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) return _loading();
      if (snapshot.hasError || snapshot.data?.isNotEmpty != true) {
        return _failure();
      }
      return Image.network(
        snapshot.data!,
        fit: BoxFit.contain,
        semanticLabel: widget.semanticLabel,
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : _loading(),
        errorBuilder: (_, _, _) => _failure(),
      );
    },
  );
}
