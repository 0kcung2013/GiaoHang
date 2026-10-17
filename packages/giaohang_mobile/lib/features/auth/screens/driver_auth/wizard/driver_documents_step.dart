import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import '../driver_auth_strings.dart';
import '../widgets/driver_auth_field.dart';
import '../widgets/driver_auth_feedback.dart';
import '../widgets/driver_document_picker.dart';
import 'driver_register_data.dart';
import 'driver_register_validation.dart';

class DriverDocumentsStep extends StatelessWidget {
  const DriverDocumentsStep({
    super.key,
    required this.data,
    required this.onPick,
    this.issue,
  });
  final DriverRegisterData data;
  final ValueChanged<String> onPick;
  final DriverRegisterIssue? issue;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const DriverAuthNotice(message: DriverAuthStrings.privateDocuments),
      const SizedBox(height: AppSpacing.xl2),
      DriverAuthField(
        label: DriverAuthStrings.idNumber,
        hint: DriverAuthStrings.idNumberHint,
        initialValue: data.idCardNumber,
        keyboardType: TextInputType.number,
        error: issue?.forField(DriverRegisterField.idNumber),
        onChanged: (v) => data.idCardNumber = v,
      ),
      const SizedBox(height: AppSpacing.lg),
      LayoutBuilder(
        builder: (context, constraints) {
          final front = DriverDocumentPicker(
            label: DriverAuthStrings.idFront,
            icon: Icons.badge_rounded,
            file: data.idCardFrontFile,
            onTap: () => onPick('id_front'),
            error: issue?.forField(DriverRegisterField.idFront),
          );
          final back = DriverDocumentPicker(
            label: DriverAuthStrings.idBack,
            icon: Icons.badge_rounded,
            file: data.idCardBackFile,
            onTap: () => onPick('id_back'),
            error: issue?.forField(DriverRegisterField.idBack),
          );
          if (constraints.maxWidth < 400 ||
              MediaQuery.textScalerOf(context).scale(14) > 18) {
            return Column(
              children: [
                front,
                const SizedBox(height: AppSpacing.lg),
                back,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: front),
              const SizedBox(width: AppSpacing.lg),
              Expanded(child: back),
            ],
          );
        },
      ),
      const SizedBox(height: AppSpacing.xl2),
      DriverAuthField(
        label: DriverAuthStrings.licenseNumber,
        hint: DriverAuthStrings.licenseNumberHint,
        initialValue: data.driverLicenseNumber,
        textInputAction: TextInputAction.done,
        error: issue?.forField(DriverRegisterField.licenseNumber),
        onChanged: (v) => data.driverLicenseNumber = v,
      ),
      const SizedBox(height: AppSpacing.lg),
      DriverDocumentPicker(
        label: DriverAuthStrings.licensePhoto,
        icon: Icons.credit_card_rounded,
        file: data.driverLicenseFile,
        onTap: () => onPick('license'),
        error: issue?.forField(DriverRegisterField.licensePhoto),
      ),
      const SizedBox(height: AppSpacing.lg),
      DriverDocumentPicker(
        label: DriverAuthStrings.vehiclePhoto,
        hint: DriverAuthStrings.vehiclePhotoHint,
        icon: Icons.two_wheeler_rounded,
        file: data.vehiclePhotoFile,
        onTap: () => onPick('vehicle'),
        error: issue?.forField(DriverRegisterField.vehiclePhoto),
      ),
    ],
  );
}
