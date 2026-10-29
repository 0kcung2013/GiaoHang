import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/models/recent_address_model.dart';
import '../../../../core/models/saved_address_model.dart';
import '../../../../core/providers/address_providers.dart';
import '../../../../core/services/saved_address_service.dart';
import '../create_order/address_picker_strings.dart';
import '../create_order/widgets/address_picker/address_picker_dialogs.dart';
import '../create_order/widgets/address_picker/saved_addresses_tab.dart';
import '../create_order/widgets/map_picker_sheet.dart';
import 'constants/customer_account_strings.dart';
import 'providers/customer_account_providers.dart';
import 'widgets/account_components.dart';

class CustomerAddressesScreen extends ConsumerStatefulWidget {
  const CustomerAddressesScreen({super.key});
  @override
  ConsumerState<CustomerAddressesScreen> createState() =>
      _CustomerAddressesScreenState();
}

class _CustomerAddressesScreenState
    extends ConsumerState<CustomerAddressesScreen> {
  String? _busyId;

  Future<void> _edit([SavedAddressModel? address]) async {
    await showModalBottomSheet<MapPickerResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.bgCard,
      builder: (_) => MapPickerSheet(
        initialPosition: address == null
            ? const LatLng(10.7769, 106.7009)
            : LatLng(address.latitude, address.longitude),
        addressType: RecentAddressType.pickup,
        saveOnly: true,
        savedAddressToEdit: address,
      ),
    );
  }

  Future<void> _action(
    SavedAddressModel address,
    SavedAddressAction action,
  ) async {
    if (_busyId != null) return;
    if (action == SavedAddressAction.edit) {
      await _edit(address);
      return;
    }
    final userId = ref.read(customerAccountUserIdProvider);
    if (userId == null) return;
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
    setState(() => _busyId = address.id);
    try {
      final service = ref.read(savedAddressServiceProvider);
      if (action == SavedAddressAction.setDefault) {
        await service.setDefault(address.id, userId);
      } else {
        await service.deleteSavedAddress(address.id, userId);
      }
      ref.invalidate(savedAddressesProvider(userId));
    } on AddressBookException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(customerAccountUserIdProvider);
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: Text(
          CustomerAccountStrings.addresses,
          style: AppTextStyles.headingMedium,
        ),
        backgroundColor: AppColors.bgCard,
        surfaceTintColor: AppColors.bgCard,
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: userId == null
                ? const CustomerAccountState(
                    message: CustomerAccountStrings.signIn,
                  )
                : SavedAddressesTab(
                    userId: userId,
                    busyAddressId: _busyId,
                    onSelect: (address) => _edit(address),
                    onAdd: _edit,
                    onAction: _action,
                  ),
          ),
        ),
      ),
    );
  }
}
