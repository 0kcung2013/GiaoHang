import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:go_router/go_router.dart';

import '../help_center_strings.dart';

class HelpCenterButton extends StatelessWidget {
  const HelpCenterButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: HelpCenterStrings.title,
    onPressed: () => context.push('/help'),
    style: IconButton.styleFrom(
      minimumSize: const Size(48, 48),
      foregroundColor: AppColors.accent,
      backgroundColor: AppColors.accentLight,
    ),
    icon: const Icon(Icons.support_agent_rounded),
  );
}
