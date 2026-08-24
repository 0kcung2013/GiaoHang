import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:image_picker/image_picker.dart';

import '../data/driver_profile_change_repository.dart';
import '../models/driver_account_view_data.dart';
import '../models/driver_profile_change_form_state.dart';
import '../utils/driver_profile_change_labels.dart';
import '../widgets/driver_profile_change_editor.dart';
import '../widgets/driver_profile_change_field_selector.dart';
import '../widgets/driver_profile_change_review.dart';
import '../widgets/driver_profile_change_sheet_chrome.dart';

Future<void> showDriverProfileChangeRequestSheet(
  BuildContext context, {
  required DriverAccountViewData profile,
  required DriverProfileChangeRepository repository,
  DriverProfileChangeRequest? request,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.bgLight,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.94,
      child: DriverProfileChangeRequestSheet(
        profile: profile,
        repository: repository,
        request: request,
      ),
    ),
  );
}

class DriverProfileChangeRequestSheet extends StatefulWidget {
  const DriverProfileChangeRequestSheet({
    super.key,
    required this.profile,
    required this.repository,
    this.request,
  });

  final DriverAccountViewData profile;
  final DriverProfileChangeRepository repository;
  final DriverProfileChangeRequest? request;

  @override
  State<DriverProfileChangeRequestSheet> createState() =>
      _DriverProfileChangeRequestSheetState();
}

