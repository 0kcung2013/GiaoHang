import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:giaohang_design/giaohang_design.dart';

import 'dispatch_preferences_providers.dart';
import 'dispatch_preferences_screen.dart';
import 'dispatch_preferences_strings.dart';

class DispatchPreferencesPage extends ConsumerWidget {
  const DispatchPreferencesPage({super.key, required this.userId});
  final String userId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(dispatchPreferencesProvider(userId))
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DispatchPreferencesStrings.loadError,
                  style: AppTextStyles.bodyMedium,
                ),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(dispatchPreferencesProvider(userId)),
                  child: const Text(DispatchPreferencesStrings.retry),
                ),
              ],
            ),
          ),
        ),
        data: (preferences) => DispatchPreferencesScreen(
          key: ValueKey(preferences.toJson().toString()),
          userId: userId,
          initial: preferences,
          embedded: true,
        ),
      );
}
