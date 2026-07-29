import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../../../core/constants/app_theme.dart';
import '../utils/reverse_geocode_result.dart';
import '../utils/reverse_geocoding_service.dart';

part 'map_picker_components.dart';

class MapPickerResult {
  final LatLng position;
  final String address;

  const MapPickerResult({required this.position, required this.address});
}

class MapPickerSheet extends StatefulWidget {
  final LatLng initialPosition;
  final String title;

  const MapPickerSheet({
    super.key,
    required this.initialPosition,
    this.title = 'Chọn vị trí',
  });

  @override
  State<MapPickerSheet> createState() => _MapPickerSheetState();
}

class _MapPickerSheetState extends State<MapPickerSheet> {
  final _mapController = MapController();
  final _detailController = TextEditingController();
  final _geocodingService = ReverseGeocodingService();

  late LatLng _selectedPosition;
  ReverseGeocodeResult? _resolvedAddress;
  Timer? _debounceTimer;
  int _requestSerial = 0;
  bool _isLocating = false;
  bool _isResolving = true;
  String? _resolutionError;
  String? _detailError;

  @override
  void initState() {
    super.initState();
    _selectedPosition = widget.initialPosition;
    _fetchAddress(_selectedPosition);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _detailController.dispose();
    _geocodingService.dispose();
    super.dispose();
  }

  Future<void> _fetchAddress(LatLng position) async {
    final request = ++_requestSerial;
    if (mounted) {
      setState(() {
        _isResolving = true;
        _resolutionError = null;
        _detailError = null;
      });
    }

    try {
      final result = await _geocodingService.resolve(position);
      if (!mounted || request != _requestSerial) return;
      setState(() {
        _resolvedAddress = result;
        _isResolving = false;
      });
    } catch (_) {
      if (!mounted || request != _requestSerial) return;
      final coordinates =
          '${position.latitude.toStringAsFixed(6)}, '
          '${position.longitude.toStringAsFixed(6)}';
      setState(() {
        _resolvedAddress = ReverseGeocodeResult(
          displayAddress: coordinates,
          rawDisplayName: coordinates,
        );
        _resolutionError =
            'Không đọc được địa chỉ tự động. Ghim vẫn chính xác; hãy nhập mô tả vị trí bên dưới.';
        _isResolving = false;
      });
    }
  }

  void _onMapMoved(MapEvent event) {
    final center = _mapController.camera.center;
    if (_selectedPosition == center) return;

    if (_detailController.text.isNotEmpty) {
      _detailController.clear();
    }
    setState(() {
      _selectedPosition = center;
      _isResolving = true;
      _detailError = null;
    });
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1100), () {
      _fetchAddress(center);
    });
  }

  Future<void> _locateMe() async {
    if (_isLocating) return;
    setState(() => _isLocating = true);

    try {
      final permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        _showMessage(
          'Hãy cấp quyền vị trí để dùng vị trí hiện tại.',
          isError: true,
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (!mounted) return;

      final location = LatLng(position.latitude, position.longitude);
      _selectedPosition = location;
      _mapController.move(location, 18);
      _debounceTimer?.cancel();
      await _fetchAddress(location);
    } catch (_) {
      _showMessage(
        'Không thể lấy vị trí hiện tại. Hãy kiểm tra GPS và thử lại.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _confirmLocation() {
    if (_isResolving || _resolvedAddress == null) return;

    final detail = _detailController.text.trim();
    if (!_resolvedAddress!.hasHouseNumber && detail.isEmpty) {
      setState(() {
        _detailError =
            'Nhập số nhà, tên tòa nhà hoặc mô tả điểm đón để tài xế tìm đúng.';
      });
      return;
    }

    Navigator.pop(
      context,
      MapPickerResult(
        position: _selectedPosition,
        address: _resolvedAddress!.addressWithDetail(detail),
      ),
    );
  }

  void _showMessage(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.94,
      minChildSize: 0.65,
      maxChildSize: 0.97,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _SheetHeader(
                title: widget.title,
                onClose: () => Navigator.pop(context),
              ),
              Expanded(
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: widget.initialPosition,
                        initialZoom: 18,
                        minZoom: 5,
                        maxZoom: 19,
                        onMapEvent: _onMapMoved,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.datn.giaohang',
                          maxNativeZoom: 19,
                        ),
                        SimpleAttributionWidget(
                          source: Text(
                            'OpenStreetMap contributors',
                            style: AppTextStyles.labelSmall.copyWith(
                              fontSize: 9,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          backgroundColor: AppColors.bgCard.withValues(
                            alpha: 0.85,
                          ),
                        ),
                      ],
                    ),
                    const IgnorePointer(
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.only(bottom: 36),
                          child: Icon(
                            Icons.location_on_rounded,
                            color: AppColors.accent,
                            size: 46,
                            shadows: AppShadow.card,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: AppSpacing.md,
                      left: AppSpacing.md,
                      child: _MapHint(isResolving: _isResolving),
                    ),
                    Positioned(
                      right: AppSpacing.md,
                      bottom: AppSpacing.md,
                      child: FloatingActionButton.small(
                        heroTag: 'locate_me',
                        elevation: 2,
                        backgroundColor: AppColors.bgCard,
                        onPressed: _isLocating ? null : _locateMe,
                        child: _isLocating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.accent,
                                ),
                              )
                            : const Icon(
                                Icons.my_location_rounded,
                                color: AppColors.accent,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              _AddressConfirmationPanel(
                resolvedAddress: _resolvedAddress,
                isResolving: _isResolving,
                resolutionError: _resolutionError,
                detailController: _detailController,
                detailError: _detailError,
                onDetailChanged: (_) {
                  if (_detailError != null) {
                    setState(() => _detailError = null);
                  }
                },
                onConfirm: _confirmLocation,
              ),
            ],
          ),
        );
      },
    );
  }
}
