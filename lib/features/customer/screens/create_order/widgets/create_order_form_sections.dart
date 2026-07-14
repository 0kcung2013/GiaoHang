import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../core/constants/app_theme.dart';
import 'cargo_image_picker.dart';
import 'create_order_inputs.dart';
import 'create_order_options.dart';
import 'create_order_summary.dart';

class CreateOrderAddressSection extends StatelessWidget {
  const CreateOrderAddressSection({
    super.key,
    required this.pickupAddressController,
    required this.deliveryAddressController,
    required this.requiredAddress,
    required this.onPickPickup,
    required this.onPickDelivery,
  });

  final TextEditingController pickupAddressController;
  final TextEditingController deliveryAddressController;
  final String? Function(String?) Function(String message) requiredAddress;
  final VoidCallback onPickPickup;
  final VoidCallback onPickDelivery;

  @override
  Widget build(BuildContext context) {
    return CreateOrderSection(
      icon: Icons.add_location_alt_rounded,
      iconColor: AppColors.info,
      title: 'Thông tin địa chỉ',
      children: [
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
            Material(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: AppRadius.sm,
              child: InkWell(
                borderRadius: AppRadius.sm,
                onTap: onPickPickup,
                child: const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Icon(Icons.map_rounded, color: AppColors.accent, size: 20),
                ),
              ),
            ),
          ],
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
            Material(
              color: AppColors.markerDrop.withValues(alpha: 0.1),
              borderRadius: AppRadius.sm,
              child: InkWell(
                borderRadius: AppRadius.sm,
                onTap: onPickDelivery,
                child: const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Icon(Icons.map_rounded, color: AppColors.markerDrop, size: 20),
                ),
              ),
            ),
          ],
        ),
      ],
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

class CreateOrderConfirmationSection extends StatelessWidget {
  const CreateOrderConfirmationSection({
    super.key,
    required this.pickupAddress,
    required this.deliveryAddress,
    required this.recipientName,
    required this.recipientPhone,
    required this.serviceType,
    required this.paymentMethod,
    required this.note,
    required this.itemName,
    required this.itemCategory,
    required this.itemDescription,
    required this.itemImageName,
    required this.deliveryFee,
  });

  final String pickupAddress;
  final String deliveryAddress;
  final String recipientName;
  final String recipientPhone;
  final String serviceType;
  final String paymentMethod;
  final String note;
  final String itemName;
  final String itemCategory;
  final String itemDescription;
  final String? itemImageName;
  final double deliveryFee;

  @override
  Widget build(BuildContext context) {
    return CreateOrderSection(
      icon: Icons.fact_check_rounded,
      iconColor: AppColors.primary,
      title: 'Xác nhận đơn hàng',
      children: [
        OrderConfirmationSummary(
          pickupAddress: pickupAddress,
          deliveryAddress: deliveryAddress,
          recipientName: recipientName,
          recipientPhone: recipientPhone,
          serviceType: serviceType,
          paymentMethod: paymentMethod,
          note: note,
          itemName: itemName,
          itemCategory: itemCategory,
          itemDescription: itemDescription,
          itemImageName: itemImageName,
          deliveryFee: deliveryFee,
        ),
      ],
    );
  }
}
