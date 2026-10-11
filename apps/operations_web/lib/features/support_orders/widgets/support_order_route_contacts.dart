import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../utils/support_order_information_strings.dart';
import 'support_order_information_components.dart';

class SupportOrderRouteContacts extends StatelessWidget {
  const SupportOrderRouteContacts({
    required this.order,
    this.onContactCustomer,
    this.onContactDriver,
    super.key,
  });
  final RiskOrderSummary order;
  final VoidCallback? onContactCustomer;
  final VoidCallback? onContactDriver;

  @override
  Widget build(BuildContext context) => SupportOrderInfoSection(
    title: SupportOrderInformationStrings.route,
    icon: Icons.route_rounded,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Stop(
          label: SupportOrderInformationStrings.pickup,
          address: order.pickupAddress,
          lat: order.pickupLat,
          lng: order.pickupLng,
          color: AppColors.markerPickup,
          contact: _Contact(
            label: SupportOrderInformationStrings.sender,
            contact: order.customer,
            onContact: onContactCustomer,
            contactLabel: SupportOrderInformationStrings.contactCustomer,
          ),
        ),
        const Divider(height: AppSpacing.xl3, color: AppColors.border),
        _Stop(
          label: SupportOrderInformationStrings.delivery,
          address: order.deliveryAddress,
          lat: order.deliveryLat,
          lng: order.deliveryLng,
          color: AppColors.markerDrop,
          contact: _Contact(
            label: SupportOrderInformationStrings.recipient,
            contact: RiskContact(
              name: order.recipientName,
              phone: order.recipientPhone,
            ),
          ),
        ),
        const Divider(height: AppSpacing.xl3, color: AppColors.border),
        _Contact(
          label: SupportOrderInformationStrings.driver,
          contact: order.driver,
          emptyLabel: order.driverId == null
              ? SupportOrderInformationStrings.noDriver
              : SupportOrderInformationStrings.noContact,
          onContact: onContactDriver,
          contactLabel: SupportOrderInformationStrings.contactDriver,
        ),
      ],
    ),
  );
}

class _Stop extends StatelessWidget {
  const _Stop({
    required this.label,
    required this.address,
    required this.color,
    required this.contact,
    this.lat,
    this.lng,
  });
  final String label;
  final String address;
  final Color color;
  final Widget contact;
  final double? lat;
  final double? lng;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.location_on_rounded, color: color, size: 24),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: SupportOrderInfoFact(label: label, value: address),
          ),
        ],
      ),
      if (lat != null && lng != null) ...[
        const SizedBox(height: AppSpacing.sm),
        SelectableText(
          '${SupportOrderInformationStrings.coordinate}: ${lat!.toStringAsFixed(6)}, ${lng!.toStringAsFixed(6)}',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
      const SizedBox(height: AppSpacing.lg),
      contact,
    ],
  );
}

class _Contact extends StatelessWidget {
  const _Contact({
    required this.label,
    this.contact,
    this.onContact,
    this.contactLabel,
    this.emptyLabel = SupportOrderInformationStrings.noContact,
  });
  final String label;
  final RiskContact? contact;
  final VoidCallback? onContact;
  final String? contactLabel;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
      const SizedBox(height: AppSpacing.xs),
      SelectableText(
        contact?.name?.trim().isNotEmpty == true ? contact!.name! : emptyLabel,
        style: AppTextStyles.labelLarge,
      ),
      const SizedBox(height: AppSpacing.xs),
      Row(
        children: [
          Expanded(
            child: SelectableText(
              contact?.phone?.trim().isNotEmpty == true
                  ? contact!.phone!
                  : SupportOrderInformationStrings.noPhone,
              style: AppTextStyles.bodyMedium,
            ),
          ),
          if (contact?.phone?.trim().isNotEmpty == true)
            IconButton(
              tooltip: '${SupportOrderInformationStrings.copyPhone} · $label',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: contact!.phone!));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(SupportOrderInformationStrings.copiedPhone),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
            ),
        ],
      ),
      if (contact?.email?.trim().isNotEmpty == true)
        SelectableText(
          contact!.email!,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      if (onContact != null)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onContact,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              minimumSize: const Size(48, 48),
              textStyle: AppTextStyles.labelMedium,
            ),
            icon: const Icon(Icons.forum_rounded, size: 20),
            label: Text(contactLabel!),
          ),
        ),
    ],
  );
}
