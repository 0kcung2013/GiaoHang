import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/order_model.dart';
import '../controllers/risk_report_form_controller.dart';
import '../data/risk_report_repository.dart';
import '../utils/risk_report_options.dart';
import 'risk_evidence_step.dart';
import 'risk_message_picker_sheet.dart';
import 'risk_reason_step.dart';
import 'risk_review_step.dart';
import 'risk_report_sheet_chrome.dart';

Future<RiskReportSubmissionResult?> showRiskReportSheet(
  BuildContext context, {
  required OrderModel order,
  required RiskReporterRole role,
  RiskCategory? initialCategory,
  ParticipantRiskReportRepository? repository,
}) {
  return showModalBottomSheet<RiskReportSubmissionResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.primary.withValues(alpha: 0.42),
    builder: (_) => RiskReportSheet(
      order: order,
      role: role,
      initialCategory: initialCategory,
      repository: repository ?? SupabaseParticipantRiskReportRepository(),
    ),
  );
}

class RiskReportSheet extends StatefulWidget {
  const RiskReportSheet({
    required this.order,
    required this.role,
    required this.repository,
    this.initialCategory,
    super.key,
  });

  final OrderModel order;
  final RiskReporterRole role;
  final ParticipantRiskReportRepository repository;
  final RiskCategory? initialCategory;

  @override
  State<RiskReportSheet> createState() => _RiskReportSheetState();
}

class _RiskReportSheetState extends State<RiskReportSheet> {
  late final RiskReportFormController _controller;
  late final TextEditingController _descriptionController;
  bool _loadingEvidence = false;

  @override
  void initState() {
    super.initState();
    _controller = RiskReportFormController(
      orderId: widget.order.id,
      repository: widget.repository,
    );
    final initialCategory = widget.initialCategory;
    if (initialCategory != null) {
      _controller.selectCategory(initialCategory);
      _controller.next();
    }
    _controller.addListener(_refresh);
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _controller.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: FractionallySizedBox(
        heightFactor: 0.92,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: AppShadow.elevated,
          ),
          child: Column(
            children: [
              RiskReportSheetHeader(
                step: state.step,
                onClose: () => Navigator.pop(context),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH,
                    AppSpacing.md,
                    AppSpacing.screenH,
                    AppSpacing.xl,
                  ),
                  child: AnimatedSwitcher(
                    duration: AppDuration.normal,
                    child: KeyedSubtree(
                      key: ValueKey(state.step),
                      child: _stepContent(state),
                    ),
                  ),
                ),
              ),
              RiskReportSheetFooter(
                step: state.step,
                submitting: state.isSubmitting,
                submissionLabel: _submissionLabel(state.submissionPhase),
                errorMessage: state.errorMessage,
                onBack: _controller.back,
                onPrimary: state.step < 2 ? _controller.next : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepContent(RiskReportFormState state) {
    if (state.step == 0) {
      return RiskReasonStep(
        role: widget.role,
        selected: state.category,
        errorText: state.categoryError,
        onSelected: _controller.selectCategory,
      );
    }
    if (state.step == 1) {
      return RiskEvidenceStep(
        descriptionController: _descriptionController,
        photos: state.photos,
        latitude: state.latitude,
        longitude: state.longitude,
        messageCount: state.messageIds.length,
        descriptionError: state.descriptionError,
        photoError: state.photoError,
        onDescriptionChanged: _controller.setDescription,
        onPickPhotos: _pickPhotos,
        onCaptureLocation: _captureLocation,
        onPickMessages: _pickMessages,
      );
    }
    return RiskReviewStep(
      trackingCode: widget.order.trackingCode,
      option: riskOptionFor(widget.role, state.category),
      description: state.description,
      photoCount: state.photos.length,
      hasLocation: state.latitude != null,
      messageCount: state.messageIds.length,
    );
  }

  Future<void> _pickPhotos() async {
    if (_loadingEvidence) return;
    setState(() => _loadingEvidence = true);
    try {
      final remaining = 5 - _controller.state.photos.length;
      if (remaining <= 0) {
        _showMessage('Bạn đã chọn đủ 5 ảnh.');
        return;
      }
      final files = await ImagePicker().pickMultiImage(
        imageQuality: 92,
        limit: remaining,
      );
      final additions = <RiskPhotoInput>[];
      for (final file in files.take(remaining)) {
        additions.add(
          RiskPhotoInput(
            fileName: file.name,
            bytes: Uint8List.fromList(await file.readAsBytes()),
          ),
        );
      }
      _controller.setPhotos([..._controller.state.photos, ...additions]);
    } catch (_) {
      _showMessage('Không thể đọc ảnh đã chọn.');
    } finally {
      if (mounted) setState(() => _loadingEvidence = false);
    }
  }

  Future<void> _captureLocation() async {
    if (_loadingEvidence) return;
    setState(() => _loadingEvidence = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMessage('Bạn chưa cấp quyền vị trí.');
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      _controller.setLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (_) {
      _showMessage('Chưa thể lấy vị trí hiện tại.');
    } finally {
      if (mounted) setState(() => _loadingEvidence = false);
    }
  }

  Future<void> _pickMessages() async {
    if (_loadingEvidence) return;
    setState(() => _loadingEvidence = true);
    try {
      final response = await Supabase.instance.client
          .from('order_messages')
          .select('id, body, message_type, created_at')
          .eq('order_id', widget.order.id)
          .order('created_at', ascending: false)
          .limit(20);
      if (!mounted) return;
      final rows = response
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      final selected = await showRiskMessagePicker(
        context,
        rows,
        _controller.state.messageIds.toSet(),
      );
      if (selected != null) _controller.setMessageIds(selected.toList());
    } catch (_) {
      _showMessage('Chưa thể tải tin nhắn của đơn hàng.');
    } finally {
      if (mounted) setState(() => _loadingEvidence = false);
    }
  }

  Future<void> _submit() async {
    final result = await _controller.submit();
    if (result != null && mounted) Navigator.pop(context, result);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _submissionLabel(RiskReportSubmissionPhase? phase) => switch (phase) {
    RiskReportSubmissionPhase.checkingDuplicate => 'Đang kiểm tra báo cáo',
    RiskReportSubmissionPhase.processingImages => 'Đang xử lý ảnh',
    RiskReportSubmissionPhase.uploadingImages => 'Đang tải ảnh',
    RiskReportSubmissionPhase.sendingReport => 'Đang gửi báo cáo',
    null => 'Đang chuẩn bị báo cáo',
  };
}
