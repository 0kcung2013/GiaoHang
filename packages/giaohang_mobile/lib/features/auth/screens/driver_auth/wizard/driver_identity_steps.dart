import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import '../driver_auth_strings.dart';
import '../widgets/driver_auth_field.dart';
import '../widgets/driver_document_picker.dart';
import 'driver_register_data.dart';
import 'driver_register_validation.dart';

class DriverAccountStep extends StatelessWidget {
  const DriverAccountStep({
    super.key,
    required this.data,
    this.issue,
    required this.onNext,
  });
  final DriverRegisterData data;
  final DriverRegisterIssue? issue;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => AutofillGroup(
    child: Column(
      children: [
        DriverAuthField(
          label: DriverAuthStrings.email,
          hint: DriverAuthStrings.emailHint,
          initialValue: data.email,
          icon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.newUsername, AutofillHints.email],
          error: issue?.forField(DriverRegisterField.email),
          onChanged: (v) => data.email = v,
        ),
        const SizedBox(height: AppSpacing.lg),
        DriverAuthField(
          label: DriverAuthStrings.password,
          hint: DriverAuthStrings.passwordHint,
          helper: DriverAuthStrings.passwordHelp,
          initialValue: data.password,
          icon: Icons.lock_outline_rounded,
          password: true,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.done,
          error: issue?.forField(DriverRegisterField.password),
          onChanged: (v) => data.password = v,
          onSubmitted: (_) => onNext(),
        ),
      ],
    ),
  );
}

class DriverPersonalStep extends StatelessWidget {
  const DriverPersonalStep({
    super.key,
    required this.data,
    required this.onPickAvatar,
    this.issue,
  });
  final DriverRegisterData data;
  final VoidCallback onPickAvatar;
  final DriverRegisterIssue? issue;

  @override
  Widget build(BuildContext context) => AutofillGroup(
    child: Column(
      children: [
        DriverDocumentPicker(
          label: DriverAuthStrings.avatar,
          hint: DriverAuthStrings.avatarHint,
          portrait: true,
          icon: Icons.add_a_photo_rounded,
          file: data.avatarFile,
          onTap: onPickAvatar,
          error: issue?.forField(DriverRegisterField.avatar),
        ),
        const SizedBox(height: AppSpacing.xl2),
        DriverAuthField(
          label: DriverAuthStrings.fullName,
          hint: DriverAuthStrings.fullNameHint,
          initialValue: data.fullName,
          icon: Icons.person_outline_rounded,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.name],
          error: issue?.forField(DriverRegisterField.name),
          onChanged: (v) => data.fullName = v,
        ),
        const SizedBox(height: AppSpacing.lg),
        DriverAuthField(
          label: DriverAuthStrings.phone,
          hint: DriverAuthStrings.phoneHint,
          initialValue: data.phone,
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
          textInputAction: TextInputAction.done,
          error: issue?.forField(DriverRegisterField.phone),
          onChanged: (v) => data.phone = v,
        ),
      ],
    ),
  );
}
