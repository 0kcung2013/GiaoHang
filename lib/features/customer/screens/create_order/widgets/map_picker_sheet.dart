import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../../../../core/constants/app_theme.dart';

class MapPickerSheet extends StatefulWidget {
  final LatLng initialPosition;

  const MapPickerSheet({super.key, required this.initialPosition});

  @override
  State<MapPickerSheet> createState() => _MapPickerSheetState();
}

class _MapPickerSheetState extends State<MapPickerSheet> {
  final _mapController = MapController();
  late LatLng _selectedPosition;
  String _addressText = 'Đang tải địa chỉ...';

  @override
  void initState() {
    super.initState();
    _selectedPosition = widget.initialPosition;
    _fetchAddress(_selectedPosition);
  }

  Future<void> _fetchAddress(LatLng pos) async {
    setState(() => _addressText = 'Đang tải địa chỉ...');
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=json&lat=${pos.latitude}&lon=${pos.longitude}&accept-language=vi',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final displayName = data['display_name'] as String?;
        setState(() => _addressText = displayName ?? 'Không rõ địa chỉ');
      } else {
        setState(() => _addressText = 'Không lấy được địa chỉ');
      }
    } catch (_) {
      setState(() => _addressText = 'Không lấy được địa chỉ');
    }
  }

  void _onMapMoved(MapEvent event) {
    final center = _mapController.camera.center;
    if (_selectedPosition != center) {
      _selectedPosition = center;
      _fetchAddress(center);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: AppRadius.full,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.map_rounded, color: AppColors.accent, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Chọn vị trí trên bản đồ',
                      style: AppTextStyles.headingSmall.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.bgLight,
                          borderRadius: AppRadius.sm,
                        ),
                        child: const Icon(Icons.close_rounded, size: 18, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: widget.initialPosition,
                        initialZoom: 16,
                        onMapEvent: _onMapMoved,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.datn.giaohang',
                          subdomains: const ['a', 'b', 'c'],
                          maxNativeZoom: 19,
                        ),
                      ],
                    ),
                    const IgnorePointer(
                      child: Center(
                        child: Icon(
                          Icons.location_on_rounded,
                          color: AppColors.error,
                          size: 40,
                          shadows: AppShadow.subtle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: const BoxDecoration(
                  color: AppColors.bgCard,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Vị trí đã chọn',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _addressText,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${_selectedPosition.latitude.toStringAsFixed(6)}, ${_selectedPosition.longitude.toStringAsFixed(6)}',
                      style: AppTextStyles.mono.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      height: 48,
                      child: Material(
                        color: AppColors.accent,
                        borderRadius: AppRadius.full,
                        child: InkWell(
                          borderRadius: AppRadius.full,
                          onTap: () => Navigator.pop(context, _selectedPosition),
                          child: Center(
                            child: Text(
                              'Xác nhận vị trí này',
                              style: AppTextStyles.labelLarge.copyWith(
                                color: AppColors.textOnAccent,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