class _DriverProfileChangeRequestSheetState
    extends State<DriverProfileChangeRequestSheet> {
  late DriverProfileChangeFormState _form;
  String? _requestId;
  bool _isReview = false;
  bool _isSubmitting = false;
  bool _isCancelling = false;
  DriverProfileChangeField? _uploadingField;
  String? _error;

  bool get _isEditable =>
      widget.request == null ||
      widget.request?.status == DriverProfileChangeStatus.draft;

  @override
  void initState() {
    super.initState();
    _requestId = widget.request?.id;
    _form = widget.request == null
        ? const DriverProfileChangeFormState()
        : DriverProfileChangeFormState.fromRequest(widget.request!);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        children: [
          DriverProfileChangeSheetHeader(
            title: _title,
            subtitle: _subtitle,
            onBack: _isReview && _isEditable
                ? () => setState(() {
                    _isReview = false;
                    _error = null;
                  })
                : null,
            onClose: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH,
                AppSpacing.lg,
                AppSpacing.screenH,
                AppSpacing.xl2,
              ),
              child: _isReview || !_isEditable
                  ? DriverProfileChangeReview(
                      profile: widget.profile,
                      changes: _reviewChanges,
                      reason: _form.reason,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chọn thông tin cần thay đổi',
                          style: AppTextStyles.headingSmall.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Các mục đã chọn sẽ được gửi chung trong một yêu cầu.',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        DriverProfileChangeFieldSelector(
                          selectedFields: _form.selectedFields,
                          onToggle: (field) => setState(() {
                            _form = _form.toggle(field);
                            _error = null;
                          }),
                        ),
                        const SizedBox(height: AppSpacing.xl2),
                        DriverProfileChangeEditor(
                          profile: widget.profile,
                          state: _form,
                          uploadingField: _uploadingField,
                          onValueChanged: (field, value) => setState(() {
                            _form = _form.setValue(field, value);
                            _error = null;
                          }),
                          onPickFile: _pickFile,
                        ),
                      ],
                    ),
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    if (!_isEditable) {
      return DriverProfileChangeSheetFooter(
        error: _error,
        child: Row(
          children: [
            if (widget.request?.canDriverCancel == true) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: _isCancelling ? null : _cancel,
                  style: _secondaryButtonStyle,
                  child: Text(_isCancelling ? 'Đang hủy...' : 'Hủy yêu cầu'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: FilledButton(
                onPressed: () => Navigator.of(context).maybePop(),
                style: _primaryButtonStyle,
                child: const Text('Đóng'),
              ),
            ),
          ],
        ),
      );
    }

    if (_isReview) {
      return DriverProfileChangeSheetFooter(
        error: _error,
        child: FilledButton.icon(
          onPressed: _isSubmitting ? null : _submit,
          style: _primaryButtonStyle,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.textOnAccent,
                  ),
                )
              : const Icon(Icons.send_rounded),
          label: Text(_isSubmitting ? 'Đang gửi...' : 'Gửi yêu cầu'),
        ),
      );
    }

    return DriverProfileChangeSheetFooter(
      error: _error,
      child: Column(
        children: [
          TextFormField(
            key: const Key('profile-change-reason'),
            initialValue: _form.reason,
            onChanged: (value) => setState(() {
              _form = _form.setReason(value);
              _error = null;
            }),
            maxLines: 2,
            minLines: 1,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary,
            ),
            decoration: const InputDecoration(
              labelText: 'Lý do thay đổi',
              hintText: 'Ví dụ: Đổi số điện thoại đang sử dụng',
              filled: true,
              fillColor: AppColors.bgCard,
              border: OutlineInputBorder(borderRadius: AppRadius.md),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.md,
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.md,
                borderSide: BorderSide(
                  color: AppColors.borderFocus,
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _uploadingField == null ? _review : null,
              style: _primaryButtonStyle,
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Xem lại'),
            ),
          ),
        ],
      ),
    );
  }

  Map<DriverProfileChangeField, Object?> get _reviewChanges {
    if (!_isEditable) return _form.changes;
    return _form.normalizedChanges(widget.profile);
  }

  String get _title => !_isEditable
      ? driverProfileChangeStatusLabel(widget.request!.status)
      : _isReview
      ? 'Xem lại yêu cầu'
      : 'Chỉnh sửa hồ sơ';

  String get _subtitle => !_isEditable
      ? 'Toàn bộ yêu cầu do Admin xử lý'
      : 'Hồ sơ hiện tại vẫn giữ nguyên cho đến khi được duyệt';

  void _review() {
    final changes = _form.normalizedChanges(widget.profile);
    if (changes.isEmpty) {
      setState(() => _error = 'Vui lòng nhập ít nhất một thông tin mới.');
      return;
    }
    if (_form.reason.trim().length < 3) {
      setState(() => _error = 'Vui lòng nhập lý do thay đổi ít nhất 3 ký tự.');
      return;
    }
    setState(() {
      _isReview = true;
      _error = null;
    });
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final requestId = await _ensureDraft();
      await widget.repository.submit(
        requestId: requestId,
        changes: _form.normalizedChanges(widget.profile),
        reason: _form.reason,
      );
      if (mounted) Navigator.of(context).maybePop();
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _pickFile(DriverProfileChangeField field) async {
    setState(() {
      _uploadingField = field;
      _error = null;
    });
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
      );
      if (image == null) return;
      final requestId = await _ensureDraft();
      final extension = image.name.split('.').last.toLowerCase();
      final path = await widget.repository.uploadDraftFile(
        requestId: requestId,
        field: field,
        bytes: await image.readAsBytes(),
        extension: extension,
        contentType: _contentType(extension),
      );
      if (mounted) setState(() => _form = _form.setValue(field, path));
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _uploadingField = null);
    }
  }

  Future<String> _ensureDraft() async {
    if (_requestId?.isNotEmpty == true) return _requestId!;
    final request = await widget.repository.createDraft();
    _requestId = request.id;
    return request.id;
  }

  Future<void> _cancel() async {
    setState(() {
      _isCancelling = true;
      _error = null;
    });
    try {
      await widget.repository.cancel(widget.request!.id);
      if (mounted) Navigator.of(context).maybePop();
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  String _message(Object error) => error is DriverProfileChangeException
      ? error.message
      : 'Chưa thể xử lý yêu cầu. Vui lòng thử lại.';

  String _contentType(String extension) => extension == 'png'
      ? 'image/png'
      : extension == 'webp'
      ? 'image/webp'
      : 'image/jpeg';

  ButtonStyle get _primaryButtonStyle => FilledButton.styleFrom(
    backgroundColor: AppColors.accent,
    foregroundColor: AppColors.textOnAccent,
    minimumSize: const Size(48, 54),
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.full),
  );

  ButtonStyle get _secondaryButtonStyle => OutlinedButton.styleFrom(
    foregroundColor: AppColors.error,
    minimumSize: const Size(48, 54),
    side: const BorderSide(color: AppColors.error),
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.full),
  );
}
