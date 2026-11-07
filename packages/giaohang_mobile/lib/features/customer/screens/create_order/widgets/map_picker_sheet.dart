import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
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
import 'address_picker/pickup_reference_card.dart';
import 'address_picker/recent_addresses_tab.dart';
import 'address_picker/saved_addresses_tab.dart';

export '../models/address_picker_result.dart';

class MapPickerSheet extends ConsumerStatefulWidget {
  const MapPickerSheet({
    super.key,
    required this.initialPosition,
    required this.addressType,
    this.initialSelection,
    this.saveOnly = false,
    this.savedAddressToEdit,
    this.pickupSelection,
    this.tileProvider,
  });

  final LatLng initialPosition;
  final RecentAddressType addressType;
  final MapPickerResult? initialSelection;
  final bool saveOnly;
  final SavedAddressModel? savedAddressToEdit;
  final MapPickerResult? pickupSelection;
  final TileProvider? tileProvider;

  String get title => saveOnly
      ? AddressPickerStrings.addressBookTitle
      : addressType == RecentAddressType.pickup
      ? AddressPickerStrings.pickupTitle
      : AddressPickerStrings.deliveryTitle;

  String get confirmLabel => saveOnly
      ? AddressPickerStrings.saveAddress
      : addressType == RecentAddressType.pickup
      ? AddressPickerStrings.confirmPickup
      : AddressPickerStrings.confirmDelivery;

  @override
  ConsumerState<MapPickerSheet> createState() => _MapPickerSheetState();
}

class _MapPickerSheetState extends ConsumerState<MapPickerSheet> {
  late final AddressPickerController _controller;
  String? _busyAddressId;
  bool _isClearingHistory = false;
  final _mapKey = GlobalKey();

  String? get _userId => ref.read(currentAddressUserIdProvider);
  MapPickerResult? get _pickupReference =>
      !widget.saveOnly && widget.addressType == RecentAddressType.delivery
      ? widget.pickupSelection
      : null;

  @override
  void initState() {
    super.initState();
    final editing = widget.savedAddressToEdit;
    _controller = AddressPickerController(
      initialPosition: widget.initialPosition,
      pickupReferencePosition: _pickupReference?.position,
      initialSelection:
          widget.initialSelection ??
          (editing == null
              ? null
              : MapPickerResult(
                  position: widget.initialPosition,
                  formattedAddress: editing.formattedAddress,
                  addressDetail: editing.addressDetail,
                  deliveryNote: editing.deliveryNote,
                )),
    );
    if (widget.saveOnly) {
      if (editing != null) {
        _controller.selectSavedAddress(editing, forEditing: true);
      } else {
        _controller.prepareNewSavedAddress();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
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
                      compact: keyboardInset > 0,
                      onClose: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: CustomScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        slivers: [
                          SliverToBoxAdapter(
                            child: Column(
                              children: [
                                if (_pickupReference != null &&
                                    keyboardInset == 0)
                                  PickupReferenceCard(
                                    pickup: _pickupReference!,
                                    onShowBoth: _showBothStops,
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
                                    onSelect: (result) {
                                      _controller.selectSearchResult(result);
                                      if (_pickupReference != null) {
                                        _showBothStops();
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                if (!widget.saveOnly && keyboardInset == 0)
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
                              ],
                            ),
                          ),
                          if (_controller.activeTab == AddressPickerTab.map)
                            SliverToBoxAdapter(child: _buildActiveTab())
                          else
                            SliverFillRemaining(child: _buildActiveTab()),
                        ],
                      ),
                    ),
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
        return MapAddressTab(
          key: _mapKey,
          shrinkWrap: true,
          controller: _controller,
          onLocate: _locateMe,
          saveRequired: widget.saveOnly,
          pickupSelection: _pickupReference,
          isPickup: widget.addressType == RecentAddressType.pickup,
          tileProvider: widget.tileProvider,
        );
      case AddressPickerTab.saved:
        final userId = _userId;
        if (userId == null) {
          return AddressErrorState(onRetry: () {});
        }
        return SavedAddressesTab(
          userId: userId,
          busyAddressId: _busyAddressId,
          onSelect: (address) {
            _controller.selectSavedAddress(address, forEditing: false);
            if (_pickupReference != null) _showBothStops();
          },
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
          onSelect: (address) {
            _controller.selectRecentAddress(address, saveAfterReview: false);
            if (_pickupReference != null) _showBothStops();
          },
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

  void _showBothStops() {
    final pickup = _pickupReference;
    if (pickup == null) return;
    _controller.selectTab(AddressPickerTab.map);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.showPickupContext(pickup.position);
      final mapContext = _mapKey.currentContext;
      if (mapContext != null) {
        Scrollable.ensureVisible(
          mapContext,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : AppDuration.fast,
        );
      }
    });
  }

  Future<void> _confirmLocation() async {
    if (widget.saveOnly && !_controller.saveAddress) {
      _controller.setSaveAddress(true);
    }
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
  const _AddressPickerHeader({
    required this.title,
    required this.onClose,
    this.compact = false,
  });

  final String title;
  final VoidCallback onClose;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenH,
        compact ? AppSpacing.xs : AppSpacing.md,
        AppSpacing.md,
        compact ? AppSpacing.xs : AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: compact ? 1 : null,
              overflow: compact ? TextOverflow.ellipsis : null,
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
