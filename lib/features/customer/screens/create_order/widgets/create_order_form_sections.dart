import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../core/constants/app_theme.dart';
import '../utils/vietnam_phone_input.dart';
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
      icon: Icons.route_rounded,
      title: 'Lộ trình giao hàng',
      accentColor: AppColors.info,
      subtitle: hasPickupPin && hasDeliveryPin
          ? 'Đã sẵn sàng để xem phí giao hàng'
          : 'Chọn điểm lấy và điểm giao trên bản đồ',
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.035),
            borderRadius: AppRadius.xl2,
            border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
          ),
          child: Column(
            children: [
              _RouteStop(
                controller: pickupAddressController,
                label: 'Lấy hàng',
                hint: 'Chọn điểm lấy hàng',
                icon: Icons.radio_button_checked_rounded,
                color: AppColors.markerPickup,
                selected: hasPickupPin,
                onTap: onPickPickup,
                validator: requiredAddress('Vui lòng chọn điểm lấy hàng.'),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 35),
                child: Divider(height: 1, color: AppColors.border),
              ),
              _RouteStop(
                controller: deliveryAddressController,
                label: 'Giao đến',
                hint: 'Chọn điểm giao hàng',
                icon: Icons.location_on_rounded,
                color: AppColors.markerDrop,
                selected: hasDeliveryPin,
                onTap: onPickDelivery,
                validator: requiredAddress('Vui lòng chọn điểm giao hàng.'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RouteStop extends StatelessWidget {
  const _RouteStop({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
    required this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label, ${selected ? 'đã chọn' : 'chưa chọn'}',
      child: TextFormField(
        controller: controller,
        readOnly: true,
        onTap: onTap,
        validator: validator,
        style: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          prefixIcon: Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.lg,
              right: AppSpacing.md,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 52,
            minHeight: 56,
          ),
          labelText: label,
          labelStyle: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
          hintText: hint,
          hintStyle: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textMuted,
          ),
          suffixIcon: Icon(
            selected ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
            color: selected ? AppColors.success : AppColors.textMuted,
          ),
          filled: true,
          fillColor: selected
              ? color.withValues(alpha: 0.035)
              : Colors.transparent,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          errorStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
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
      icon: Icons.person_outline_rounded,
      title: 'Người nhận',
      accentColor: AppColors.primary,
      subtitle: 'Tài xế sẽ dùng thông tin này khi giao hàng',
      children: [
        CreateOrderTextField(
          controller: recipientNameController,
          label: 'Họ và tên',
          hint: 'Nhập tên người nhận',
          icon: Icons.person_outline_rounded,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
          validator: requiredText('Vui lòng nhập tên người nhận.'),
        ),
        const SizedBox(height: AppSpacing.lg),
        CreateOrderTextField(
          controller: recipientPhoneController,
          label: 'Số điện thoại',
          hint: 'Nhập số điện thoại',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.telephoneNumber],
          inputFormatters: const [VietnamPhoneInputFormatter()],
          maxLength: vietnamPhoneMaxLength,
          validator: validatePhone,
        ),
        const SizedBox(height: AppSpacing.lg),
        CreateOrderTextField(
          controller: noteController,
          label: 'Ghi chú cho tài xế (tuỳ chọn)',
          hint: 'Ví dụ: gọi trước khi giao',
          icon: Icons.notes_rounded,
          maxLines: 2,
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
    required this.requiredText,
    required this.onCategoryChanged,
  });

  final TextEditingController itemNameController;
  final TextEditingController itemDescriptionController;
  final String itemCategory;
  final String? Function(String?) Function(String message) requiredText;
  final ValueChanged<String> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    return CreateOrderSection(
      icon: Icons.inventory_2_outlined,
      title: 'Thông tin kiện hàng',
      accentColor: AppColors.accent,
      subtitle: 'Mô tả rõ để tài xế xử lý phù hợp',
      children: [
        CreateOrderTextField(
          controller: itemNameController,
          label: 'Tên kiện hàng',
          hint: 'Ví dụ: hồ sơ, bánh kem, quần áo',
          icon: Icons.inventory_2_outlined,
          textInputAction: TextInputAction.next,
          validator: requiredText('Vui lòng nhập tên hàng hoá.'),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Danh mục',
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        CargoCategorySelector(
          value: itemCategory,
          onChanged: onCategoryChanged,
        ),
        const SizedBox(height: AppSpacing.lg),
        CreateOrderTextField(
          controller: itemDescriptionController,
          label: 'Mô tả (tuỳ chọn)',
          hint: 'Kích thước, lưu ý bảo quản hoặc thông tin cần biết',
          icon: Icons.subject_rounded,
          maxLines: 3,
          textInputAction: TextInputAction.next,
        ),
      ],
    );
  }
}

class CreateOrderPhotosSection extends StatelessWidget {
  const CreateOrderPhotosSection({
    super.key,
    required this.image,
    required this.onPickCamera,
    required this.onPickGallery,
    required this.onRemove,
  });

  final XFile? image;
  final VoidCallback onPickCamera;
  final VoidCallback onPickGallery;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return CreateOrderSection(
      icon: Icons.photo_camera_outlined,
      title: 'Ảnh kiện hàng',
      accentColor: AppColors.accent,
      subtitle: 'Không bắt buộc, giúp tài xế nhận diện kiện hàng',
      children: [
        CargoImagePicker(
          image: image,
          onPickCamera: onPickCamera,
          onPickGallery: onPickGallery,
          onRemove: onRemove,
        ),
      ],
    );
  }
}
