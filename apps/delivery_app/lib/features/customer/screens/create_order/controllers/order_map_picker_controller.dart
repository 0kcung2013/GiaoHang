import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../../../core/models/recent_address_model.dart';
import '../widgets/map_picker_sheet.dart';

class OrderMapPickerController {
  const OrderMapPickerController();

  Future<OrderMapPickerOutcome> pick({
    required BuildContext context,
    required RecentAddressType addressType,
    required MapPickerResult? currentSelection,
    required Position? currentPosition,
    required Future<Position?> Function() locate,
  }) async {
    var position = currentPosition;
    var usedFallback = false;
    final LatLng initialPosition;

    if (currentSelection != null) {
      initialPosition = currentSelection.position;
    } else {
      position ??= await locate();
      if (position == null) {
        usedFallback = true;
        initialPosition = const LatLng(10.762622, 106.660172);
      } else {
        initialPosition = LatLng(position.latitude, position.longitude);
      }
    }

    if (!context.mounted) {
      return OrderMapPickerOutcome(
        selection: null,
        currentPosition: position,
        usedFallback: usedFallback,
      );
    }
    final selection = await showModalBottomSheet<MapPickerResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MapPickerSheet(
        initialPosition: initialPosition,
        addressType: addressType,
        initialSelection: currentSelection,
      ),
    );

    return OrderMapPickerOutcome(
      selection: selection,
      currentPosition: position,
      usedFallback: usedFallback,
    );
  }
}

class OrderMapPickerOutcome {
  const OrderMapPickerOutcome({
    required this.selection,
    required this.currentPosition,
    required this.usedFallback,
  });

  final MapPickerResult? selection;
  final Position? currentPosition;
  final bool usedFallback;
}
