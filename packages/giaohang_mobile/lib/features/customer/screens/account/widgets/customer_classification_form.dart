import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/models/user_model.dart';
import '../constants/customer_classification_strings.dart';
import '../data/customer_classification_repository.dart';
import '../providers/customer_account_providers.dart';
import 'customer_type_choice.dart';

class CustomerClassificationForm extends ConsumerStatefulWidget {
  const CustomerClassificationForm({
    super.key,
    required this.profile,
    required this.onboarding,
  });
  final UserModel profile;
  final bool onboarding;
  @override
  ConsumerState<CustomerClassificationForm> createState() => _FormState();
}

class _FormState extends ConsumerState<CustomerClassificationForm> {
  final _form = GlobalKey<FormState>();
  late String? _type = widget.profile.customerType;
  late final _name = TextEditingController(text: widget.profile.businessName);
  late final _address = TextEditingController(
    text: widget.profile.businessAddress,
  );
  late final _tax = TextEditingController(text: widget.profile.businessTaxCode);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _tax.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    if (_type == null) {
      setState(() => _error = CustomerClassificationStrings.selectType);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(customerClassificationRepositoryProvider)
          .save(
            userId: widget.profile.id,
            type: _type!,
            businessName: _name.text,
            businessAddress: _address.text,
            taxCode: _tax.text,
          );
      if (!mounted) return;
      refreshCustomerAccount(ref, widget.profile.id);
      if (widget.onboarding) {
        context.go('/customer-home');
      } else {
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = CustomerClassificationStrings.saveError;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenH),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              CustomerClassificationStrings.title,
              style: AppTextStyles.headingLarge,
            ),
            const SizedBox(height: AppSpacing.xl),
            CustomerTypeChoice(
              title: CustomerClassificationStrings.individual,
              description: CustomerClassificationStrings.individualHint,
              icon: Icons.person_outline_rounded,
              selected: _type == 'individual',
              onTap: _busy
                  ? null
                  : () => setState(() {
                      _type = 'individual';
                      _error = null;
                    }),
            ),
            const SizedBox(height: AppSpacing.md),
            CustomerTypeChoice(
              title: CustomerClassificationStrings.business,
              description: CustomerClassificationStrings.businessHint,
              icon: Icons.storefront_outlined,
              selected: _type == 'business',
              onTap: _busy
                  ? null
                  : () => setState(() {
                      _type = 'business';
                      _error = null;
                    }),
            ),
            if (_type == 'business') ...[
              const SizedBox(height: AppSpacing.xl),
              _field(
                _name,
                CustomerClassificationStrings.businessName,
                160,
                (v) => v.trim().length < 2
                    ? CustomerClassificationStrings.nameError
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              _field(
                _address,
                CustomerClassificationStrings.businessAddress,
                500,
                (v) => v.trim().length < 5
                    ? CustomerClassificationStrings.addressError
                    : null,
                address: true,
              ),
              const SizedBox(height: AppSpacing.md),
              _field(
                _tax,
                CustomerClassificationStrings.taxCode,
                20,
                (v) =>
                    v.trim().isEmpty ||
                        RegExp(r'^[0-9-]{10,20}$').hasMatch(v.trim())
                    ? null
                    : CustomerClassificationStrings.taxError,
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.lg),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _busy || _type == null ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.textOnAccent,
                minimumSize: const Size.fromHeight(52),
                shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
              ),
              child: Text(
                _busy
                    ? CustomerClassificationStrings.saving
                    : CustomerClassificationStrings.save,
                style: AppTextStyles.labelLarge,
              ),
            ),
            if (widget.onboarding)
              TextButton(
                onPressed: _busy
                    ? null
                    : () => context.go('/customer-home?tab=orders'),
                child: const Text(CustomerClassificationStrings.activeOrders),
              ),
          ],
        ),
      ),
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label,
    int max,
    String? Function(String) validate, {
    bool address = false,
  }) => TextFormField(
    controller: controller,
    style: AppTextStyles.bodyMedium,
    enabled: !_busy,
    maxLength: max,
    minLines: 1,
    maxLines: address ? 3 : 1,
    textCapitalization: address || controller == _name
        ? TextCapitalization.words
        : TextCapitalization.none,
    textInputAction: TextInputAction.next,
    decoration: InputDecoration(
      labelText: label,
      labelStyle: AppTextStyles.bodySmall,
      counterStyle: AppTextStyles.bodySmall,
      filled: true,
      fillColor: AppColors.bgCard,
      border: const OutlineInputBorder(borderRadius: AppRadius.md),
      enabledBorder: const OutlineInputBorder(
        borderRadius: AppRadius.md,
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: AppRadius.md,
        borderSide: BorderSide(color: AppColors.accent),
      ),
    ),
    validator: (v) => validate(v ?? ''),
  );
}
