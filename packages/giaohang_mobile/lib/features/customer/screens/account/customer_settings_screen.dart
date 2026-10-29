import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../notifications/screens/notifications_screen.dart';
import '../../../notifications/models/notification_inbox_item.dart';
import '../../../../core/mobile_app_role.dart';
import '../../../help_center/screens/general_support_chat_screen.dart';
import 'constants/customer_account_strings.dart';
import 'widgets/account_components.dart';

class CustomerSettingsScreen extends StatefulWidget {
  const CustomerSettingsScreen({super.key});
  @override
  State<CustomerSettingsScreen> createState() => _CustomerSettingsScreenState();
}

class _CustomerSettingsScreenState extends State<CustomerSettingsScreen> {
  late Future<LocationPermission?> _permission = _checkPermission();
  Future<LocationPermission?> _checkPermission() async {
    try {
      return await Geolocator.checkPermission();
    } catch (_) {
      return null;
    }
  }

  Future<void> _openSettings() async {
    try {
      if (await Geolocator.openAppSettings()) return;
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(CustomerAccountStrings.permissionSettingsError),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final providers = user?.appMetadata['providers'];
    final google = providers is List && providers.contains('google');
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: Text(
          CustomerAccountStrings.settings,
          style: AppTextStyles.headingMedium,
        ),
        backgroundColor: AppColors.bgCard,
        surfaceTintColor: AppColors.bgCard,
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.screenH),
              children: [
                Text(
                  CustomerAccountStrings.security,
                  style: AppTextStyles.headingSmall,
                ),
                const SizedBox(height: AppSpacing.md),
                CustomerAccountSurface(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          CustomerAccountStrings.email,
                          style: AppTextStyles.labelMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        SelectableText(
                          user?.email ?? CustomerAccountStrings.missing,
                          style: AppTextStyles.bodyMedium,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          CustomerAccountStrings.loginMethod,
                          style: AppTextStyles.labelMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          google
                              ? CustomerAccountStrings.google
                              : CustomerAccountStrings.emailPassword,
                          style: AppTextStyles.bodyMedium,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          google
                              ? CustomerAccountStrings.googleHint
                              : CustomerAccountStrings.securityHint,
                          style: AppTextStyles.bodySmall,
                        ),
                        TextButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const GeneralSupportChatScreen(
                                role: MobileAppRole.customer,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.support_agent_rounded),
                          label: const Text(
                            CustomerAccountStrings.accountSupport,
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.accent,
                            minimumSize: const Size(48, 48),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl2),
                Text(
                  CustomerAccountStrings.permissions,
                  style: AppTextStyles.headingSmall,
                ),
                const SizedBox(height: AppSpacing.md),
                CustomerAccountSurface(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          CustomerAccountStrings.location,
                          style: AppTextStyles.labelMedium,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        FutureBuilder<LocationPermission?>(
                          future: _permission,
                          builder: (context, snapshot) {
                            final allowed =
                                snapshot.data == LocationPermission.always ||
                                snapshot.data == LocationPermission.whileInUse;
                            return Text(
                              snapshot.connectionState !=
                                          ConnectionState.done ||
                                      snapshot.data == null
                                  ? CustomerAccountStrings.locationUnavailable
                                  : allowed
                                  ? CustomerAccountStrings.locationAllowed
                                  : CustomerAccountStrings.locationDenied,
                              style: AppTextStyles.bodyMedium,
                            );
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          kIsWeb
                              ? CustomerAccountStrings.browserPermissionHint
                              : CustomerAccountStrings.devicePermissionHint,
                          style: AppTextStyles.bodySmall,
                        ),
                        TextButton(
                          onPressed: () =>
                              setState(() => _permission = _checkPermission()),
                          child: const Text(
                            CustomerAccountStrings.checkPermissions,
                          ),
                        ),
                        if (!kIsWeb)
                          TextButton(
                            onPressed: _openSettings,
                            child: const Text(
                              CustomerAccountStrings.openDeviceSettings,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                CustomerAccountSurface(
                  child: CustomerAccountAction(
                    icon: Icons.notifications_none_rounded,
                    label: CustomerAccountStrings.notificationHint,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const NotificationsScreen(
                          audience: NotificationAudience.customer,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
