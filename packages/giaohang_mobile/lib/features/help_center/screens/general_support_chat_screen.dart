import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/mobile_app_role.dart';
import '../../order_help/data/customer_support_ticket_repository.dart';
import '../../order_help/widgets/support_chat/support_chat_sheet.dart';
import '../help_center_strings.dart';

class GeneralSupportChatScreen extends StatefulWidget {
  const GeneralSupportChatScreen({
    required this.role,
    this.repository,
    this.requesterId,
    super.key,
  });

  final MobileAppRole role;
  final ParticipantGeneralSupportTicketRepository? repository;
  final String? requesterId;

  @override
  State<GeneralSupportChatScreen> createState() =>
      _GeneralSupportChatScreenState();
}

class _GeneralSupportChatScreenState extends State<GeneralSupportChatScreen> {
  late final _repository =
      widget.repository ?? SupabaseParticipantSupportTicketRepository();
  late final _requesterId =
      widget.requesterId ?? Supabase.instance.client.auth.currentUser?.id;
  late Future<SupportTicket?> _conversation = _load();

  Future<SupportTicket?> _load() async {
    if (_requesterId == null) return null;
    final tickets =
        (await _repository.fetchGeneralTickets())
            .where(
              (ticket) =>
                  ticket.requesterId == _requesterId &&
                  ticket.orderId == null &&
                  !ticket.isMonitoring,
            )
            .toList()
          ..sort((left, right) {
            if (left.status.isClosed != right.status.isClosed) {
              return left.status.isClosed ? 1 : -1;
            }
            return right.updatedAt.compareTo(left.updatedAt);
          });
    return tickets.firstOrNull;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bgLight,
    body: SafeArea(
      child: FutureBuilder<SupportTicket?>(
        future: _conversation,
        builder: (context, snapshot) {
          if (_requesterId == null) return _message(HelpCenterStrings.signIn);
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            );
          }
          if (snapshot.hasError) {
            return _message(HelpCenterStrings.generalLoadError, retry: true);
          }
          return SupportChatSheet(
            requesterId: _requesterId,
            requesterRole: widget.role.name,
            subject: snapshot.data?.subject ?? HelpCenterStrings.subject,
            priority: snapshot.data?.priority ?? SupportTicketPriority.normal,
            repository: _repository,
            initialTicket: snapshot.data,
            embedded: true,
          );
        },
      ),
    ),
  );

  Widget _message(String message, {bool retry = false}) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.support_agent_rounded,
            color: AppColors.accent,
            size: 40,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            message,
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
          if (retry)
            TextButton(
              onPressed: () => setState(() {
                _conversation = _load();
              }),
              child: const Text(HelpCenterStrings.retry),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(HelpCenterStrings.close),
          ),
        ],
      ),
    ),
  );
}
