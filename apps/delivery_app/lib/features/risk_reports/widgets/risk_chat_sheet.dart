import 'dart:async';

import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_storage/giaohang_storage.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../../order_help/controllers/support_chat_attachment_draft.dart';
import '../../order_help/widgets/support_chat/support_chat_attachment_preview.dart';
import '../../order_help/widgets/support_chat/support_chat_composer.dart';
import '../../order_help/widgets/support_chat/support_chat_header.dart';
import '../../order_help/widgets/support_chat/support_chat_messages.dart';
import '../controllers/risk_chat_controller.dart';
import '../data/participant_risk_report_query_repository.dart';
import '../models/participant_risk_report_summary.dart';
import '../utils/risk_chat_strings.dart';

Future<void> showParticipantRiskChatSheet(
  BuildContext context, {
  required ParticipantRiskReportSummary report,
  required String requesterId,
  required String orderCode,
  required ParticipantRiskReportQueryRepository repository,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  builder: (_) => RiskChatSheet(
    report: report,
    requesterId: requesterId,
    orderCode: orderCode,
    repository: repository,
  ),
);

class RiskChatSheet extends StatefulWidget {
  const RiskChatSheet({
    required this.report,
    required this.requesterId,
    required this.orderCode,
    required this.repository,
    this.attachmentDraft,
    super.key,
  });

  final ParticipantRiskReportSummary report;
  final String requesterId;
  final String orderCode;
  final ParticipantRiskReportQueryRepository repository;
  final SupportChatAttachmentDraft? attachmentDraft;

  @override
  State<RiskChatSheet> createState() => _RiskChatSheetState();
}

class _RiskChatSheetState extends State<RiskChatSheet>
    with WidgetsBindingObserver {
  final _composer = TextEditingController();
  final _scroll = ScrollController();
  late final RiskChatController _chat;
  late final SupportChatAttachmentDraft _attachments;
  bool _busy = false;
  String? _attachmentError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _attachments =
        widget.attachmentDraft ??
        SupportChatAttachmentDraft(contextId: widget.report.orderId);
    _chat = RiskChatController(
      repository: widget.repository,
      requesterId: widget.requesterId,
      report: widget.report,
    )..addListener(_updated);
    unawaited(_chat.refresh());
  }

  void _updated() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      unawaited(
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: AppDuration.normal,
          curve: AppCurve.decelerate,
        ),
      );
    });
  }

  Future<void> _pickImages() async {
    if (_busy || _chat.closed) return;
    setState(() {
      _busy = true;
      _attachmentError = null;
    });
    try {
      await _attachments.pick();
    } on R2MediaException catch (error) {
      _attachmentError = error.message;
    } catch (_) {
      _attachmentError = 'Chưa chọn được ảnh. Vui lòng thử lại.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    if (_busy || _chat.sending || _chat.closed) return;
    final text = _composer.text.trim();
    if (text.isEmpty && _attachments.images.isEmpty) return;
    setState(() {
      _busy = true;
      _attachmentError = null;
    });
    var cleared = false;
    try {
      final images = await _attachments.upload();
      if (!mounted) return;
      final body = CaseMessageContent(text: text, images: images).encode();
      if (body.length > 4000) {
        setState(() => _attachmentError = RiskChatStrings.tooLong);
        return;
      }
      _composer.clear();
      cleared = true;
      final sent = await _chat.send(body);
      if (!mounted) return;
      if (sent) {
        _attachments.clear();
      } else {
        _composer.text = text;
        _composer.selection = TextSelection.collapsed(offset: text.length);
      }
    } on R2MediaException catch (error) {
      _attachmentError = 'Chưa tải được ảnh: ${error.message}';
    } catch (_) {
      _attachmentError = RiskChatStrings.sendError;
      if (cleared && mounted) _composer.text = text;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_chat.refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _chat.removeListener(_updated);
    _chat.dispose();
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final id = _chat.report.id;
    final shortId = id.length > 8 ? id.substring(0, 8) : id;
    final code = widget.orderCode.isEmpty
        ? _chat.report.orderId
        : widget.orderCode;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: FractionallySizedBox(
        heightFactor: 0.94,
        child: Material(
          key: const Key('risk-chat-sheet'),
          color: AppColors.bgLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: LayoutBuilder(
            builder: (context, constraints) => Column(
              children: [
                SupportChatHeader(
                  title: RiskChatStrings.subject,
                  compact: keyboard > 0 || constraints.maxHeight < 420,
                  connectionLabel: _chat.connected
                      ? RiskChatStrings.synced
                      : _chat.error == null
                      ? RiskChatStrings.loading
                      : RiskChatStrings.disconnected,
                  connected: _chat.connected,
                  orderLabel: 'Đơn $code',
                  subject: 'Báo cáo #${shortId.toUpperCase()}',
                  statusLabel: RiskChatStrings.status(_chat.report.status),
                  statusColor: _chat.report.status.isClosed
                      ? AppColors.success
                      : AppColors.warning,
                  onClose: () => Navigator.pop(context),
                  onRetry: () => unawaited(_chat.refresh()),
                ),
                Expanded(
                  child: SupportChatMessages(
                    messages: _chat.messages,
                    requesterId: widget.requesterId,
                    scrollController: _scroll,
                    pendingBody: _chat.pendingBody,
                    welcomeText: RiskChatStrings.welcome,
                    guidance: _chat.available
                        ? null
                        : RiskChatStrings.unavailable,
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight / 2,
                  ),
                  child: SingleChildScrollView(
                    reverse: true,
                    child: SupportChatComposer(
                      controller: _composer,
                      sending: _busy || _chat.sending,
                      started: true,
                      closed: _chat.closed,
                      error: _attachmentError ?? _chat.error,
                      onSend: () => unawaited(_send()),
                      onAttach: () => unawaited(_pickImages()),
                      attachmentPreview: _attachments.images.isEmpty
                          ? null
                          : SupportChatAttachmentPreview(
                              images: _attachments.images,
                              enabled: !_busy && !_chat.sending,
                              onRemove: (image) =>
                                  setState(() => _attachments.remove(image)),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
