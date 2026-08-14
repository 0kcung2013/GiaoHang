import 'package:flutter/material.dart';

import '../../support/widgets/support_workspace_scaffold.dart';

import 'risk_reports_view.dart';

class SupportRiskReportsScreen extends StatelessWidget {
  const SupportRiskReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SupportWorkspaceScaffold(
      activeSection: SupportWorkspaceSection.risks,
      body: RiskReportsView(isAdmin: false),
    );
  }
}
