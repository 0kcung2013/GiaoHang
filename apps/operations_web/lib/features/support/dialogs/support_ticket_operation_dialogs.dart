import 'package:flutter/material.dart';
import 'support_resolution_dialog.dart';

export 'support_risk_conversion_dialog.dart'
    show SupportRiskConversionDraft, showSupportRiskConversionDialog;

Future<String?> showSupportResolutionDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (_) => const SupportResolutionDialog(),
  );
}
