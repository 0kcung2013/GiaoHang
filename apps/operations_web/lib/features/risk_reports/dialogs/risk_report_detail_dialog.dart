import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/risk_report_repository.dart';
import '../models/risk_message_evidence.dart';
import '../models/risk_report.dart';
import '../models/risk_report_policy.dart';
import '../widgets/risk_report_actions.dart';
import '../widgets/risk_report_detail_body.dart';
import '../widgets/risk_report_detail_content.dart';

class RiskReportDetailDialog extends StatefulWidget {
  const RiskReportDetailDialog({
    required this.report,
    required this.currentUserId,
    required this.isAdmin,
    required this.repository,
    super.key,
  });

  final RiskReport report;
  final String currentUserId;
  final bool isAdmin;
  final RiskReportRepository repository;

  @override
  State<RiskReportDetailDialog> createState() => _RiskReportDetailDialogState();
}

class _RiskReportDetailDialogState extends State<RiskReportDetailDialog> {
  List<RiskReportEvent>? _events;
  List<RiskOrderMessage>? _orderMessages;
  List<RiskMessageEvidence>? _messageEvidence;
  List<RiskReportAttachmentView>? _attachments;
  List<CaseMessage>? _caseMessages;
  RiskIntervention? _intervention;
  List<RiskReportNote> _notes = const [];
  String? _error;
  bool _submitting = false;
  bool _attachingEvidence = false;

  @override
  void initState() {
    super.initState();
    _loadEvents();
    _loadMessageEvidence();
    _loadAttachments();
    _loadIntervention();
    _loadNotes();
    _loadCaseMessages();
  }

  Future<void> _loadCaseMessages() async {
    final repository = widget.repository;
    if (repository is! RiskCaseConversationRepository) {
      if (mounted) setState(() => _caseMessages = const []);
      return;
    }
    final conversations = repository as RiskCaseConversationRepository;
    try {
      final messages = await conversations.fetchCaseMessages(widget.report.id);
      if (mounted) setState(() => _caseMessages = messages);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được trao đổi hồ sơ.');
    }
  }

  Future<void> _loadNotes() async {
    final repository = widget.repository;
    if (repository is! RiskInterventionCommandRepository) return;
    final commands = repository as RiskInterventionCommandRepository;
    try {
      final notes = await commands.fetchNotes(widget.report.id);
      if (mounted) setState(() => _notes = notes);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được ghi chú nội bộ.');
    }
  }

