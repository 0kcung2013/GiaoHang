import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/business_settings_service.dart';

class BusinessContactCard extends StatefulWidget {
  const BusinessContactCard({super.key});
  @override
  State<BusinessContactCard> createState() => _BusinessContactCardState();
}

class _BusinessContactCardState extends State<BusinessContactCard> {
  late final Stream<BusinessSettings> _contact = BusinessSettingsService()
      .watchContact()
      .handleError((Object _) {
        /* Keep the last contact offline. */
      });
  static const _unavailable =
      'Không mở được ứng dụng liên hệ. Bạn có thể sao chép thông tin bên dưới.';

  Future<void> _open(Uri uri) async {
    try {
      if (await launchUrl(uri)) return;
    } catch (_) {
      /* Show the contact text below. */
    }
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(_unavailable)));
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<BusinessSettings>(
    stream: _contact,
    builder: (context, snapshot) {
      final contact = snapshot.data;
      if (contact == null) return const SizedBox.shrink();
      return Container(
        margin: const EdgeInsets.only(top: AppSpacing.xl),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: AppRadius.lg,
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(contact.companyName, style: AppTextStyles.headingSmall),
            const SizedBox(height: AppSpacing.sm),
            if (contact.supportPhone.isNotEmpty)
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  IconButton(
                    onPressed: () =>
                        _open(Uri(scheme: 'tel', path: contact.supportPhone)),
                    tooltip: contact.supportPhone,
                    icon: const Icon(Icons.phone_outlined),
                  ),
                  SelectableText(
                    contact.supportPhone,
                    style: AppTextStyles.bodyMedium,
                  ),
                ],
              ),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                IconButton(
                  onPressed: () =>
                      _open(Uri(scheme: 'mailto', path: contact.supportEmail)),
                  tooltip: contact.supportEmail,
                  icon: const Icon(Icons.mail_outline_rounded),
                ),
                SelectableText(
                  contact.supportEmail,
                  style: AppTextStyles.bodyMedium,
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
