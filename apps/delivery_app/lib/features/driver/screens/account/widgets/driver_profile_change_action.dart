import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

class DriverProfileChangeAction extends StatelessWidget {
  const DriverProfileChangeAction({
    super.key,
    required this.request,
    required this.onCreate,
    required this.onView,
  });

  final DriverProfileChangeRequest? request;
  final VoidCallback onCreate;
  final ValueChanged<DriverProfileChangeRequest> onView;

  @override
  Widget build(BuildContext context) {
    final active = request?.isActive == true ? request : null;
    final isDraft = active?.status == DriverProfileChangeStatus.draft;
    final label = switch (active?.status) {
      DriverProfileChangeStatus.draft => 'Tiếp tục yêu cầu chỉnh sửa',
      DriverProfileChangeStatus.pending => 'Xem yêu cầu đang chờ',
      DriverProfileChangeStatus.applying => 'Xem thay đổi đang áp dụng',
      _ => 'Yêu cầu chỉnh sửa hồ sơ',
    };
    final icon = active == null
        ? Icons.edit_note_rounded
        : isDraft
        ? Icons.edit_document
        : Icons.schedule_rounded;

    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: Material(
          color: AppColors.accent,
          borderRadius: AppRadius.full,
          child: InkWell(
            onTap: active == null ? onCreate : () => onView(active),
            borderRadius: AppRadius.full,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: AppColors.textOnAccent, size: 21),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.textOnAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