  Future<void> _loadIntervention() async {
    final repository = widget.repository;
    if (repository is! RiskInterventionCommandRepository) return;
    final commands = repository as RiskInterventionCommandRepository;
    try {
      final intervention = await commands.fetchIntervention(widget.report.id);
      if (mounted) setState(() => _intervention = intervention);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không tải được trạng thái can thiệp.');
      }
    }
  }

  Future<void> _loadAttachments() async {
    final repository = widget.repository;
    if (repository is! RiskReportAttachmentRepository) {
      setState(() => _attachments = const []);
      return;
    }
    try {
      final attachmentRepository = repository as RiskReportAttachmentRepository;
      final attachments = await attachmentRepository.fetchAttachments(
        widget.report.id,
      );
      if (mounted) setState(() => _attachments = attachments);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không tải được ảnh và vị trí bằng chứng.');
      }
    }
  }

  Future<void> _loadEvents() async {
    try {
      final events = await widget.repository.fetchEvents(widget.report.id);
      if (mounted) setState(() => _events = events);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không tải được lịch sử xử lý.');
    }
  }

  Future<void> _loadMessageEvidence() async {
    try {
      final results = await Future.wait([
        widget.report.isSystemIncident
            ? Future.value(<RiskOrderMessage>[])
            : widget.repository.fetchOrderMessages(widget.report.orderId),
        widget.repository.fetchMessageEvidence(widget.report.id),
      ]);
      if (!mounted) return;
      setState(() {
        _orderMessages = results[0] as List<RiskOrderMessage>;
        _messageEvidence = results[1] as List<RiskMessageEvidence>;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không tải được tin nhắn bằng chứng.');
      }
    }
  }

  Future<void> _attachMessageEvidence(List<String> messageIds) async {
    setState(() => _attachingEvidence = true);
    try {
      final evidence = await widget.repository.attachMessageEvidence(
        widget.report.id,
        messageIds,
      );
      if (mounted) setState(() => _messageEvidence = evidence);
    } on PostgrestException catch (error) {
      await _loadIntervention();
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không thể gắn tin nhắn.');
    } finally {
      if (mounted) setState(() => _attachingEvidence = false);
    }
  }

  Future<void> _assignToMe() async {
    setState(() => _submitting = true);
    try {
      await widget.repository.assignToMe(widget.report.id);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không thể nhận báo cáo này.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _takeOver() async {
    final repository = widget.repository;
    if (repository is! RiskOwnershipCommandRepository) return;
    final ownership = repository as RiskOwnershipCommandRepository;
    setState(() => _submitting = true);
    try {
      await ownership.takeOverReport(widget.report.id);
      if (mounted) Navigator.pop(context, true);
    } on PostgrestException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _sendCaseMessage(
    String body,
    CaseMessageVisibility visibility,
  ) async {
    final repository = widget.repository;
    if (repository is! RiskCaseConversationRepository) return;
    final conversations = repository as RiskCaseConversationRepository;
    await conversations.postCaseMessage(
      widget.report.id,
      body,
      visibility: visibility,
    );
    await _loadCaseMessages();
    await _loadEvents();
  }

  Future<void> _changeStatus(RiskStatus status) async {
    String? resolution;
    if (RiskReportPolicy.requiresResolution(status)) {
      resolution = await showRiskResolutionDialog(context, status);
      if (resolution == null || !mounted) return;
    }

    setState(() => _submitting = true);
    try {
      await widget.repository.changeStatus(
        widget.report.id,
        status,
        resolution: resolution,
      );
      if (mounted) Navigator.pop(context, true);
    } on PostgrestException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không thể cập nhật trạng thái.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _runIntervention(
    Future<void> Function(RiskInterventionCommandRepository commands) action, {
    bool closeAfter = true,
  }) async {
    final repository = widget.repository;
    if (repository is! RiskInterventionCommandRepository) return;
    final commands = repository as RiskInterventionCommandRepository;
    setState(() => _submitting = true);
    try {
      await action(commands);
      if (!mounted) return;
      if (closeAfter) {
        Navigator.pop(context, true);
      } else {
        await _loadIntervention();
      }
    } on PostgrestException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Không thể cập nhật can thiệp đơn.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final transitions = RiskReportPolicy.allowedTransitions(
      status: report.status,
      severity: report.severity,
      isAdmin: widget.isAdmin,
    );
    final criticalRestricted =
        report.severity == RiskSeverity.critical && !widget.isAdmin;
    final screen = MediaQuery.sizeOf(context);

    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 820,
          maxHeight: screen.height - AppSpacing.xl3,
        ),
        child: Material(
          color: AppColors.bgCard,
          borderRadius: AppRadius.xl,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              RiskReportDetailHeader(
                report: report,
                onClose: () => Navigator.pop(context),
              ),
              Expanded(
                child: RiskReportDetailBody(
                  report: report,
                  currentUserId: widget.currentUserId,
                  criticalRestricted: criticalRestricted,
                  intervention: _intervention,
                  notes: _notes,
                  attachments: _attachments,
                  messageEvidence: _messageEvidence,
                  availableMessages: _availableMessages,
                  evidenceLoading:
                      _messageEvidence == null || _orderMessages == null,
                  attachingEvidence: _attachingEvidence,
                  onAttachEvidence: _attachMessageEvidence,
                  caseMessages: _caseMessages,
                  canReply: report.assignedTo == widget.currentUserId,
                  onSendMessage: _sendCaseMessage,
                  events: _events,
                  error: _error,
                  onHoldBeforePickup: () => _runIntervention(
                    (commands) => commands.holdBeforePickup(report.id),
                  ),
                  onDecision: (decision, instruction) => _runIntervention(
                    (commands) => commands.decideOperation(
                      report.id,
                      decision,
                      instruction: instruction,
                    ),
                  ),
                  onConfirmCustody: () => _runIntervention(
                    (commands) => commands.confirmCustodyResolved(report.id),
                  ),
                  onResumeOrder: () => _runIntervention(
                    (commands) => commands.resumeHeldOrder(report.id),
                  ),
                  onAddNote: (body) => _runIntervention((commands) async {
                    await commands.addInternalNote(report.id, body);
                    await _loadNotes();
                  }, closeAfter: false),
                ),
              ),
              RiskReportActionBar(
                assignedToMe: report.assignedTo == widget.currentUserId,
                unassigned: report.assignedTo == null,
                submitting: _submitting,
                transitions: transitions,
                onAssign: _assignToMe,
                canTakeOver:
                    widget.isAdmin &&
                    report.assignedTo != null &&
                    report.assignedTo != widget.currentUserId,
                onTakeOver: _takeOver,
                onTransition: _changeStatus,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<RiskOrderMessage> get _availableMessages {
    final attachedIds = (_messageEvidence ?? const <RiskMessageEvidence>[])
        .map((item) => item.sourceMessageId)
        .whereType<String>()
        .toSet();
    return (_orderMessages ?? const <RiskOrderMessage>[])
        .where((message) => !attachedIds.contains(message.id))
        .toList();
  }
}
