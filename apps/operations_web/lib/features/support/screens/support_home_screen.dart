import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:giaohang_design/giaohang_design.dart';

class SupportHomeScreen extends StatefulWidget {
  const SupportHomeScreen({super.key});

  @override
  State<SupportHomeScreen> createState() => _SupportHomeScreenState();
}

class _SupportHomeScreenState extends State<SupportHomeScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _tickets = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _supabase
          .from('support_tickets')
          .select(
            'id, order_id, customer_id, subject, message, resolution, status, priority, created_at, updated_at',
          )
          .order('updated_at', ascending: false);
      if (mounted) {
        setState(() {
          _tickets = List<Map<String, dynamic>>.from(rows);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Không thể tải yêu cầu hỗ trợ.';
        });
      }
    }
  }

  Future<void> _updateStatus(Map<String, dynamic> ticket, String status) async {
    await _supabase
        .from('support_tickets')
        .update({'status': status})
        .eq('id', ticket['id']);
    await _loadTickets();
  }

  Future<void> _createTicket() async {
    final result = await showDialog<_SupportTicketDraft>(
      context: context,
      builder: (_) => const _CreateSupportTicketDialog(),
    );
    if (result == null || !mounted) return;
    try {
      await _supabase.from('support_tickets').insert({
        'customer_id': result.customerId,
        'created_by': _supabase.auth.currentUser!.id,
        'order_id': result.orderId.isEmpty ? null : result.orderId,
        'subject': result.subject,
        'message': result.message,
        'priority': result.priority,
      });
      await _loadTickets();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Không tạo được yêu cầu. Kiểm tra mã khách hàng/đơn hàng.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: const Text('CSKH / Support'),
        backgroundColor: AppColors.bgCard,
        surfaceTintColor: AppColors.bgCard,
        actions: [
          IconButton(
            tooltip: 'Báo cáo rủi ro',
            onPressed: () => context.push('/support-risk'),
            icon: const Icon(Icons.gpp_maybe_outlined),
          ),
          IconButton(
            tooltip: 'Ghi nhận hỗ trợ',
            onPressed: _createTicket,
            icon: const Icon(Icons.add_comment_outlined),
          ),
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: () async {
              await _supabase.auth.signOut();
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadTickets,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!),
                  ),
                ],
              )
            : _tickets.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 180),
                  Center(child: Text('Chưa có yêu cầu hỗ trợ.')),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.screenH),
                itemCount: _tickets.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, index) => _TicketCard(
                  ticket: _tickets[index],
                  onStatusChanged: (status) =>
                      _updateStatus(_tickets[index], status),
                ),
              ),
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket, required this.onStatusChanged});
  final Map<String, dynamic> ticket;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final status = ticket['status']?.toString() ?? 'open';
    final color = switch (status) {
      'resolved' || 'closed' => AppColors.success,
      'in_progress' => AppColors.primary,
      _ => AppColors.warning,
    };
    return Card(
      elevation: 0,
      color: AppColors.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.lg,
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ticket['subject']?.toString() ?? '',
                    style: AppTextStyles.headingSmall,
                  ),
                ),
                _StatusMenu(
                  status: status,
                  color: color,
                  onChanged: onStatusChanged,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              ticket['message']?.toString() ?? '',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 10),
            Text(
              'Khách: ${ticket['customer_id']}\nĐơn: ${ticket['order_id'] ?? 'Chưa gắn đơn'}',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if ((ticket['resolution']?.toString() ?? '').isNotEmpty) ...[
              const Divider(height: 20),
              Text(
                'Kết quả: ${ticket['resolution']}',
                style: AppTextStyles.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusMenu extends StatelessWidget {
  const _StatusMenu({
    required this.status,
    required this.color,
    required this.onChanged,
  });
  final String status;
  final Color color;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    onSelected: onChanged,
    child: Chip(
      label: Text(status),
      labelStyle: TextStyle(color: color, fontSize: 12),
      backgroundColor: color.withValues(alpha: .1),
    ),
    itemBuilder: (_) => const [
      PopupMenuItem(value: 'open', child: Text('Mở')),
      PopupMenuItem(value: 'in_progress', child: Text('Đang xử lý')),
      PopupMenuItem(value: 'resolved', child: Text('Đã xử lý')),
      PopupMenuItem(value: 'closed', child: Text('Đóng')),
    ],
  );
}

class _SupportTicketDraft {
  const _SupportTicketDraft({
    required this.customerId,
    required this.orderId,
    required this.subject,
    required this.message,
    required this.priority,
  });
  final String customerId, orderId, subject, message, priority;
}

class _CreateSupportTicketDialog extends StatefulWidget {
  const _CreateSupportTicketDialog();
  @override
  State<_CreateSupportTicketDialog> createState() =>
      _CreateSupportTicketDialogState();
}

class _CreateSupportTicketDialogState
    extends State<_CreateSupportTicketDialog> {
  final _customer = TextEditingController();
  final _order = TextEditingController();
  final _subject = TextEditingController();
  final _message = TextEditingController();
  String _priority = 'normal';
  @override
  void dispose() {
    _customer.dispose();
    _order.dispose();
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Ghi nhận hỗ trợ'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _customer,
            decoration: const InputDecoration(labelText: 'Mã khách hàng *'),
          ),
          TextField(
            controller: _order,
            decoration: const InputDecoration(
              labelText: 'Mã đơn hàng (tuỳ chọn)',
            ),
          ),
          TextField(
            controller: _subject,
            decoration: const InputDecoration(labelText: 'Chủ đề *'),
          ),
          TextField(
            controller: _message,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Nội dung *'),
          ),
          DropdownButtonFormField(
            initialValue: _priority,
            items: const [
              DropdownMenuItem(value: 'low', child: Text('Thấp')),
              DropdownMenuItem(value: 'normal', child: Text('Bình thường')),
              DropdownMenuItem(value: 'high', child: Text('Cao')),
            ],
            onChanged: (v) => setState(() => _priority = v!),
            decoration: const InputDecoration(labelText: 'Ưu tiên'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Huỷ'),
      ),
      FilledButton(
        onPressed: () {
          if (_customer.text.trim().isEmpty ||
              _subject.text.trim().isEmpty ||
              _message.text.trim().isEmpty) {
            return;
          }
          Navigator.pop(
            context,
            _SupportTicketDraft(
              customerId: _customer.text.trim(),
              orderId: _order.text.trim(),
              subject: _subject.text.trim(),
              message: _message.text.trim(),
              priority: _priority,
            ),
          );
        },
        child: const Text('Lưu'),
      ),
    ],
  );
}
