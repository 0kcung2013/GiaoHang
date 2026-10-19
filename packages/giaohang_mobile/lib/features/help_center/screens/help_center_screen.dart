import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';

import '../../../core/mobile_app_role.dart';
import '../data/help_topics.dart';
import '../help_center_strings.dart';
import '../widgets/help_chat_card.dart';
import '../widgets/help_topic_tile.dart';
import 'support_order_picker_screen.dart';
import 'general_support_chat_screen.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({required this.role, this.onChat, super.key});

  final MobileAppRole role;
  final VoidCallback? onChat;

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _chat() {
    if (widget.onChat != null) {
      widget.onChat!();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GeneralSupportChatScreen(role: widget.role),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topics = helpTopicsFor(
      widget.role,
    ).where((topic) => topic.matches(_query)).toList();
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: Text(
          HelpCenterStrings.title,
          style: AppTextStyles.headingMedium,
        ),
        backgroundColor: AppColors.bgCard,
        surfaceTintColor: AppColors.bgCard,
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              key: const PageStorageKey('help-center-scroll'),
              padding: const EdgeInsets.all(AppSpacing.screenH),
              children: [
                HelpChatCard(onChat: _chat),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            SupportOrderPickerScreen(role: widget.role),
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      textStyle: AppTextStyles.labelMedium,
                      minimumSize: const Size(48, 48),
                    ),
                    icon: const Icon(Icons.inventory_2_outlined, size: 20),
                    label: const Text(HelpCenterStrings.orderSupport),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl2),
                Text(
                  HelpCenterStrings.questions,
                  style: AppTextStyles.headingMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  key: const Key('help-center-search'),
                  controller: _search,
                  onChanged: (value) => setState(() => _query = value),
                  style: AppTextStyles.bodyMedium,
                  decoration: InputDecoration(
                    labelText: HelpCenterStrings.search,
                    labelStyle: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: HelpCenterStrings.clearSearch,
                            onPressed: () {
                              _search.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                    filled: true,
                    fillColor: AppColors.bgCard,
                    border: const OutlineInputBorder(
                      borderRadius: AppRadius.md,
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: const OutlineInputBorder(
                      borderRadius: AppRadius.md,
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: AppRadius.md,
                      borderSide: BorderSide(color: AppColors.borderFocus),
                    ),
                  ),
                ),
                if (topics.isEmpty) ...[
                  const SizedBox(height: AppSpacing.xl2),
                  const Icon(
                    Icons.search_off_rounded,
                    color: AppColors.textSecondary,
                    size: 32,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    HelpCenterStrings.noResults,
                    style: AppTextStyles.headingSmall,
                  ),
                  Text(
                    HelpCenterStrings.noResultsHint,
                    style: AppTextStyles.bodyMedium,
                  ),
                ],
                for (var i = 0; i < topics.length; i++) ...[
                  if (i == 0 || topics[i].group != topics[i - 1].group) ...[
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      topics[i].group,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  HelpTopicTile(topic: topics[i], onChat: _chat),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
