import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:giaohang_mobile/core/models/user_model.dart';
import 'package:giaohang_mobile/features/customer/screens/account/data/customer_account_repository.dart';
import 'package:image_picker/image_picker.dart';

final customerAccountFixture = UserModel.fromJson({
  'id': 'actor-1',
  'email': 'customer@example.invalid',
  'full_name': 'Nguyễn Minh An',
  'phone': '0901234567',
  'role': 'customer',
  'created_at': '2026-10-22T00:00:00Z',
});

Future<void> loadCustomerAccountTestFonts() async {
  GoogleFonts.config.allowRuntimeFetching = false;
  final bytes = File.fromUri(
    File(
      Platform.resolvedExecutable,
    ).parent.uri.resolve('../../material_fonts/roboto-regular.ttf'),
  ).readAsBytesSync();
  const names = ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold'];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (message) async {
        final key = utf8.decode(message!.buffer.asUint8List());
        if (key == 'AssetManifest.bin') {
          return const StandardMessageCodec().encodeMessage({
            'JetBrainsMono-Medium.ttf': [
              {'asset': 'JetBrainsMono-Medium.ttf'},
            ],
            for (final name in names)
              'PlusJakartaSans-$name.ttf': [
                {'asset': 'PlusJakartaSans-$name.ttf'},
              ],
          });
        }
        if (key.endsWith('.ttf')) return ByteData.sublistView(bytes);
        return null;
      });
  for (final weight in [
    FontWeight.w400,
    FontWeight.w500,
    FontWeight.w600,
    FontWeight.w700,
    FontWeight.w800,
  ]) {
    GoogleFonts.plusJakartaSans(fontWeight: weight);
  }
  GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w500);
  await GoogleFonts.pendingFonts();
}

class FakeCustomerAccountRepository implements CustomerAccountRepository {
  UserModel profile = customerAccountFixture;
  int saves = 0;
  bool fail = false;
  Future<void> Function()? onSave;
  @override
  Future<UserModel> load() async => profile;
  @override
  Future<UserModel> save({
    required String userId,
    required String fullName,
    required String phone,
    String? avatarUrl,
  }) async {
    saves++;
    if (fail) throw Exception('offline');
    await onSave?.call();
    profile = UserModel.fromJson({
      ...profile.toJson(),
      'full_name': fullName.trim(),
      'phone': phone.trim(),
      'avatar_url': ?avatarUrl,
    });
    return profile;
  }

  @override
  Future<String> uploadAvatar(XFile file) async =>
      'r2://media/users/actor-1/avatars/photo.jpg';
}
