import 'dart:async';

import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../../core/utils/money_formatter.dart';
import '../../../../../core/utils/vnd_input_formatter.dart';
import '../../../../../core/services/business_settings_service.dart';
import 'package:giaohang_domain/giaohang_domain.dart' show BusinessSettings;

Future<int?> showWalletTopupSheet(
  BuildContext context, {
  BusinessSettings? settings,
  Stream<BusinessSettings>? updates,
}) async {
  final live = settings == null;
  try {
    settings ??= await BusinessSettingsService().load();
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không tải được hạn mức nạp ví. Vui lòng thử lại.'),
        ),
      );
    }
    return null;
  }
  if (!context.mounted) return null;
  final policy = settings;
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _WalletTopupSheet(
      settings: policy,
      updates: updates ?? (live ? BusinessSettingsService().watch() : null),
    ),
  );
}

class _WalletTopupSheet extends StatefulWidget {
  const _WalletTopupSheet({required this.settings, this.updates});
  final BusinessSettings settings;
  final Stream<BusinessSettings>? updates;

  @override
  State<_WalletTopupSheet> createState() => _WalletTopupSheetState();
}

class _WalletTopupSheetState extends State<_WalletTopupSheet> {
  final _controller = TextEditingController(text: '200.000');
  late BusinessSettings _settings;
  StreamSubscription<BusinessSettings>? _subscription;
  int get amount => parseVndInput(_controller.text);
  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
    _controller.text = formatVndDigits(
      200000.clamp(widget.settings.topupMin, widget.settings.topupMax),
    );
    if (widget.updates != null) {
      _subscription = widget.updates!.listen(
        (settings) {
          if (mounted && settings.revision > _settings.revision) {
            setState(() => _settings = settings);
          }
        },
        onError: (Object _) {
          /* Submit rechecks limits against the server. */
        },
      );
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
        ),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl2),
          decoration: const BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: AppRadius.xl2,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nạp ví', style: AppTextStyles.headingLarge),
              const SizedBox(height: AppSpacing.lg),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final value in const [100000, 200000, 500000])
                    if (value >= _settings.topupMin &&
                        value <= _settings.topupMax)
                      ActionChip(
                        label: Text(formatVnd(value)),
                        onPressed: () => setState(
                          () => _controller.text = formatVndDigits(value),
                        ),
                      ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                inputFormatters: const [VndInputFormatter()],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Số tiền',
                  suffixText: 'đ',
                  helperText:
                      '${formatVnd(_settings.topupMin)} – ${formatVnd(_settings.topupMax)} mỗi lần',
                  helperMaxLines: 3,
                  border: const OutlineInputBorder(borderRadius: AppRadius.md),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed:
                      amount >= _settings.topupMin &&
                          amount <= _settings.topupMax
                      ? () => Navigator.of(context).pop(amount)
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.full),
                  ),
                  child: const Text('Tiếp tục với VNPAY'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
