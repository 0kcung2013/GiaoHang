import 'package:flutter/material.dart';

import 'package:giaohang_design/giaohang_design.dart';
import '../../../../../core/utils/money_formatter.dart';
import '../../../../../core/utils/vnd_input_formatter.dart';

Future<int?> showWalletTopupSheet(BuildContext context) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _WalletTopupSheet(),
  );
}

class _WalletTopupSheet extends StatefulWidget {
  const _WalletTopupSheet();

  @override
  State<_WalletTopupSheet> createState() => _WalletTopupSheetState();
}

class _WalletTopupSheetState extends State<_WalletTopupSheet> {
  final _controller = TextEditingController(text: '200.000');
  int get amount => parseVndInput(_controller.text);

  @override
  void dispose() {
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
                decoration: const InputDecoration(
                  labelText: 'Số tiền',
                  suffixText: 'đ',
                  border: OutlineInputBorder(borderRadius: AppRadius.md),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: amount >= 5000 && amount <= 10000000
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
