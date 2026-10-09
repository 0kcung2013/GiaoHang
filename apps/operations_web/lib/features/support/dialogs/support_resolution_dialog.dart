import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

class SupportResolutionDialog extends StatefulWidget {
  const SupportResolutionDialog({super.key});
  @override
  State<SupportResolutionDialog> createState() =>
      _SupportResolutionDialogState();
}

class _SupportResolutionDialogState extends State<SupportResolutionDialog> {
  final _controller = TextEditingController();
  String? _error;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: AppColors.bgCard,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.lg),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Kết thúc yêu cầu', style: AppTextStyles.headingMedium),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              key: const Key('support-resolution-field'),
              controller: _controller,
              minLines: 3,
              maxLines: 6,
              maxLength: 4000,
              decoration: InputDecoration(
                labelText: 'Kết quả xử lý',
                hintText:
                    'Đã làm gì? Kết quả ra sao? Bên nào đã được thông báo?',
                errorText: _error,
                filled: true,
                fillColor: AppColors.bgLight,
                border: const OutlineInputBorder(borderRadius: AppRadius.md),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: AppSpacing.sm,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  onPressed: () {
                    final value = _controller.text.trim();
                    if (value.length < 3) {
                      setState(() => _error = 'Vui lòng nhập kết quả xử lý.');
                      return;
                    }
                    Navigator.pop(context, value);
                  },
                  child: const Text('Xác nhận'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
