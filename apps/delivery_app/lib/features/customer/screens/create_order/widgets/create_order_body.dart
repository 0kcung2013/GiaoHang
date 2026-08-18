import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:giaohang_design/giaohang_design.dart';
import 'create_order_form_sections.dart';
import 'demo_autofill_button.dart';
import 'order_finance_details_section.dart';
import 'sender_contact_section.dart';

class CreateOrderBody extends StatelessWidget {
  const CreateOrderBody({
    super.key,
    required this.formKey,
    required this.recipientNameController,
    required this.recipientPhoneController,
    required this.noteController,
    required this.itemNameController,
    required this.itemDescriptionController,
    required this.itemCategory,
    required this.cargoImage,
    required this.requiredText,
    required this.validatePhone,
    required this.onCategoryChanged,
    required this.onPickCamera,
    required this.onPickGallery,
    required this.onRemoveImage,
    required this.onAutofillDemo,
    required this.codCollectionController,
    this.trafficDemoRouteCard,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController recipientNameController;
  final TextEditingController recipientPhoneController;
  final TextEditingController noteController;
  final TextEditingController itemNameController;
  final TextEditingController itemDescriptionController;
  final String itemCategory;
  final XFile? cargoImage;
  final String? Function(String?) Function(String message) requiredText;
  final String? Function(String?) validatePhone;
  final ValueChanged<String> onCategoryChanged;
  final VoidCallback onPickCamera;
  final VoidCallback onPickGallery;
  final VoidCallback onRemoveImage;
  final VoidCallback onAutofillDemo;
  final TextEditingController codCollectionController;
  final Widget? trafficDemoRouteCard;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = _CreateOrderLayout.fromWidth(constraints.maxWidth);

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: layout.maxContentWidth),
            child: Form(
              key: formKey,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  layout.horizontalPadding,
                  AppSpacing.md,
                  layout.horizontalPadding,
                  AppSpacing.xl2,
                ),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  DemoAutofillButton(onPressed: onAutofillDemo),
                  const SizedBox(height: AppSpacing.lg),
                  if (trafficDemoRouteCard != null) ...[
                    trafficDemoRouteCard!,
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  CreateOrderRecipientSection(
                    recipientNameController: recipientNameController,
                    recipientPhoneController: recipientPhoneController,
                    noteController: noteController,
                    requiredText: requiredText,
                    validatePhone: validatePhone,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  CreateOrderCargoSection(
                    itemNameController: itemNameController,
                    itemDescriptionController: itemDescriptionController,
                    itemCategory: itemCategory,
                    requiredText: requiredText,
                    onCategoryChanged: onCategoryChanged,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  OrderFinanceDetailsSection(
                    codCollectionController: codCollectionController,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  CreateOrderPhotosSection(
                    image: cargoImage,
                    onPickCamera: onPickCamera,
                    onPickGallery: onPickGallery,
                    onRemove: onRemoveImage,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const SenderContactSection(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CreateOrderLayout {
  const _CreateOrderLayout({
    required this.horizontalPadding,
    required this.maxContentWidth,
  });

  final double horizontalPadding;
  final double maxContentWidth;

  factory _CreateOrderLayout.fromWidth(double width) {
    if (width >= 1024) {
      return const _CreateOrderLayout(
        horizontalPadding: AppSpacing.xl3,
        maxContentWidth: 760,
      );
    }
    if (width >= 600) {
      return const _CreateOrderLayout(
        horizontalPadding: AppSpacing.xl3,
        maxContentWidth: 720,
      );
    }
    return const _CreateOrderLayout(
      horizontalPadding: AppSpacing.screenH,
      maxContentWidth: double.infinity,
    );
  }
}
