import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/constants/app_theme.dart';
import '../../../../../core/providers/customer_providers.dart';
import '../../../../notifications/models/notification_inbox_item.dart';
import '../../../../notifications/widgets/notification_bell_button.dart';
import '../dashboard_strings.dart';

class DashboardHeader extends ConsumerWidget {
  const DashboardHeader({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(customerProfileProvider(user.id)).valueOrNull;
    final fullName = _resolveFullName(
      profileName: profile?.fullName,
      metadataName: user.userMetadata?['full_name']?.toString(),
      email: user.email,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
          ),
          child: const NotificationBellButton(
            audience: NotificationAudience.customer,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _CustomerAvatar(name: fullName),
      ],
    );
  }
}

class _CustomerAvatar extends StatelessWidget {
  const _CustomerAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(name);

    return Semantics(
      image: true,
      label: DashboardStrings.avatarSemantics(name),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.accentLight,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.18)),
        ),
        alignment: Alignment.center,
        child: Text(
          initials,
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.accent,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

String _resolveFullName({
  required String? profileName,
  required String? metadataName,
  required String? email,
}) {
  final candidates = [profileName, metadataName];
  for (final candidate in candidates) {
    final normalized = candidate?.trim() ?? '';
    if (normalized.isNotEmpty) return normalized;
  }

  final emailName = email?.split('@').first.trim() ?? '';
  return emailName.isNotEmpty ? emailName : DashboardStrings.customerFallback;
}

String _initials(String fullName) {
  final parts = fullName
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.length >= 2) {
    return '${parts[parts.length - 2][0]}${parts.last[0]}'.toUpperCase();
  }
  if (parts.isEmpty) return DashboardStrings.customerInitials;
  final name = parts.first;
  return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
}
