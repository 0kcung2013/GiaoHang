typedef SessionAction = Future<void> Function();

/// Áp dụng chính sách một phiên đăng nhập cho mỗi tài khoản.
///
/// Phiên đăng nhập mới sẽ thu hồi các phiên khác. Nếu không thể thu hồi,
/// guard đăng xuất phiên mới để tránh duy trì đồng thời nhiều phiên.
class SingleSessionGuard {
  SingleSessionGuard({
    required SessionAction revokeOtherSessions,
    required SessionAction signOutCurrentSession,
  }) : _revokeOtherSessions = revokeOtherSessions,
       _signOutCurrentSession = signOutCurrentSession;

  final SessionAction _revokeOtherSessions;
  final SessionAction _signOutCurrentSession;

  Future<bool>? _pendingEnforcement;

  Future<bool> enforce() {
    final pending = _pendingEnforcement;
    if (pending != null) return pending;

    late final Future<bool> tracked;
    tracked = _enforce().whenComplete(() {
      if (identical(_pendingEnforcement, tracked)) {
        _pendingEnforcement = null;
      }
    });
    _pendingEnforcement = tracked;
    return tracked;
  }

  Future<bool> _enforce() async {
    try {
      await _revokeOtherSessions();
      return true;
    } catch (_) {
      try {
        await _signOutCurrentSession();
      } catch (_) {
        // Không che lỗi ban đầu; kết quả false cho biết guard không thể áp dụng.
      }
      return false;
    }
  }
}
