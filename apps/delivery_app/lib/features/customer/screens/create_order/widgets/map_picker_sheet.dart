import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:giaohang_design/giaohang_design.dart';

import '../../../../../core/models/recent_address_model.dart';
import '../../../../../core/models/saved_address_model.dart';
import '../../../../../core/providers/address_providers.dart';
import '../../../../../core/services/saved_address_service.dart';
import '../address_picker_strings.dart';
import '../controllers/address_picker_controller.dart';
import '../models/address_picker_result.dart';
import 'address_picker/address_picker_confirm_bar.dart';
import 'address_picker/address_picker_dialogs.dart';
import 'address_picker/address_picker_search_panel.dart';
import 'address_picker/address_picker_states.dart';
import 'address_picker/address_picker_tabs.dart';
import 'address_picker/map_address_tab.dart';
import 'address_picker/recent_addresses_tab.dart';
import 'address_picker/saved_addresses_tab.dart';

export '../models/address_picker_result.dart';

class MapPickerSheet extends ConsumerStatefulWidget {
  const MapPickerSheet({
    super.key,
    required this.initialPosition,
    required this.addressType,
    this.initialSelection,
  });

  final LatLng initialPosition;
  final RecentAddressType addressType;
  final MapPickerResult? initialSelection;

  String get title => addressType == RecentAddressType.pickup
      ? AddressPickerStrings.pickupTitle
      : AddressPickerStrings.deliveryTitle;

  String get confirmLabel => addressType == RecentAddressType.pickup
      ? AddressPickerStrings.confirmPickup
      : AddressPickerStrings.confirmDelivery;

  @override
  ConsumerState<MapPickerSheet> createState() => _MapPickerSheetState();
}

class _MapPickerSheetState extends ConsumerState<MapPickerSheet> {
  late final AddressPickerController _controller;
  String? _busyAddressId;
  bool _isClearingHistory = false;

  String? get _userId => ref.read(currentAddressUserIdProvider);

