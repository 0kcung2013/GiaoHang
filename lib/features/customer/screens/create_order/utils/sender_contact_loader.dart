import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/providers/customer_providers.dart';
import 'vietnam_phone_input.dart';

class SenderContactData {
  const SenderContactData({required this.name, required this.phone});

  final String name;
  final String phone;
}

class SenderContactException implements Exception {
  const SenderContactException(this.message);

  final String message;
}

Future<SenderContactData> loadSenderContact(WidgetRef ref) async {
  final authUser = Supabase.instance.client.auth.currentUser;
  if (authUser == null) {
    throw const SenderContactException('Vui lòng đăng nhập để tạo đơn hàng.');
  }

  try {
    final profile = await ref.read(customerProfileProvider(authUser.id).future);
    final profileName = profile?.fullName.trim() ?? '';
    final profilePhone = profile?.phone?.trim() ?? '';
    final metadataName =
        authUser.userMetadata?['full_name']?.toString().trim() ?? '';
    final name = profileName.isNotEmpty ? profileName : metadataName;
    final phone = normalizeVietnamPhone(
      profilePhone.isNotEmpty ? profilePhone : (authUser.phone ?? '').trim(),
    );

    if (name.isEmpty || !isValidVietnamPhone(phone)) {
      throw const SenderContactException(
        'Thông tin người gửi chưa đầy đủ. Vui lòng bổ sung họ tên và số điện thoại trong Tài khoản.',
      );
    }

    return SenderContactData(name: name, phone: phone);
  } on SenderContactException {
    rethrow;
  } catch (_) {
    throw const SenderContactException(
      'Không tải được thông tin người gửi. Vui lòng thử lại.',
    );
  }
}
