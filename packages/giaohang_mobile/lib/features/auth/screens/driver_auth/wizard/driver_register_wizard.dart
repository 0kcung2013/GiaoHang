import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:giaohang_design/giaohang_design.dart';
import '../../../../../core/services/auth_service.dart';
import '../../../../../core/services/driver_kyc_storage_service.dart';
import '../driver_auth_strings.dart';
import '../widgets/driver_auth_feedback.dart';
import '../widgets/driver_registration_progress.dart';
import 'driver_register_data.dart';
import 'driver_register_prefill.dart';
import 'driver_register_validation.dart';
import 'driver_identity_steps.dart';
import 'driver_vehicle_step.dart';
import 'driver_documents_step.dart';
import 'driver_confirmation_step.dart';

/// Five-step registration. Account prefill skips the first step as before.
class DriverRegisterWizard extends StatefulWidget {
  const DriverRegisterWizard({super.key, this.prefill});
  final DriverRegisterPrefill? prefill;

  @override
  State<DriverRegisterWizard> createState() => _DriverRegisterWizardState();
}

class _DriverRegisterWizardState extends State<DriverRegisterWizard> {
  final _data = DriverRegisterData();
  final _auth = AuthService();
  final _storage = DriverKycStorageService();
  final _picker = ImagePicker();
  final _scrollController = ScrollController();

  late int _step;
  late final bool _skipAccount;
  bool _loading = false;
  String? _error;
  DriverRegisterIssue? _issue;

  int get _firstStep => _skipAccount ? 1 : 0;
  int get _totalVisibleSteps => _skipAccount ? 4 : 5;
  int get _displayStepIndex => _skipAccount ? _step : _step + 1;

