import 'package:flutter/material.dart';
import 'package:giaohang_design/giaohang_design.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../customer/screens/create_order/utils/address_search_result.dart';
import '../../customer/screens/create_order/utils/address_search_service.dart';
import 'dispatch_preferences_strings.dart';
import 'widgets/destination_route_map.dart';
import 'widgets/dispatch_field_decoration.dart';

class DispatchDestination {
  const DispatchDestination(this.point, this.label);
  final LatLng point;
  final String label;
}

class DestinationPickerScreen extends StatefulWidget {
  const DestinationPickerScreen({super.key, required this.origin});
  final LatLng? origin;
  @override
  State<DestinationPickerScreen> createState() =>
      _DestinationPickerScreenState();
}

class _DestinationPickerScreenState extends State<DestinationPickerScreen> {
  final _query = TextEditingController();
  final _client = http.Client();
  List<AddressSearchResult> _results = const [];
  DispatchDestination? _selection;
  bool _loading = false;
  String? _error;
  @override
  void dispose() {
    _query.dispose();
    _client.close();
    super.dispose();
  }

  Future<void> _search() async {
    if (_query.text.trim().length < 3 || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await AddressSearchService(
        client: _client,
      ).search(_query.text, proximity: widget.origin);
      if (mounted) {
        setState(() {
          _results = results;
          if (results.isEmpty) _error = DispatchPreferencesStrings.searchEmpty;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = DispatchPreferencesStrings.searchError);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bgLight,
    appBar: AppBar(
      backgroundColor: AppColors.bgLight,
      title: Text(
        DispatchPreferencesStrings.chooseDestination,
        style: AppTextStyles.headingMedium,
      ),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.screenH),
            children: [
              TextField(
                controller: _query,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                style: AppTextStyles.bodyMedium,
                decoration: dispatchFieldDecoration(
                  DispatchPreferencesStrings.search,
                  suffixIcon: IconButton(
                    tooltip: DispatchPreferencesStrings.searchAction,
                    onPressed: _loading ? null : _search,
                    icon: const Icon(Icons.search_rounded),
                  ),
                ),
              ),
              if (_loading) const LinearProgressIndicator(),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Text(_error!),
                ),
              for (final result in _results)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.location_on_rounded),
                  title: Text(result.displayAddress),
                  onTap: () {
                    FocusScope.of(context).unfocus();
                    setState(() {
                      _selection = DispatchDestination(
                        result.position,
                        result.displayAddress,
                      );
                      _results = const [];
                    });
                  },
                ),
              const SizedBox(height: AppSpacing.lg),
              DestinationRouteMap(
                origin: widget.origin,
                destination: _selection?.point,
                onTap: (point) => setState(
                  () => _selection = DispatchDestination(
                    point,
                    DispatchPreferencesStrings.coordinates(
                      point.latitude,
                      point.longitude,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                _selection?.label ?? DispatchPreferencesStrings.pickHint,
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.textOnAccent,
                  textStyle: AppTextStyles.labelLarge,
                  minimumSize: const Size.fromHeight(52),
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.lg,
                  ),
                ),
                onPressed: _selection == null
                    ? null
                    : () => Navigator.pop(context, _selection),
                child: const Text(
                  DispatchPreferencesStrings.confirmDestination,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
