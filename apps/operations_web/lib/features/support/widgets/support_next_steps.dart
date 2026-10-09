import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:go_router/go_router.dart';
import '../../support_orders/utils/support_order_ui.dart';
import '../models/support_completion_context.dart';

class SupportNextSteps extends StatelessWidget {
  const SupportNextSteps({
    required this.ticket,
    this.completion,
    this.loading = false,
    this.error,
    this.onRetry,
    super.key,
  });
  final SupportTicket ticket;
  final SupportCompletionContext? completion;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final issue = SupportIssue.fromSubject(ticket.subject);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: AppRadius.md,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Việc cần làm', style: AppTextStyles.headingSmall),
          if (completion?.orderStatus != null)
            Text(
              SupportOrderUi.statusLabel(completion!.orderStatus!),
              style: AppTextStyles.labelMedium,
            ),
          if (ticket.status.isClosed)
            Text(
              'Hồ sơ đã kết thúc. Mở lại nếu cần xử lý tiếp.',
              style: AppTextStyles.bodySmall,
            )
          else ...[
            if (ticket.assignedTo == null)
              Text(
                'Nhận xử lý để phản hồi và thực hiện nghiệp vụ.',
                style: AppTextStyles.bodySmall,
              ),
            for (final step in issue.verification)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text('• $step', style: AppTextStyles.bodySmall),
              ),
            const SizedBox(height: AppSpacing.md),
            Text('Trước khi kết thúc', style: AppTextStyles.labelMedium),
            Text(issue.completionHint, style: AppTextStyles.bodySmall),
            if (loading) const LinearProgressIndicator(color: AppColors.accent),
            if (error != null)
              Text(
                error!,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
              ),
            for (final blocker
                in completion?.blockers ?? <SupportCompletionBlocker>[]) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                blocker.message,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    context.push('/support-case/${blocker.riskReportId}'),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Xử lý việc còn lại'),
              ),
            ],
            if (onRetry != null)
              TextButton.icon(
                onPressed: loading ? null : onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Kiểm tra lại điều kiện'),
              ),
          ],
        ],
      ),
    );
  }
}