  @override
  void initState() {
    super.initState();
    final p = widget.prefill;
    if (p != null) {
      _data.email = p.email.trim();
      _data.password = p.password;
      _data.fullName = p.fullName.trim();
      _data.phone = p.phone.trim();
    }
    _skipAccount = p?.hasAccount ?? false;
    _step = _firstStep;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(void Function(XFile file) assign) async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (mounted && file != null) {
        setState(() {
          assign(file);
          _issue = null;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) _showError(DriverAuthStrings.pickerError);
    }
  }

  bool _validateCurrentStep() {
    final issue = validateDriverRegisterStep(_step, _data);
    setState(() {
      _issue = issue;
      _error = null;
    });
    return issue == null;
  }

  void _showError(String message) {
    setState(() => _error = message);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: MediaQuery.disableAnimationsOf(context)
              ? const Duration(milliseconds: 1)
              : AppDuration.normal,
          curve: AppCurve.decelerate,
        );
      }
    });
  }

  void _changeStep(int step) {
    FocusScope.of(context).unfocus();
    setState(() {
      _step = step;
      _issue = null;
      _error = null;
    });
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  void _next() {
    if (_loading || !_validateCurrentStep()) return;
    if (_step < DriverAuthStrings.stepTitles.length - 1) {
      _changeStep(_step + 1);
    } else {
      _submit();
    }
  }

  void _back() {
    if (!_loading && _step > _firstStep) _changeStep(_step - 1);
  }

  Future<void> _submit() async {
    if (!_validateCurrentStep()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1) Auth trước để có uid upload storage
      final user = await _auth.signUpDriverAuth(
        email: _data.email.trim(),
        password: _data.password,
        fullName: _data.fullName.trim(),
        phone: _data.phone.trim(),
      );

      if (user == null) {
        throw Exception(DriverAuthStrings.registerFailed);
      }

      final uid = user.id;

      try {
        // 2) Upload ảnh KYC
        final avatarUrl = await _storage.uploadDriverImage(
          userId: uid,
          image: _data.avatarFile!,
          kind: 'avatar',
        );
        final idFront = await _storage.uploadDriverImage(
          userId: uid,
          image: _data.idCardFrontFile!,
          kind: 'id_front',
        );
        final idBack = await _storage.uploadDriverImage(
          userId: uid,
          image: _data.idCardBackFile!,
          kind: 'id_back',
        );
        final licenseUrl = await _storage.uploadDriverImage(
          userId: uid,
          image: _data.driverLicenseFile!,
          kind: 'license',
        );
        final vehicleUrl = await _storage.uploadDriverImage(
          userId: uid,
          image: _data.vehiclePhotoFile!,
          kind: 'vehicle',
        );

        // 3) Một lần tạo profile + KYC đầy đủ
        await _auth.createDriverProfile(
          email: _data.email.trim(),
          fullName: _data.fullName.trim(),
          phone: _data.phone.trim(),
          vehicleType: _data.vehicleType,
          licensePlate: _data.licensePlate.trim(),
          vehicleBrandModel: _data.vehicleBrandModel.trim(),
          vehicleColor: _data.vehicleColor.trim(),
          avatarUrl: avatarUrl,
          idCardNumber: _data.idCardNumber.trim(),
          idCardFrontUrl: idFront,
          idCardBackUrl: idBack,
          driverLicenseNumber: _data.driverLicenseNumber.trim(),
          driverLicenseUrl: licenseUrl,
          vehiclePhotoUrl: vehicleUrl,
        );
      } catch (_) {
        await Supabase.instance.client.auth.signOut();
        rethrow;
      }

      if (!mounted) return;
      context.go('/driver-pending');
    } on AuthException catch (e) {
      if (!mounted) return;
      if (e.message.toLowerCase().contains('already')) {
        _showError(DriverAuthStrings.emailExists);
      } else {
        _showError(e.message);
      }
    } catch (e) {
      if (!mounted) return;
      _showError('${DriverAuthStrings.registerFailed}: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _stepContent() => switch (_step) {
    0 => DriverAccountStep(data: _data, issue: _issue, onNext: _next),
    1 => DriverPersonalStep(
      data: _data,
      issue: _issue,
      onPickAvatar: () => _pickImage((f) => _data.avatarFile = f),
    ),
    2 => DriverVehicleStep(data: _data, issue: _issue),
    3 => DriverDocumentsStep(
      data: _data,
      issue: _issue,
      onPick: (kind) => _pickImage((f) {
        switch (kind) {
          case 'id_front':
            _data.idCardFrontFile = f;
          case 'id_back':
            _data.idCardBackFile = f;
          case 'license':
            _data.driverLicenseFile = f;
          case 'vehicle':
            _data.vehiclePhotoFile = f;
        }
      }),
    ),
    _ => DriverConfirmationStep(data: _data),
  };

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DriverRegistrationProgress(
        current: _displayStepIndex,
        total: _totalVisibleSteps,
        title: DriverAuthStrings.stepTitles[_step],
      ),
      Expanded(
        child: AbsorbPointer(
          absorbing: _loading,
          child: SingleChildScrollView(
            controller: _scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH,
              AppSpacing.sm,
              AppSpacing.screenH,
              AppSpacing.xl2,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  DriverAuthStrings.stepHeadings[_step],
                  style: AppTextStyles.headingLarge.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  DriverAuthStrings.stepHints[_step],
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (_skipAccount && _step == _firstStep) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '${DriverAuthStrings.prefilledAccount}: ${_data.email}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl2),
                KeyedSubtree(key: ValueKey(_step), child: _stepContent()),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  DriverAuthNotice(message: _error!, error: true),
                ],
              ],
            ),
          ),
        ),
      ),
      Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH,
          AppSpacing.md,
          AppSpacing.screenH,
          AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            if (_step > _firstStep) ...[
              IconButton.outlined(
                tooltip: DriverAuthStrings.back,
                onPressed: _loading ? null : _back,
                style: IconButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: BorderSide(color: AppColors.border),
                  minimumSize: const Size(52, 52),
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.md,
                  ),
                ),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: DriverAuthButton(
                label: _step == 4
                    ? DriverAuthStrings.submit
                    : DriverAuthStrings.next,
                loadingLabel: DriverAuthStrings.submitting,
                loading: _loading,
                onPressed: _next,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
