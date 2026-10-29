import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:url_launcher/url_launcher.dart';

import 'auth_strings.dart';
import '../../../../core/services/business_settings_service.dart';
import 'package:giaohang_domain/giaohang_domain.dart' show BusinessSettings;

class AccountSupportContact extends StatefulWidget {
  const AccountSupportContact({super.key, this.launchEmail});

  final Future<bool> Function(Uri)? launchEmail;

  @override
  State<AccountSupportContact> createState() => _AccountSupportContactState();
}

class _AccountSupportContactState extends State<AccountSupportContact> {
  bool _opening = false;
  bool _failed = false;
  BusinessSettings? _contact;
  StreamSubscription<BusinessSettings>? _subscription;
  String get _email => _contact?.supportEmail ?? AuthStrings.supportEmail;
  @override
  void initState() {
    super.initState();
    _subscription = BusinessSettingsService().watchContact().listen(
      (contact) {
        if (mounted) setState(() => _contact = contact);
      },
      onError: (Object _) {
        /* Keep the last contact while offline. */
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _openEmail() async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _failed = false;
    });
    final uri = Uri(
      scheme: 'mailto',
      path: _email,
      query:
          {
                'subject': AuthStrings.disabledAccountSubject,
                'body': AuthStrings.disabledAccountBody,
              }.entries
              .map(
                (entry) =>
                    '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}',
              )
              .join('&'),
    );
    try {
      final opened = await (widget.launchEmail?.call(uri) ?? launchUrl(uri));
      if (mounted) setState(() => _failed = !opened);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _copyEmail() async {
    var message = AuthStrings.supportEmailCopied;
    try {
      await Clipboard.setData(ClipboardData(text: _email));
    } catch (_) {
      message = AuthStrings.supportCopyFailed;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_contact != null) ...[
        Text(_contact!.companyName, style: AppTextStyles.labelLarge),
        if (_contact!.supportPhone.isNotEmpty)
          SelectableText(
            _contact!.supportPhone,
            style: AppTextStyles.bodyMedium,
          ),
        const SizedBox(height: AppSpacing.sm),
      ],
      OutlinedButton.icon(
        onPressed: _opening ? null : _openEmail,
        icon: const Icon(Icons.mail_outline_rounded),
        label: const Text(AuthStrings.contactSupport),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accent,
          minimumSize: const Size.fromHeight(48),
          textStyle: AppTextStyles.labelLarge,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
        ),
      ),
      const SizedBox(height: AppSpacing.xs),
      Row(
        children: [
          Expanded(
            child: SelectableText(_email, style: AppTextStyles.bodyMedium),
          ),
          IconButton(
            tooltip: AuthStrings.copySupportEmail,
            onPressed: _copyEmail,
            icon: const Icon(Icons.copy_outlined),
          ),
        ],
      ),
      if (_failed)
        Semantics(
          liveRegion: true,
          child: Text(
            'Không mở được ứng dụng email. Hãy gửi yêu cầu đến $_email.',
            style: AppTextStyles.bodySmall,
          ),
        ),
    ],
  );
}
