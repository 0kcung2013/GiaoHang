import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:giaohang_design/giaohang_design.dart';
import '../utils/order_form_validators.dart';
import 'cargo_image_picker.dart';
import 'create_order_inputs.dart';
import 'create_order_options.dart';
import 'order_field_label.dart';

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
        OrderFieldLabel(
          'Danh mục',
          style: AppTextStyles.labelMedium.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        FormField<String>(
          initialValue: itemCategory,
          validator: (_) => validateOrderCategory(itemCategory),
          builder: (field) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CargoCategorySelector(
                value: itemCategory,
                onChanged: (value) {
                  field.didChange(value);
                  onCategoryChanged(value);
                },
              ),
              if (field.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    field.errorText!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ),
            ],
          ),
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
      requiredField: true,
      accentColor: AppColors.accent,
      children: [
        FormField<XFile>(
          key: ValueKey(image?.path),
          initialValue: image,
          validator: (_) =>
              image == null ? OrderFormValidationText.photoRequired : null,
          builder: (field) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CargoImagePicker(
                image: image,
                onPickCamera: onPickCamera,
                onPickGallery: onPickGallery,
                onRemove: onRemove,
              ),
              if (field.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    field.errorText!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
