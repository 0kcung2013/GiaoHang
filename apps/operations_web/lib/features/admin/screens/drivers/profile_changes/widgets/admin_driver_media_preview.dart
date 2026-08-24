import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../data/admin_driver_media_resolver.dart';

class AdminDriverMediaPreview extends StatefulWidget {
  const AdminDriverMediaPreview({
    super.key,
    required this.label,
    required this.storedValue,
    required this.resolver,
    this.width = 132,
    this.height = 104,
  });

  final String label;
  final String? storedValue;
  final AdminDriverMediaResolver resolver;
  final double width;
  final double height;

  @override
  State<AdminDriverMediaPreview> createState() =>
      _AdminDriverMediaPreviewState();
}

class _AdminDriverMediaPreviewState extends State<AdminDriverMediaPreview> {
  late Future<String?> _resolvedUrl;

  @override
  void initState() {
    super.initState();
    _resolvedUrl = widget.resolver.resolve(widget.storedValue);
  }

  @override
  void didUpdateWidget(covariant AdminDriverMediaPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storedValue != widget.storedValue ||
        oldWidget.resolver != widget.resolver) {
      _resolvedUrl = widget.resolver.resolve(widget.storedValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: FutureBuilder<String?>(
        future: _resolvedUrl,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _MediaFrame(
              label: widget.label,
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                ),
              ),
            );
          }
          if (snapshot.hasError) {
            return _MediaFrame(
              label: widget.label,
              child: const Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  color: AppColors.error,
                ),
              ),
            );
          }
          final url = snapshot.data;
          if (url == null || url.isEmpty) {
            return _MediaFrame(
              label: widget.label,
              child: Center(
                child: Text(
                  'Chưa có ảnh',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            );
          }
          return Material(
            color: AppColors.bgLight,
            borderRadius: AppRadius.md,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _showFullImage(context, url),
              child: _MediaFrame(
                label: widget.label,
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showFullImage(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.bgCard,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920, maxHeight: 720),
          child: InteractiveViewer(
            child: Image.network(url, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

class _MediaFrame extends StatelessWidget {
  const _MediaFrame({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              color: AppColors.primary.withValues(alpha: 0.84),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textOnDark,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
