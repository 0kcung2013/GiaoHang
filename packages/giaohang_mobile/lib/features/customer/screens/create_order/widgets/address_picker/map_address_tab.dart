import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:giaohang_design/giaohang_design.dart';

import '../../address_picker_strings.dart';
import '../../controllers/address_picker_controller.dart';
import 'address_detail_form.dart';

class MapAddressTab extends StatelessWidget {
  const MapAddressTab({
    super.key,
    required this.controller,
    required this.onLocate,
  });

  final AddressPickerController controller;
  final VoidCallback onLocate;

  @override
  Widget build(BuildContext context) {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.zero,
      children: [
        SizedBox(
          height: 260,
          child: Stack(
            children: [
              FlutterMap(
                mapController: controller.mapController,
                options: MapOptions(
                  initialCenter: controller.selectedPosition,
                  initialZoom: 18,
                  minZoom: 5,
                  maxZoom: 19,
                  onMapEvent: controller.onMapMoved,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.datn.giaohang',
                    maxNativeZoom: 19,
                  ),
                  SimpleAttributionWidget(
                    source: Text(
                      'OpenStreetMap contributors',
                      style: AppTextStyles.labelSmall.copyWith(
                        fontSize: 9,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    backgroundColor: AppColors.bgCard.withValues(alpha: 0.86),
                  ),
                ],
              ),
              const IgnorePointer(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 36),
                    child: Icon(
                      Icons.location_on_rounded,
                      color: AppColors.accent,
                      size: 48,
                      shadows: AppShadow.card,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: AppSpacing.md,
                left: AppSpacing.md,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard.withValues(alpha: 0.94),
                    borderRadius: AppRadius.full,
                    boxShadow: AppShadow.subtle,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        controller.isResolving
                            ? Icons.more_horiz_rounded
                            : Icons.open_with_rounded,
                        size: 17,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        controller.isResolving
                            ? AddressPickerStrings.resolvingAddress
                            : AddressPickerStrings.moveMapHint,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: AppSpacing.md,
                bottom: AppSpacing.md,
                child: Semantics(
                  button: true,
                  label: AddressPickerStrings.locateMe,
                  child: Material(
                    color: AppColors.bgCard,
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: InkWell(
                      onTap: controller.isLocating ? null : onLocate,
                      customBorder: const CircleBorder(),
                      child: SizedBox(
                        width: 50,
                        height: 50,
                        child: Icon(
                          controller.isLocating
                              ? Icons.more_horiz_rounded
                              : Icons.my_location_rounded,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        AddressDetailForm(
          resolvedAddress: controller.resolvedAddress,
          isResolving: controller.isResolving,
          resolutionError: controller.resolutionError,
          detailController: controller.detailController,
          noteController: controller.noteController,
          detailError: controller.detailError,
          onDetailChanged: (_) => controller.clearDetailError(),
          saveAddress: controller.saveAddress,
          labelType: controller.labelType,
          customLabelController: controller.customLabelController,
          onSaveChanged: controller.setSaveAddress,
          onLabelChanged: controller.setLabelType,
          onCustomLabelChanged: (_) => controller.clearCustomLabelError(),
          customLabelError: controller.customLabelError,
          saveError: controller.saveError,
        ),
      ],
    );
  }
}
