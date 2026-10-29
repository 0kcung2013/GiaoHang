import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/models/user_model.dart';
import 'utils/customer_profile_validation.dart';
import 'constants/customer_account_strings.dart';
import 'providers/customer_account_providers.dart';
import 'widgets/account_components.dart';

class CustomerProfileScreen extends ConsumerStatefulWidget {
  const CustomerProfileScreen({super.key, required this.profile});
  final UserModel profile;
  @override
  ConsumerState<CustomerProfileScreen> createState() =>
      _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends ConsumerState<CustomerProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.profile.fullName);
  late final _phone = TextEditingController(text: widget.profile.phone);
  XFile? _image;
  Uint8List? _imageBytes;
  String? _uploadedAvatar;
  String? _error;
  bool _busy = false;
  bool _picking = false;
  bool _allowPop = false;

  bool get _dirty =>
      _name.text.trim() != widget.profile.fullName.trim() ||
      _phone.text.trim() != (widget.profile.phone ?? '').trim() ||
      _image != null;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    setState(() => _picking = true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (file == null) return;
      if (await file.length() > 5 * 1024 * 1024) {
        throw const FormatException(CustomerAccountStrings.avatarError);
      }
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _image = file;
        _imageBytes = bytes;
        _uploadedAvatar = null;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = CustomerAccountStrings.avatarPickError);
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _leave() async {
    if (_busy || _picking) return;
    if (!_dirty ||
        await confirmCustomerAccountAction(
          context,
          title: CustomerAccountStrings.leaveTitle,
          message: CustomerAccountStrings.leaveMessage,
          confirm: CustomerAccountStrings.leave,
        )) {
      if (!mounted) return;
      setState(() => _allowPop = true);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _save() async {
    if (_busy || _picking || !_dirty || !_formKey.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repository = ref.read(customerAccountRepositoryProvider);
      if (_image != null) {
        _uploadedAvatar ??= await repository.uploadAvatar(_image!);
      }
      await repository.save(
        userId: widget.profile.id,
        fullName: _name.text,
        phone: _phone.text,
        avatarUrl: _uploadedAvatar,
      );
      if (!mounted) return;
      refreshCustomerAccount(ref, widget.profile.id);
      setState(() {
        _allowPop = true;
        _busy = false;
      });
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = CustomerAccountStrings.saveError;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowPop || (!_dirty && !_busy && !_picking),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _leave();
    },
    child: Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: Text(
          CustomerAccountStrings.profile,
          style: AppTextStyles.headingMedium,
        ),
        backgroundColor: AppColors.bgCard,
        surfaceTintColor: AppColors.bgCard,
        leading: BackButton(onPressed: _leave),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _formKey,
              onChanged: () => setState(() {}),
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.screenH),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  Center(
                    child: _imageBytes == null
                        ? CustomerAccountAvatar(
                            name: _name.text,
                            reference: widget.profile.avatarUrl,
                            size: 88,
                          )
                        : ClipOval(
                            child: Image.memory(
                              _imageBytes!,
                              width: 88,
                              height: 88,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) =>
                                  const Icon(Icons.person_rounded, size: 88),
                            ),
                          ),
                  ),
                  Center(
                    child: TextButton.icon(
                      onPressed: _busy || _picking ? null : _pickAvatar,
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: const Text(CustomerAccountStrings.changeAvatar),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.accent,
                        minimumSize: const Size(48, 48),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _name,
                    enabled: !_busy,
                    maxLength: 100,
                    autofillHints: const [AutofillHints.name],
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: _decoration(CustomerAccountStrings.fullName),
                    validator: (v) =>
                        (v?.trim().length ?? 0) < 2 ||
                            (v?.trim().length ?? 0) > 100
                        ? CustomerAccountStrings.nameRequired
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _phone,
                    enabled: !_busy,
                    maxLength: 16,
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _save(),
                    decoration: _decoration(CustomerAccountStrings.phone),
                    validator: (v) =>
                        normalizeCustomerContactPhone(v ?? '').isNotEmpty
                        ? null
                        : CustomerAccountStrings.phoneInvalid,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    CustomerAccountStrings.contactHint,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  CustomerAccountSurface(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            CustomerAccountStrings.email,
                            style: AppTextStyles.labelMedium,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          SelectableText(
                            widget.profile.email,
                            style: AppTextStyles.bodyMedium,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            CustomerAccountStrings.emailHint,
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.lg),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.xl2),
                  FilledButton(
                    onPressed: _dirty && !_busy && !_picking ? _save : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.textOnAccent,
                      minimumSize: const Size.fromHeight(52),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadius.md,
                      ),
                    ),
                    child: Text(
                      _busy
                          ? CustomerAccountStrings.saving
                          : CustomerAccountStrings.save,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  InputDecoration _decoration(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: AppColors.bgCard,
    border: const OutlineInputBorder(
      borderRadius: AppRadius.md,
      borderSide: BorderSide(color: AppColors.border),
    ),
    enabledBorder: const OutlineInputBorder(
      borderRadius: AppRadius.md,
      borderSide: BorderSide(color: AppColors.border),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: AppRadius.md,
      borderSide: BorderSide(color: AppColors.accent),
    ),
  );
}
