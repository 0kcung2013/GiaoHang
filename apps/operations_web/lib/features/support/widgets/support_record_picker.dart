import 'dart:async';

import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Search by human-readable identifiers, while the form retains database IDs.
class SupportRecordPicker extends StatefulWidget {
  const SupportRecordPicker({
    required this.onSelected,
    this.order = false,
    this.initialId,
    this.initialLabel,
    super.key,
  });
  final ValueChanged<String?> onSelected;
  final bool order;
  final String? initialId;
  final String? initialLabel;
  @override
  State<SupportRecordPicker> createState() => _SupportRecordPickerState();
}

class _SupportRecordPickerState extends State<SupportRecordPicker> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  String? _error;
  int _request = 0;
  String? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialId;
    _controller.text = widget.initialLabel ?? '';
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _search(String text) {
    widget.onSelected(null);
    _debounce?.cancel();
    final request = ++_request;
    setState(() {
      _selected = null;
      _results = [];
      _error = null;
      _loading = text.trim().length >= 2;
    });
    if (!_loading) return;
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final client = Supabase.instance.client;
        final search = text.trim().replaceAll(RegExp(r'[,()%_\\"]'), ' ');
        final rows = widget.order
            ? await client
                  .from('orders')
                  .select('id,tracking_code,recipient_name')
                  .ilike('tracking_code', '%$search%')
                  .limit(8)
            : await client
                  .from('users')
                  .select('id,full_name,phone,role')
                  .inFilter('role', ['customer', 'driver'])
                  .or('full_name.ilike.%$search%,phone.ilike.%$search%')
                  .limit(8);
        if (mounted && request == _request) {
          setState(() {
            _results = rows;
            _loading = false;
          });
        }
      } catch (_) {
        if (mounted && request == _request) {
          setState(() {
            _error = 'Không tải được kết quả. Hãy nhập lại để thử.';
            _loading = false;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextFormField(
        controller: _controller,
        onChanged: _search,
        validator: (_) => !widget.order && _selected == null
            ? 'Chọn người yêu cầu trong kết quả tìm kiếm.'
            : widget.order &&
                  _controller.text.trim().isNotEmpty &&
                  _selected == null
            ? 'Chọn đơn trong kết quả hoặc xóa tìm kiếm.'
            : null,
        decoration: InputDecoration(
          labelText: widget.order ? 'Đơn hàng (tùy chọn)' : 'Người yêu cầu *',
          hintText: widget.order
              ? 'Tìm theo mã vận đơn'
              : 'Tìm tên hoặc số điện thoại',
          errorText: _error,
          prefixIcon: const Icon(Icons.search_rounded),
          filled: true,
          fillColor: AppColors.bgLight,
        ),
      ),
      if (_loading) const LinearProgressIndicator(color: AppColors.accent),
      for (final row in _results)
        ListTile(
          dense: true,
          title: Text(
            (widget.order ? row['tracking_code'] : row['full_name']).toString(),
          ),
          subtitle: Text(
            widget.order
                ? (row['recipient_name'] ?? '').toString()
                : '${row['role'] == 'driver' ? 'Tài xế' : 'Khách hàng'} · ${row['phone'] ?? ''}',
          ),
          onTap: () {
            ++_request;
            _debounce?.cancel();
            setState(() {
              _selected = row['id'] as String;
              _results = [];
              _loading = false;
              _controller.text =
                  (widget.order ? row['tracking_code'] : row['full_name'])
                      .toString();
            });
            widget.onSelected(_selected);
          },
        ),
    ],
  );
}
