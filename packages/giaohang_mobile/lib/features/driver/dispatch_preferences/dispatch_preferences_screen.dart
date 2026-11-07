import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/customer_providers.dart';
import '../../../core/providers/location_providers.dart';
import 'destination_picker_screen.dart';
import 'dispatch_preferences.dart';
import 'dispatch_preferences_providers.dart';
import 'dispatch_preferences_strings.dart';
import 'widgets/dispatch_mode_selector.dart';
import 'widgets/dispatch_mode_form.dart';

class DispatchPreferencesScreen extends ConsumerStatefulWidget {
  const DispatchPreferencesScreen({
    super.key,
    required this.userId,
    required this.initial,
    this.embedded = false,
  });
  final String userId;
  final DispatchPreferences initial;
  final bool embedded;
  @override
  ConsumerState<DispatchPreferencesScreen> createState() =>
      _DispatchPreferencesScreenState();
}

class _DispatchPreferencesScreenState
    extends ConsumerState<DispatchPreferencesScreen> {
  late DispatchMode _mode;
  late int? _deliveryLimit;
  String? _areaId;
  DispatchDestination? _destination;
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _mode = widget.initial.mode;
    _deliveryLimit = widget.initial.nearbyDeliveryLimitMeters;
    _areaId = widget.initial.areaId;
    if (widget.initial.destination != null) {
      _destination = DispatchDestination(
        widget.initial.destination!,
        widget.initial.destinationLabel!,
      );
    }
  }

  Future<void> _save({bool end = false}) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final mode = end ? DispatchMode.nearby : _mode;
      await ref
          .read(dispatchPreferencesRepositoryProvider)
          .save(
            DispatchPreferences(
              mode: mode,
              areaId: mode == DispatchMode.area ? _areaId : null,
              destination: mode == DispatchMode.destination
                  ? _destination?.point
                  : null,
              destinationLabel: mode == DispatchMode.destination
                  ? _destination?.label
                  : null,
              nearbyDeliveryLimitMeters: _deliveryLimit,
            ),
          );
      if (!mounted) return;
      ref.invalidate(dispatchPreferencesProvider(widget.userId));
      ref.invalidate(driverByUserIdProvider(widget.userId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(DispatchPreferencesStrings.saved)),
      );
      if (!widget.embedded) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error =
              error is PostgrestException &&
                  error.message.contains('DISPATCH_OFFER_PENDING')
              ? DispatchPreferencesStrings.pendingOffer
              : DispatchPreferencesStrings.saveError,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final driver = ref.watch(driverByUserIdProvider(widget.userId)).valueOrNull;
    final physical = ref.watch(driverPhysicalPositionProvider);
    final origin =
        physical ??
        (driver?.currentLat != null && driver?.currentLng != null
            ? LatLng(driver!.currentLat!, driver.currentLng!)
            : null);
    final canSave =
        !_saving &&
        (_mode == DispatchMode.nearby ||
            (_mode == DispatchMode.area && _areaId != null) ||
            (_mode == DispatchMode.destination && _destination != null));
    final content = SafeArea(
      top: false,
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.screenH),
                  children: [
                    DispatchModeSelector(
                      mode: _mode,
                      onChanged: _saving
                          ? null
                          : (value) => setState(() {
                              _mode = value;
                              _error = null;
                            }),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    DispatchModeForm(
                      mode: _mode,
                      enabled: !_saving,
                      areaId: _areaId,
                      onAreaChanged: (value) => setState(() => _areaId = value),
                      deliveryLimit: _deliveryLimit,
                      onLimitChanged: (value) =>
                          setState(() => _deliveryLimit = value),
                      destination: _destination,
                      origin: origin,
                      expired:
                          widget.initial.expired &&
                          _destination?.point == widget.initial.destination,
                      onPickDestination: () async {
                        final picked =
                            await Navigator.push<DispatchDestination>(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    DestinationPickerScreen(origin: origin),
                              ),
                            );
                        if (picked != null && mounted) {
                          setState(() => _destination = picked);
                        }
                      },
                    ),
                    if (widget.initial.mode == DispatchMode.destination)
                      TextButton(
                        onPressed: _saving ? null : () => _save(end: true),
                        child: Text(
                          DispatchPreferencesStrings.end,
                          style: AppTextStyles.labelMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          DecoratedBox(
            decoration: const BoxDecoration(
              color: AppColors.bgCard,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenH,
                    vertical: AppSpacing.md,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              _error!,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ),
                      FilledButton(
                        onPressed: canSave ? () => _save() : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.textOnAccent,
                          textStyle: AppTextStyles.labelLarge,
                          minimumSize: const Size.fromHeight(52),
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppRadius.lg,
                          ),
                        ),
                        child: _saving
                            ? const SizedBox.square(
                                dimension: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(DispatchPreferencesStrings.save),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        DispatchPreferencesStrings.newOffersOnly,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    if (widget.embedded) {
      return ColoredBox(color: AppColors.bgLight, child: content);
    }
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        backgroundColor: AppColors.bgLight,
        appBar: AppBar(
          backgroundColor: AppColors.bgLight,
          toolbarHeight: MediaQuery.textScalerOf(context).scale(18) > 24
              ? 80
              : 56,
          title: Text(
            DispatchPreferencesStrings.title,
            maxLines: 2,
            style: AppTextStyles.headingMedium,
          ),
        ),
        body: content,
      ),
    );
  }
}
