import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../core/constants/app_theme.dart';
import 'cargo_image_picker.dart';
import 'create_order_inputs.dart';
import 'create_order_options.dart';

class CreateOrderAddressSection extends StatelessWidget {
  const CreateOrderAddressSection({
    super.key,
    required this.pickupAddressController,
    required this.deliveryAddressController,
    required this.requiredAddress,
    required this.onPickPickup,
    required this.onPickDelivery,
    this.hasPickupPin = false,
    this.hasDeliveryPin = false,
  });

  final TextEditingController pickupAddressController;
  final TextEditingController deliveryAddressController;
  final String? Function(String?) Function(String message) requiredAddress;
  final VoidCallback onPickPickup;
  final VoidCallback onPickDelivery;
  final bool hasPickupPin;
  final bool hasDeliveryPin;

  @override
  Widget build(BuildContext context) {
    return CreateOrderSection(
      icon: Icons.add_location_alt_rounded,
      iconColor: AppColors.info,
      title: 'Thông tin địa chỉ',
      children: [
        Text(
          'Bắt buộc ghim điểm trên bản đồ (nút map) để tính phí & tìm tài xế.',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
            height: 1.35,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: CreateOrderTextField(
                controller: pickupAddressController,
                label: 'Địa chỉ lấy hàng',
                hint: 'Nhập địa chỉ hoặc chọn trên bản đồ',
                icon: Icons.my_location_rounded,
                textInputAction: TextInputAction.next,
                validator: requiredAddress('Vui lòng nhập địa chỉ lấy hàng.'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _MapPinButton(
              onTap: onPickPickup,
              color: AppColors.accent,
              pinned: hasPickupPin,
            ),
          ],
        ),
        if (hasPickupPin)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              'Đã ghim điểm lấy trên bản đồ',
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.success),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: CreateOrderTextField(
                controller: deliveryAddressController,
                label: 'Địa chỉ giao hàng',
                hint: 'Nhập địa chỉ hoặc chọn trên bản đồ',
                icon: Icons.location_on_rounded,
                textInputAction: TextInputAction.next,
                validator: requiredAddress('Vui lòng nhập địa chỉ giao hàng.'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _MapPinButton(
              onTap: onPickDelivery,
              color: AppColors.markerDrop,
              pinned: hasDeliveryPin,
            ),
          ],
        ),
        if (hasDeliveryPin)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              'Đã ghim điểm giao trên bản đồ',
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.success),
            ),
          ),
      ],
    );
  }
}

class _MapPinButton extends StatelessWidget {
  const _MapPinButton({
    required this.onTap,
    required this.color,
    required this.pinned,
  });

  final VoidCallback onTap;
  final Color color;
  final bool pinned;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: AppRadius.sm,
      child: InkWell(
        borderRadius: AppRadius.sm,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Icon(
            pinned ? Icons.check_circle_rounded : Icons.map_rounded,
            color: color,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class CreateOrderRecipientSection extends StatelessWidget {
  const CreateOrderRecipientSection({
    super.key,
    required this.recipientNameController,
    required this.recipientPhoneController,
    required this.noteController,
    required this.requiredText,
    required this.validatePhone,
  });

  final TextEditingController recipientNameController;
  final TextEditingController recipientPhoneController;
  final TextEditingController noteController;
  final String? Function(String?) Function(String message) requiredText;
  final String? Function(String?) validatePhone;

  @override
  Widget build(BuildContext context) {
    return CreateOrderSection(
      icon: Icons.person_rounded,
      iconColor: AppColors.success,
      title: 'Người nhận',
      children: [
        CreateOrderTextField(
          controller: recipientNameController,
          label: 'Tên người nhận',
          hint: 'Nhập họ tên người nhận',
          icon: Icons.badge_rounded,
          textInputAction: TextInputAction.next,
          validator: requiredText('Vui lòng nhập tên người nhận.'),
        ),
        const SizedBox(height: AppSpacing.md),
        CreateOrderTextField(
          controller: recipientPhoneController,
          label: 'Số điện thoại',
          hint: 'Nhập số điện thoại người nhận',
          icon: Icons.phone_rounded,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          validator: validatePhone,
        ),
        const SizedBox(height: AppSpacing.md),
        CreateOrderTextField(
          controller: noteController,
          label: 'Ghi chú giao hàng',
          hint: 'Ví dụ: gọi trước khi giao, để tại lễ tân',
          icon: Icons.sticky_note_2_rounded,
          maxLines: 3,
          textInputAction: TextInputAction.done,
        ),
      ],
    );
  }
}

class CreateOrderCargoSection extends StatelessWidget {
  const CreateOrderCargoSection({
    super.key,
    required this.itemNameController,
    required this.itemDescriptionController,
    required this.itemCategory,
    required this.image,
    required this.requiredText,
    required this.onCategoryChanged,
    required this.onPickImage,
    required this.onRemoveImage,
  });

  final TextEditingController itemNameController;
  final TextEditingController itemDescriptionController;
  final String itemCategory;
  final XFile? image;
  final String? Function(String?) Function(String message) requiredText;
  final ValueChanged<String> onCategoryChanged;
  final VoidCallback onPickImage;
  final VoidCallback onRemoveImage;

  @override
  Widget build(BuildContext context) {
    return CreateOrderSection(
      icon: Icons.inventory_2_rounded,
      iconColor: AppColors.accent,
      title: 'Thông tin hàng hoá',
      children: [
        CreateOrderTextField(
          controller: itemNameController,
          label: 'Tên hàng hoá',
          hint: 'Ví dụ: hồ sơ, bánh kem, quần áo',
          icon: Icons.inventory_2_outlined,
          textInputAction: TextInputAction.next,
          validator: requiredText('Vui lòng nhập tên hàng hoá.'),
        ),
        const SizedBox(height: AppSpacing.md),
        CargoCategorySelector(
          value: itemCategory,
          onChanged: onCategoryChanged,
        ),
        const SizedBox(height: AppSpacing.md),
        CreateOrderTextField(
          controller: itemDescriptionController,
          label: 'Mô tả hàng hoá',
          hint: 'Kích thước, lưu ý bảo quản hoặc thông tin cần biết',
          icon: Icons.notes_rounded,
          maxLines: 3,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.md),
        CargoImagePicker(
          image: image,
          onPick: onPickImage,
          onRemove: onRemoveImage,
        ),
      ],
    );
  }
}

class CreateOrderServiceSection extends StatelessWidget {
  const CreateOrderServiceSection({
    super.key,
    required this.serviceType,
    required this.onChanged,
  });

  final String serviceType;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return CreateOrderSection(
      icon: Icons.local_shipping_rounded,
      iconColor: AppColors.accent,
      title: 'Dịch vụ',
      children: [ServiceTypeSelector(value: serviceType, onChanged: onChanged)],
    );
  }
}

class CreateOrderPaymentSection extends StatelessWidget {
  const CreateOrderPaymentSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const CreateOrderSection(
      icon: Icons.payments_rounded,
      iconColor: AppColors.warning,
      title: 'Thanh toán',
      children: [PaymentMethodSelector()],
    );
  }
}

