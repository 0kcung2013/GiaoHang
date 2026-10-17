import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../data/participant_risk_report_query_repository.dart';
import '../models/participant_risk_report_summary.dart';
import '../utils/risk_chat_strings.dart';

/// Một cuộc trao đổi chỉ thuộc một risk_report_id, không tạo support ticket.
class RiskChatController extends ChangeNotifier {
  RiskChatController({
    required this.repository,
    required this.requesterId,
    required this.report,
  });

  final ParticipantRiskReportQueryRepository repository;
  final String requesterId;
  ParticipantRiskReportSummary report;
  List<CaseMessage>? messages;
  String? pendingBody;
  String? error;
  bool sending = false;
  bool connected = false;
  bool available = true;
  bool _disposed = false;
  bool _sendConfirmed = false;
  Set<String> _idsBeforeSend = {};
  int _generation = 0;
  int _messageRevision = 0;
  int _reportRevision = 0;
  StreamSubscription<List<CaseMessage>>? _messagesSubscription;
  StreamSubscription<ParticipantRiskReportSummary?>? _reportSubscription;

  ParticipantRiskConversationRepository? get _conversation =>
      repository is ParticipantRiskConversationRepository
      ? repository as ParticipantRiskConversationRepository
      : null;

  bool get closed => !available || report.status.isClosed;

  Future<void> refresh() async {
    final generation = ++_generation;
    connected = false;
    error = null;
    _notify();
    await _messagesSubscription?.cancel();
    await _reportSubscription?.cancel();
    if (_disposed || generation != _generation) return;
    final live = repository;
    if (live is ParticipantRiskLiveRepository) {
      _messagesSubscription = (live as ParticipantRiskLiveRepository)
          .watchMessages(report.id)
          .listen(
            (values) {
              if (_disposed || generation != _generation) return;
              _messageRevision++;
              _receiveMessages(values);
              connected = true;
              _notify();
            },
            onError: (_) => _disconnect(generation),
            onDone: () => _disconnect(generation),
          );
      _reportSubscription = (live as ParticipantRiskLiveRepository)
          .watchReport(report.id)
          .listen(
            (value) {
              if (_disposed || generation != _generation) return;
              _reportRevision++;
              available =
                  value != null &&
                  value.id == report.id &&
                  value.orderId == report.orderId;
              if (available) report = value!;
              if (!available) error = RiskChatStrings.unavailable;
              _notify();
            },
            onError: (_) => _disconnect(generation),
            onDone: () => _disconnect(generation),
          );
    }
    final conversation = _conversation;
    if (conversation == null) {
      _disconnect(generation);
      return;
    }
    final messageRevision = _messageRevision;
    final reportRevision = _reportRevision;
    try {
      final results = await Future.wait<Object>([
        conversation.fetchMessages(report.id),
        repository.fetchForOrder(report.orderId),
      ]);
      if (_disposed || generation != _generation) return;
      if (messageRevision == _messageRevision) {
        _receiveMessages(results[0] as List<CaseMessage>);
      }
      if (reportRevision == _reportRevision) {
        final latest = (results[1] as List<ParticipantRiskReportSummary>)
            .where((value) => value.id == report.id)
            .firstOrNull;
        available = latest != null;
        if (latest != null) report = latest;
      }
      connected = true;
      if (!available) error = RiskChatStrings.unavailable;
      _notify();
    } catch (_) {
      _disconnect(generation);
    }
  }

  void _disconnect(int generation) {
    if (_disposed || generation != _generation) return;
    connected = false;
    error = RiskChatStrings.loadError;
    messages ??= [];
    _notify();
  }

  void _receiveMessages(List<CaseMessage> values) {
    messages = {
      for (final message in values)
        if (message.caseId == report.id &&
            message.visibility == CaseMessageVisibility.public)
          message.id: message,
    }.values.toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (pendingBody != null &&
        messages!.any(
          (message) =>
              !_idsBeforeSend.contains(message.id) &&
              message.senderId == requesterId &&
              message.body == pendingBody,
        )) {
      pendingBody = null;
      _sendConfirmed = true;
    }
  }

  /// true cũng bao gồm trường hợp Realtime đã xác nhận nhưng HTTP bị lỗi.
  Future<bool> send(String body) async {
    if (_disposed ||
        sending ||
        closed ||
        _conversation == null ||
        body.trim().isEmpty) {
      return false;
    }
    if (body.length > 4000) {
      error = RiskChatStrings.tooLong;
      _notify();
      return false;
    }
    sending = true;
    error = null;
    _sendConfirmed = false;
    _idsBeforeSend = {
      for (final message in messages ?? <CaseMessage>[]) message.id,
    };
    pendingBody = body.trim();
    _notify();
    try {
      await _conversation!.postMessage(report.id, pendingBody!);
      _sendConfirmed = true;
      pendingBody = null;
      if (_disposed) return true;
      final revision = _messageRevision;
      try {
        final values = await _conversation!.fetchMessages(report.id);
        if (!_disposed && revision == _messageRevision) {
          _receiveMessages(values);
        }
      } catch (_) {
        error = RiskChatStrings.sentRefreshError;
      }
      return true;
    } catch (_) {
      error = _sendConfirmed
          ? RiskChatStrings.sentRefreshError
          : RiskChatStrings.sendError;
      return _sendConfirmed;
    } finally {
      pendingBody = null;
      sending = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _messagesSubscription?.cancel();
    _reportSubscription?.cancel();
    super.dispose();
  }
}