  @override
  void initState() {
    super.initState();
    _controller = AddressPickerController(
      initialPosition: widget.initialPosition,
      initialSelection: widget.initialSelection,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: AppDuration.normal,
      curve: AppCurve.decelerate,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: FractionallySizedBox(
        heightFactor: 0.97,
        child: Material(
          color: AppColors.bgCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: ListenableBuilder(
              listenable: _controller,
              builder: (context, _) {
                return Column(
                  children: [
                    _AddressPickerHeader(
                      title: widget.title,
                      onClose: () => Navigator.pop(context),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenH,
                      ),
                      child: AddressPickerSearchPanel(
                        controller: _controller.searchController,
                        focusNode: _controller.searchFocusNode,
                        isSearching: _controller.isSearching,
                        results: _controller.searchResults,
                        error: _controller.searchError,
                        onChanged: _controller.onSearchChanged,
                        onSearch: _controller.search,
                        onClear: _controller.clearSearch,
                        onSelect: _controller.selectSearchResult,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenH,
                      ),
                      child: AddressPickerTabs(
                        value: _controller.activeTab,
                        onChanged: _controller.selectTab,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Expanded(child: _buildActiveTab()),
                    if (_controller.activeTab == AddressPickerTab.map)
                      AddressPickerConfirmBar(
                        label: widget.confirmLabel,
                        isBusy: _controller.isSaving,
                        onPressed:
                            _controller.isResolving || _controller.isSaving
                            ? null
                            : _confirmLocation,
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTab() {
    switch (_controller.activeTab) {
      case AddressPickerTab.map:
        return MapAddressTab(controller: _controller, onLocate: _locateMe);
      case AddressPickerTab.saved:
        final userId = _userId;
        if (userId == null) {
          return AddressErrorState(onRetry: () {});
        }
        return SavedAddressesTab(
          userId: userId,
          busyAddressId: _busyAddressId,
          onSelect: (address) =>
              _controller.selectSavedAddress(address, forEditing: false),
          onAdd: _controller.prepareNewSavedAddress,
          onAction: _handleSavedAction,
        );
      case AddressPickerTab.recent:
        final userId = _userId;
        if (userId == null) {
          return AddressErrorState(onRetry: () {});
        }
        return RecentAddressesTab(
          userId: userId,
          busyAddressId: _busyAddressId,
          isClearing: _isClearingHistory,
          onSelect: (address) =>
              _controller.selectRecentAddress(address, saveAfterReview: false),
          onSave: (address) =>
              _controller.selectRecentAddress(address, saveAfterReview: true),
          onDelete: _deleteRecentAddress,
          onClear: _clearRecentHistory,
        );
    }
  }

  Future<void> _locateMe() async {
    final error = await _controller.locateMe();
    if (error != null && mounted) _showMessage(error, isError: true);
  }

  Future<void> _confirmLocation() async {
    if (!_controller.validate()) return;
    final result = _controller.buildResult();
    if (!_controller.saveAddress) {
      Navigator.pop(context, result);
      return;
    }

    final userId = _userId;
    if (userId == null) {
      _controller.setSaveError(AddressPickerStrings.loginToSave);
      return;
    }

    _controller.setSaving(true);
    try {
      final service = ref.read(savedAddressServiceProvider);
      final draft = _controller.buildSavedAddress(userId);
      final duplicate = await service.findNearby(
        userId: userId,
        latitude: draft.latitude,
        longitude: draft.longitude,
        excludingId: _controller.editingAddress?.id,
      );
      if (!mounted) return;

      if (duplicate != null) {
        _controller.setSaving(false);
        final updateDuplicate = await showAddressConfirmationDialog(
          context: context,
          title: AddressPickerStrings.duplicateTitle,
          message: AddressPickerStrings.duplicateMessage,
          confirmLabel: AddressPickerStrings.update,
          cancelLabel: AddressPickerStrings.cancel,
        );
        if (!mounted) return;
        if (updateDuplicate) {
          _controller.setSaving(true);
          await service.updateSavedAddress(
            draft.copyWith(
              id: duplicate.id,
              isDefault: duplicate.isDefault,
              createdAt: duplicate.createdAt,
            ),
          );
          _showMessage(AddressPickerStrings.updatedSuccess);
        }
        ref.invalidate(savedAddressesProvider(userId));
        if (mounted) Navigator.pop(context, result);
        return;
      }

      if (_controller.editingAddress != null) {
        await service.updateSavedAddress(draft);
        _showMessage(AddressPickerStrings.updatedSuccess);
      } else {
        await service.createSavedAddress(draft);
        _showMessage(AddressPickerStrings.savedSuccess);
      }
      ref.invalidate(savedAddressesProvider(userId));
      if (mounted) Navigator.pop(context, result);
    } on AddressBookException catch (error) {
      _controller.setSaveError(error.message);
    } finally {
      if (mounted) _controller.setSaving(false);
    }
  }

  Future<void> _handleSavedAction(
    SavedAddressModel address,
    SavedAddressAction action,
  ) async {
    final userId = _userId;
    if (userId == null) return;
    if (action == SavedAddressAction.edit) {
      _controller.selectSavedAddress(address, forEditing: true);
      return;
    }

    if (action == SavedAddressAction.delete) {
      final confirmed = await showAddressConfirmationDialog(
        context: context,
        title: AddressPickerStrings.confirmDeleteTitle,
        message: AddressPickerStrings.confirmDeleteMessage,
        confirmLabel: AddressPickerStrings.delete,
        cancelLabel: AddressPickerStrings.cancel,
        destructive: true,
      );
      if (!confirmed || !mounted) return;
    }

    setState(() => _busyAddressId = address.id);
    try {
      final service = ref.read(savedAddressServiceProvider);
      if (action == SavedAddressAction.setDefault) {
        await service.setDefault(address.id, userId);
        _showMessage(AddressPickerStrings.defaultUpdatedSuccess);
      } else {
        await service.deleteSavedAddress(address.id, userId);
        _showMessage(AddressPickerStrings.deletedSuccess);
      }
      ref.invalidate(savedAddressesProvider(userId));
    } on AddressBookException catch (error) {
      _showMessage(error.message, isError: true);
    } finally {
      if (mounted) setState(() => _busyAddressId = null);
    }
  }

  Future<void> _deleteRecentAddress(RecentAddressModel address) async {
    final userId = _userId;
    if (userId == null) return;
    setState(() => _busyAddressId = address.id);
    try {
      await ref
          .read(recentAddressServiceProvider)
          .deleteRecentAddress(address.id, userId);
      ref.invalidate(recentAddressesProvider(userId));
      _showMessage(AddressPickerStrings.recentDeletedSuccess);
    } on AddressBookException catch (error) {
      _showMessage(error.message, isError: true);
    } finally {
      if (mounted) setState(() => _busyAddressId = null);
    }
  }

  Future<void> _clearRecentHistory() async {
    final userId = _userId;
    if (userId == null) return;
    final confirmed = await showAddressConfirmationDialog(
      context: context,
      title: AddressPickerStrings.confirmClearTitle,
      message: AddressPickerStrings.confirmClearMessage,
      confirmLabel: AddressPickerStrings.clearHistory,
      cancelLabel: AddressPickerStrings.cancel,
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isClearingHistory = true);
    try {
      await ref.read(recentAddressServiceProvider).clearHistory(userId);
      ref.invalidate(recentAddressesProvider(userId));
      _showMessage(AddressPickerStrings.historyClearedSuccess);
    } on AddressBookException catch (error) {
      _showMessage(error.message, isError: true);
    } finally {
      if (mounted) setState(() => _isClearingHistory = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textOnAccent,
          ),
        ),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(AppSpacing.lg),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
      ),
    );
  }
}

class _AddressPickerHeader extends StatelessWidget {
  const _AddressPickerHeader({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.headingMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            tooltip: AddressPickerStrings.close,
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}
