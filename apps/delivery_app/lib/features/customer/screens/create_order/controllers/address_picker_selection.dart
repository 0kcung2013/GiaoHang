part of 'address_picker_controller.dart';

extension AddressPickerSelection on AddressPickerController {
  void selectSavedAddress(
    SavedAddressModel address, {
    required bool forEditing,
  }) {
    editingAddress = forEditing ? address : null;
    saveAddress = forEditing;
    labelType = address.labelType;
    customLabelController.text = address.customLabel ?? '';
    _applyKnownAddress(
      position: LatLng(address.latitude, address.longitude),
      formattedAddress: address.formattedAddress,
      addressDetail: address.addressDetail,
      deliveryNote: address.deliveryNote,
    );
    moveMapTo(_selectedPosition);
  }

  void selectRecentAddress(
    RecentAddressModel address, {
    required bool saveAfterReview,
  }) {
    editingAddress = null;
    saveAddress = saveAfterReview;
    labelType = SavedAddressLabelType.home;
    customLabelController.clear();
    _applyKnownAddress(
      position: LatLng(address.latitude, address.longitude),
      formattedAddress: address.formattedAddress,
      addressDetail: address.addressDetail,
      deliveryNote: address.deliveryNote,
    );
    moveMapTo(_selectedPosition);
  }

  void prepareNewSavedAddress() {
    editingAddress = null;
    saveAddress = true;
    labelType = SavedAddressLabelType.home;
    customLabelController.clear();
    customLabelError = null;
    saveError = null;
    activeTab = AddressPickerTab.map;
    _notify();
  }

  bool validate() {
    detailError = null;
    customLabelError = null;
    saveError = null;

    final positionValid =
        _selectedPosition.latitude.isFinite &&
        _selectedPosition.longitude.isFinite &&
        _selectedPosition.latitude >= -90 &&
        _selectedPosition.latitude <= 90 &&
        _selectedPosition.longitude >= -180 &&
        _selectedPosition.longitude <= 180;
    if (!positionValid) {
      resolutionError = AddressPickerStrings.invalidCoordinates;
    } else if (resolvedAddress == null ||
        resolvedAddress!.displayAddress.trim().length < 6) {
      resolutionError = AddressPickerStrings.addressRequired;
    }

    if (resolvedAddress != null &&
        !resolvedAddress!.hasHouseNumber &&
        detailController.text.trim().length < 3) {
      detailError = AddressPickerStrings.addressDetailRequired;
    }

    if (saveAddress &&
        labelType == SavedAddressLabelType.other &&
        customLabelController.text.trim().isEmpty) {
      customLabelError = AddressPickerStrings.customLabelRequired;
    }

    _notify();
    return positionValid &&
        resolvedAddress != null &&
        resolvedAddress!.displayAddress.trim().length >= 6 &&
        detailError == null &&
        customLabelError == null &&
        !isResolving;
  }

  MapPickerResult buildResult() {
    return MapPickerResult(
      position: _selectedPosition,
      formattedAddress: resolvedAddress!.displayAddress.trim(),
      addressDetail: detailController.text.trim(),
      deliveryNote: noteController.text.trim(),
    );
  }

  SavedAddressModel buildSavedAddress(String userId) {
    final existing = editingAddress;
    final now = DateTime.now().toUtc();
    return SavedAddressModel(
      id: existing?.id ?? '',
      userId: userId,
      labelType: labelType,
      customLabel: labelType == SavedAddressLabelType.other
          ? customLabelController.text.trim()
          : null,
      formattedAddress: resolvedAddress!.displayAddress.trim(),
      addressDetail: detailController.text.trim(),
      deliveryNote: noteController.text.trim(),
      latitude: _selectedPosition.latitude,
      longitude: _selectedPosition.longitude,
      isDefault: existing?.isDefault ?? false,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
  }

  void clearDetailError() {
    if (detailError == null) return;
    detailError = null;
    _notify();
  }

  void clearCustomLabelError() {
    if (customLabelError == null) return;
    customLabelError = null;
    _notify();
  }
}
