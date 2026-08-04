import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:giaohang_design/giaohang_design.dart';
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
      step: '01',
      icon: Icons.route_rounded,
      title: 'Lộ trình giao hàng',
      accentColor: AppColors.accent,
      subtitle: hasPickupPin && hasDeliveryPin
          ? 'Đã sẵn sàng để xem phí giao hàng'
          : 'Chọn điểm lấy và điểm giao trên bản đồ',
      children: [
        _RouteStop(
          controller: pickupAddressController,
          label: 'Điểm lấy hàng',
          hint: 'Chọn vị trí lấy hàng trên bản đồ',
          icon: Icons.storefront_rounded,
          color: AppColors.markerPickup,
          selected: hasPickupPin,
          onTap: onPickPickup,
          validator: requiredAddress('Vui lòng chọn điểm lấy hàng.'),
        ),
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.xl),
          child: Row(
            children: [
              Container(
                width: 2,
                height: AppSpacing.xl,
                color: AppColors.accent.withValues(alpha: 0.2),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Divider(
                  height: 1,
                  color: AppColors.border.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
        ),
        _RouteStop(
          controller: deliveryAddressController,
          label: 'Điểm giao hàng',
          hint: 'Chọn vị trí giao hàng trên bản đồ',
          icon: Icons.location_on_rounded,
          color: AppColors.markerDrop,
          selected: hasDeliveryPin,
          onTap: onPickDelivery,
          validator: requiredAddress('Vui lòng chọn điểm giao hàng.'),
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
      child: AnimatedContainer(
        duration: AppDuration.fast,
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.045) : AppColors.bgLight,
          borderRadius: AppRadius.lg,
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.32) : AppColors.border,
          ),
        ),
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
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: AppRadius.md,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 60,
              minHeight: 62,
            ),
            labelText: label,
            labelStyle: AppTextStyles.labelSmall.copyWith(
              color: selected ? color : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
            hintText: hint,
            hintStyle: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textMuted,
            ),
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: AppColors.accentLight,
                  borderRadius: AppRadius.md,
                ),
                child: Icon(
                  selected ? Icons.check_rounded : Icons.map_outlined,
                  color: AppColors.accent,
                  size: 19,
                ),
              ),
            ),
            suffixIconConstraints: const BoxConstraints(
              minWidth: 50,
              minHeight: 56,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            errorBorder: const OutlineInputBorder(
              borderRadius: AppRadius.lg,
              borderSide: BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: const OutlineInputBorder(
              borderRadius: AppRadius.lg,
              borderSide: BorderSide(color: AppColors.error, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            errorStyle: AppTextStyles.bodySmall.copyWith(
              color: AppColors.error,
            ),
            errorMaxLines: 2,
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
      step: '02',
      icon: Icons.person_outline_rounded,
      title: 'Người nhận',
      accentColor: AppColors.accent,
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
          requiredField: true,
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
          requiredField: true,
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
      step: '03',
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
          requiredField: true,
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
      step: '04',
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
