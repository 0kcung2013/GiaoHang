import 'support_live_conversation.dart';

@Deprecated('Use SupportLiveConversation')
class SupportCaseConversation extends SupportLiveConversation {
  const SupportCaseConversation({
    required super.messages,
    required super.currentUserId,
    required super.canReply,
    required super.onSend,
    super.key,
  });
}
