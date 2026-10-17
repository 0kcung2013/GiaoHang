import 'dart:math' as math;

abstract final class ReturnCompletionGuard {
  static const double maxDistanceMeters = 150;
  static const double _earthRadiusMeters = 6371000;

  static double distanceMeters({
    required double currentLat,
    required double currentLng,
    required double destinationLat,
    required double destinationLng,
  }) {
    final lat1 = _radians(currentLat);
    final lat2 = _radians(destinationLat);
    final deltaLat = _radians(destinationLat - currentLat);
    final deltaLng = _radians(destinationLng - currentLng);
    final a =
        math.sin(deltaLat / 2) * math.sin(deltaLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(deltaLng / 2) *
            math.sin(deltaLng / 2);
    final arc = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return _earthRadiusMeters * arc;
  }

  static bool canComplete(double? distance) =>
      distance != null && distance <= maxDistanceMeters;

  static String blockedMessage(double? distance) {
    if (distance == null) {
      return 'Cập nhật vị trí để xác nhận bạn đã đến điểm trả.';
    }
    return 'Bạn còn cách điểm trả khoảng ${_formatDistance(distance)}. '
        'Hãy di chuyển vào phạm vi 150 m.';
  }

  static String compactBlockedMessage(double? distance) {
    if (distance == null) {
      return 'Gạt để mở xác nhận ảnh • GPS kiểm tra trong phạm vi 150 m';
    }
    return 'Còn ${_formatDistance(distance)} • '
        'Gạt để mở xác nhận ảnh tại điểm trả';
  }

  static String userMessage(Object error) {
    final value = error.toString();
    if (value.contains('RETURN_OUTSIDE_GEOFENCE')) {
      return 'Bạn chưa ở điểm trả. Hãy di chuyển vào phạm vi 150 m rồi thử lại.';
    }
    if (value.contains('RETURN_PROOF_REQUIRED')) {
      return 'Cần chụp ảnh bàn giao tại điểm trả trước khi hoàn tất.';
    }
    if (value.contains('RETURN_RECEIVER_REQUIRED')) {
      return 'Vui lòng nhập đúng tên người tiếp nhận hàng.';
    }
    if (value.contains('INVALID_RETURN_COMPLETE_STATE')) {
      return 'Chuyến hoàn chưa ở trạng thái có thể xác nhận.';
    }
    if (value.contains('DRIVER_NOT_ASSIGNED')) {
      return 'Bạn không phải tài xế được phân công cho chuyến hoàn này.';
    }
    if (value.contains('AUTH_REQUIRED')) {
      return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
    }
    return 'Chưa thể hoàn tất đơn. Vui lòng kiểm tra kết nối và thử lại.';
  }

  static String _formatDistance(double distance) {
    if (distance < 1000) return '${distance.round()} m';
    return '${(distance / 1000).toStringAsFixed(1)} km';
  }

  static double _radians(double degrees) => degrees * math.pi / 180;
}
