import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'single_session_guard.dart';

/// Extracts the Supabase Auth session identifier used only for local matching.
///
/// Authorization is still performed by Supabase. This helper does not verify a
/// JWT signature and must not be used as an authorization boundary.
String? sessionIdFromAccessToken(String accessToken) {
  final parts = accessToken.split('.');
  if (parts.length != 3) return null;

  try {
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    if (payload is! Map<String, dynamic>) return null;
    final sessionId = payload['session_id']?.toString();
    return sessionId == null || sessionId.isEmpty ? null : sessionId;
  } catch (_) {
    return null;
  }
}

/// Coordinates the one-active-session policy with Supabase Auth and Realtime.
class SupabaseSingleSessionController {
  SupabaseSingleSessionController({required SupabaseClient client})
    : _client = client,
      _guard = SingleSessionGuard(
        revokeOtherSessions: () =>
            client.auth.signOut(scope: SignOutScope.others),
        signOutCurrentSession: () =>
            client.auth.signOut(scope: SignOutScope.local),
      );

  static const _subscribeTimeout = Duration(seconds: 8);

  final SupabaseClient _client;
  final SingleSessionGuard _guard;

  Future<void> _pending = Future<void>.value();
  RealtimeChannel? _channel;
  String? _watchedUserId;
  String? _watchedSessionId;
  bool _disposed = false;

  Future<void> handleAuthState(AuthState state) {
    if (_disposed) return Future<void>.value();

    return _enqueue(() async {
      switch (state.event) {
        case AuthChangeEvent.signedIn:
          await _activate(state.session, claimNewSession: true);
          break;
        case AuthChangeEvent.initialSession:
        case AuthChangeEvent.tokenRefreshed:
          await _activate(state.session, claimNewSession: false);
          break;
        case AuthChangeEvent.signedOut:
          await _removeChannel();
          break;
        default:
          break;
      }
    });
  }

  Future<void> _activate(
    Session? session, {
    required bool claimNewSession,
  }) async {
    if (session == null) {
      await _removeChannel();
      return;
    }

    final sessionId = sessionIdFromAccessToken(session.accessToken);
    if (sessionId == null) {
      await _signOutIfCurrent(session.user.id, null);
      return;
    }

    try {
      if (claimNewSession) {
        final enforced = await _guard.enforce();
        if (!enforced || !_isCurrent(session.user.id, sessionId)) return;
        await _claimSession(sessionId);
      } else {
        final activeSessionId = await _fetchActiveSessionId(session.user.id);
        if (activeSessionId == null) {
          await _claimSession(sessionId);
        } else if (activeSessionId != sessionId) {
          await _signOutIfCurrent(session.user.id, sessionId);
          return;
        }
      }

      if (!_isCurrent(session.user.id, sessionId)) return;
      final subscribed = await _watchSession(session.user.id, sessionId);
      if (!subscribed) {
        await _signOutIfCurrent(session.user.id, sessionId);
        return;
      }

      // Recheck after the subscription is active to close the setup race.
      final activeSessionId = await _fetchActiveSessionId(session.user.id);
      if (activeSessionId != sessionId) {
        await _signOutIfCurrent(session.user.id, sessionId);
      }
    } catch (_) {
      await _signOutIfCurrent(session.user.id, sessionId);
    }
  }

  Future<void> _claimSession(String expectedSessionId) async {
    final result = await _client.rpc('claim_active_session');
    if (result?.toString() != expectedSessionId) {
      throw StateError('Supabase returned an unexpected active session ID.');
    }
  }

  Future<String?> _fetchActiveSessionId(String userId) async {
    final row = await _client
        .from('users')
        .select('active_session_id')
        .eq('id', userId)
        .single();
    return row['active_session_id']?.toString();
  }

  Future<bool> _watchSession(String userId, String sessionId) async {
    if (_channel != null &&
        _watchedUserId == userId &&
        _watchedSessionId == sessionId) {
      return true;
    }

    await _removeChannel();
    final ready = Completer<bool>();
    late final RealtimeChannel channel;
    channel = _client
        .channel('active-session:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'users',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: (payload) {
            final activeSessionId = payload.newRecord['active_session_id']
                ?.toString();
            if (activeSessionId != sessionId) {
              unawaited(_signOutIfCurrent(userId, sessionId));
            }
          },
        )
        .subscribe((status, error) {
          if (ready.isCompleted) return;
          if (status == RealtimeSubscribeStatus.subscribed) {
            ready.complete(true);
          } else if (status == RealtimeSubscribeStatus.channelError ||
              status == RealtimeSubscribeStatus.closed ||
              status == RealtimeSubscribeStatus.timedOut) {
            ready.complete(false);
          }
        });

    _channel = channel;
    _watchedUserId = userId;
    _watchedSessionId = sessionId;

    try {
      return await ready.future.timeout(_subscribeTimeout);
    } on TimeoutException {
      return false;
    }
  }

  bool _isCurrent(String userId, String sessionId) {
    final current = _client.auth.currentSession;
    return current?.user.id == userId &&
        sessionIdFromAccessToken(current!.accessToken) == sessionId;
  }

  Future<void> _signOutIfCurrent(
    String userId,
    String? expectedSessionId,
  ) async {
    final current = _client.auth.currentSession;
    if (current?.user.id != userId) return;
    if (expectedSessionId != null &&
        sessionIdFromAccessToken(current!.accessToken) != expectedSessionId) {
      return;
    }

    await _removeChannel();
    await _client.auth.signOut(scope: SignOutScope.local);
  }

  Future<void> _removeChannel() async {
    final channel = _channel;
    _channel = null;
    _watchedUserId = null;
    _watchedSessionId = null;
    if (channel != null) {
      await _client.removeChannel(channel);
    }
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final recovered = _pending.catchError((_) {});
    _pending = recovered.then((_) => operation());
    return _pending;
  }

  Future<void> dispose() async {
    _disposed = true;
    try {
      await _pending;
    } finally {
      await _removeChannel();
    }
  }
}
