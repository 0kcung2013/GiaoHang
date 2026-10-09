import 'order_contact_message.dart';

/// Merges history, realtime and send responses into one ordered conversation.
class OrderContactTimeline {
  final _messages = <OrderContactMessage>[];

  List<OrderContactMessage> get messages => List.unmodifiable(_messages);

  bool hasPersisted({
    required String clientMessageId,
    required String senderId,
  }) => _messages.any(
    (message) =>
        message.clientMessageId == clientMessageId &&
        message.senderId == senderId &&
        !message.id.startsWith('pending:'),
  );

  OrderContactMessage? get latestPersisted {
    for (final message in _messages.reversed) {
      if (!message.id.startsWith('pending:')) return message;
    }
    return null;
  }

  void merge(Iterable<OrderContactMessage> messages) {
    for (final message in messages) {
      final index = _messages.indexWhere(
        (existing) =>
            existing.id == message.id ||
            (existing.senderId == message.senderId &&
                existing.clientMessageId == message.clientMessageId),
      );
      if (index < 0) {
        _messages.add(message);
      } else if (!_messages[index].id.startsWith('pending:') &&
          message.id.startsWith('pending:')) {
        continue;
      } else {
        _messages[index] = message;
      }
    }
    _messages.sort((a, b) {
      final time = a.sentAt.compareTo(b.sentAt);
      return time != 0 ? time : a.clientMessageId.compareTo(b.clientMessageId);
    });
  }

  void removePending(String clientMessageId) {
    _messages.removeWhere(
      (message) =>
          message.clientMessageId == clientMessageId &&
          message.id.startsWith('pending:'),
    );
  }
}
