import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:giaohang_design/giaohang_design.dart';

import '../../address_picker_strings.dart';
import '../../controllers/address_picker_controller.dart';
import '../../models/address_picker_result.dart';
import '../../utils/pickup_context_camera_fit.dart';
import 'address_detail_form.dart';
import 'address_map_dot.dart';

class MapAddressTab extends StatelessWidget {
  const MapAddressTab({
    super.key,
    required this.controller,
    required this.onLocate,
    this.saveRequired = false,
    this.pickupSelection,
    this.isPickup = false,
    this.tileProvider,
    this.shrinkWrap = false,
  });

  final AddressPickerController controller;
  final VoidCallback onLocate;
  final bool saveRequired;
  final MapPickerResult? pickupSelection;
  final bool isPickup;
  final TileProvider? tileProvider;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
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
                  initialCameraFit: pickupSelection == null
                      ? null
                      : PickupContextCameraFit(
                          pickup: pickupSelection!.position,
                          selection: controller.selectedPosition,
                        ),
                  minZoom: pickupSelection == null ? 5 : 0,
                  maxZoom: 19,
                  onMapEvent: controller.onMapMoved,
                ),
                children: [
                  TileLayer(
                    tileProvider: tileProvider,
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.datn.giaohang',
                    maxNativeZoom: 19,
                  ),
                  if (pickupSelection != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          key: const ValueKey('address-picker-pickup-marker'),
                          point: pickupSelection!.position,
                          width: AddressMapDot.diameter,
                          height: AddressMapDot.diameter,
                          alignment: Alignment.center,
                          child: AddressMapDot(
                            color: AppColors.markerPickup,
                            label:
                                '${AddressPickerStrings.pickupSelected}: ${pickupSelection!.address}',
                          ),
                        ),
                      ],
                    ),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: ColoredBox(
                      color: AppColors.bgCard.withValues(alpha: 0.86),
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: Text(
                          AddressPickerStrings.mapAttribution,
                          style: AppTextStyles.labelSmall.copyWith(
                            fontSize: 9,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              IgnorePointer(
                child: Center(
                  child: AddressMapDot(
                    key: const ValueKey('address-picker-selection-marker'),
                    label: isPickup
                        ? AddressPickerStrings.pickupShort
                        : AddressPickerStrings.deliveryShort,
                    color: isPickup
                        ? AppColors.markerPickup
                        : AppColors.markerDrop,
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
                bottom: pickupSelection == null
                    ? AppSpacing.md
                    : AppSpacing.xl3,
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
              if (pickupSelection != null)
                Positioned(
                  left: AppSpacing.md,
                  bottom: AppSpacing.xl3,
                  child: Material(
                    color: AppColors.bgCard,
                    borderRadius: AppRadius.md,
                    elevation: 2,
                    child: IconButton(
                      tooltip: AddressPickerStrings.showBothStops,
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      onPressed: () => controller.showPickupContext(
                        pickupSelection!.position,
                      ),
                      icon: const Icon(
                        Icons.zoom_out_map_rounded,
                        color: AppColors.info,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        AddressDetailForm(
          saveRequired: saveRequired,
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
