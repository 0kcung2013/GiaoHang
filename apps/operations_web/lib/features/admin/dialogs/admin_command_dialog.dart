import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import '../constants/admin_strings.dart';
import '../models/admin_section.dart';

typedef AdminCommand = ({AdminSection section, String query});

Future<AdminCommand?> showAdminCommandDialog(BuildContext context) =>
    showDialog<AdminCommand>(
      context: context,
      builder: (_) => const _CommandDialog(),
    );

class _CommandDialog extends StatefulWidget {
  const _CommandDialog();
  @override
  State<_CommandDialog> createState() => _CommandDialogState();
}

class _CommandDialogState extends State<_CommandDialog> {
  final _text = TextEditingController();
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _searchOrders() => Navigator.pop(context, (
    section: AdminSection.orders,
    query: _text.text.trim(),
  ));
  @override
  Widget build(BuildContext context) {
    final matches = AdminSection.values
        .where(
          (s) =>
              s.label.toLowerCase().contains(_text.text.trim().toLowerCase()),
        )
        .toList();
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: AdminStrings.searchHint,
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _searchOrders(),
                    ),
                  ),
                  IconButton(
                    tooltip: AdminStrings.close,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (_text.text.trim().isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.inventory_2_rounded),
                  title: const Text(AdminStrings.searchOrders),
                  subtitle: Text(_text.text.trim()),
                  onTap: _searchOrders,
                ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final section in matches) ...[
                      if (section == matches.first ||
                          section.group !=
                              matches[matches.indexOf(section) - 1].group)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.lg,
                            AppSpacing.md,
                            AppSpacing.lg,
                            AppSpacing.xs,
                          ),
                          child: Text(
                            section.group,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ListTile(
                        leading: Icon(section.icon),
                        title: Text(section.label),
                        trailing: const Icon(
                          Icons.north_west_rounded,
                          size: 16,
                        ),
                        onTap: () => Navigator.pop(context, (
                          section: section,
                          query: '',
                        )),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
