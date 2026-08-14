import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../../../core/models/recent_address_model.dart';
import '../../../../../core/models/reverse_geocode_result.dart';
import '../../../../../core/models/saved_address_model.dart';
import '../../../../../core/services/reverse_geocoding_service.dart';
import '../address_picker_strings.dart';
import '../models/address_picker_result.dart';
import '../utils/address_search_result.dart';
import '../utils/address_search_service.dart';

part 'address_picker_selection.dart';

enum AddressPickerTab { map, saved, recent }

class AddressPickerController extends ChangeNotifier {
  AddressPickerController({
    required LatLng initialPosition,
    MapPickerResult? initialSelection,
    AddressSearchService? searchService,
    ReverseGeocodingService? geocodingService,
  }) : _selectedPosition = initialSelection?.position ?? initialPosition,
       _searchService = searchService ?? AddressSearchService(),
       _geocodingService = geocodingService ?? ReverseGeocodingService() {
    if (initialSelection != null) {
      _applyKnownAddress(
        position: initialSelection.position,
        formattedAddress: initialSelection.formattedAddress,
        addressDetail: initialSelection.addressDetail,
        deliveryNote: initialSelection.deliveryNote,
      );
    } else {
      scheduleMicrotask(() => fetchAddress(_selectedPosition));
    }
  }

  final mapController = MapController();
  final searchController = TextEditingController();
  final searchFocusNode = FocusNode();
  final detailController = TextEditingController();
  final noteController = TextEditingController();
  final customLabelController = TextEditingController();
  final AddressSearchService _searchService;
  final ReverseGeocodingService _geocodingService;

  Timer? _mapDebounce;
  Timer? _searchDebounce;
  Timer? _programmaticMoveTimer;
  int _resolveSerial = 0;
  int _searchSerial = 0;
  bool _isProgrammaticMove = false;
  bool _disposed = false;

  AddressPickerTab activeTab = AddressPickerTab.map;
  late LatLng _selectedPosition;
  ReverseGeocodeResult? resolvedAddress;
  List<AddressSearchResult> searchResults = const [];
  bool isResolving = true;
  bool isSearching = false;
  bool isLocating = false;
  bool isSaving = false;
  bool saveAddress = false;
  SavedAddressLabelType labelType = SavedAddressLabelType.home;
  SavedAddressModel? editingAddress;
  String? resolutionError;
  String? searchError;
  String? detailError;
  String? customLabelError;
  String? saveError;

  LatLng get selectedPosition => _selectedPosition;

  bool get canSubmit => !isResolving && !isSaving && resolvedAddress != null;

  void selectTab(AddressPickerTab value) {
    if (activeTab == value) return;
    activeTab = value;
    searchFocusNode.unfocus();
    _notify();
  }

  void setSaveAddress(bool value) {
    saveAddress = value;
    saveError = null;
    if (!value) {
      editingAddress = null;
      customLabelError = null;
    }
    _notify();
  }

  void setLabelType(SavedAddressLabelType value) {
    labelType = value;
    customLabelError = null;
    if (value != SavedAddressLabelType.other) {
      customLabelController.clear();
    }
    _notify();
  }

  void setSaving(bool value) {
    isSaving = value;
    saveError = null;
    _notify();
  }

  void setSaveError(String? value) {
    saveError = value;
    _notify();
  }

  Future<void> fetchAddress(LatLng position) async {
    final request = ++_resolveSerial;
    isResolving = true;
    resolutionError = null;
    resolvedAddress = null;
    detailError = null;
    _notify();

    try {
      final result = await _geocodingService.resolve(position);
      if (_disposed || request != _resolveSerial) return;
      resolvedAddress = result;
      isResolving = false;
      _notify();
    } catch (_) {
      if (_disposed || request != _resolveSerial) return;
      resolvedAddress = null;
      resolutionError = AddressPickerStrings.geocodeUnavailable;
      isResolving = false;
      _notify();
    }
  }

  void onMapMoved(MapEvent event) {
    if (_isProgrammaticMove) return;
    final center = mapController.camera.center;
    if (_selectedPosition == center) return;

    ++_searchSerial;
    _searchDebounce?.cancel();
    searchFocusNode.unfocus();
    detailController.clear();
    _selectedPosition = center;
    searchResults = const [];
    searchError = null;
    isSearching = false;
    isResolving = true;
    resolvedAddress = null;
    resolutionError = null;
    detailError = null;
    _notify();

    _mapDebounce?.cancel();
    _mapDebounce = Timer(
      const Duration(milliseconds: 900),
      () => fetchAddress(center),
    );
  }

  void onSearchChanged(String value) {
    _searchDebounce?.cancel();
    ++_searchSerial;
    final query = value.trim();
    if (query.length < 3) {
      searchResults = const [];
      searchError = null;
      isSearching = false;
      _notify();
      return;
    }

    searchResults = const [];
    searchError = null;
    isSearching = false;
    _notify();
    _searchDebounce = Timer(
      const Duration(milliseconds: 500),
      () => search(showValidationError: false),
    );
  }

  Future<void> search({bool showValidationError = true}) async {
    _searchDebounce?.cancel();
    final query = searchController.text.trim();
    if (query.length < 3) {
      searchResults = const [];
      searchError = showValidationError
          ? AddressPickerStrings.searchMinLength
          : null;
      isSearching = false;
      _notify();
      return;
    }

    final request = ++_searchSerial;
    isSearching = true;
    searchError = null;
    searchResults = const [];
    _notify();
    try {
      final results = await _searchService.search(
        query,
        proximity: _selectedPosition,
      );
      if (_disposed || request != _searchSerial) return;
      searchResults = results;
      searchError = results.isEmpty ? AddressPickerStrings.searchEmpty : null;
      isSearching = false;
      _notify();
    } catch (_) {
      if (_disposed || request != _searchSerial) return;
      searchResults = const [];
      searchError = AddressPickerStrings.searchUnavailable;
      isSearching = false;
      _notify();
    }
  }

  void clearSearch() {
    _searchDebounce?.cancel();
    ++_searchSerial;
    searchController.clear();
    searchResults = const [];
    searchError = null;
    isSearching = false;
    searchFocusNode.requestFocus();
    _notify();
  }

  void selectSearchResult(AddressSearchResult result) {
    _searchDebounce?.cancel();
    ++_searchSerial;
    ++_resolveSerial;
    searchFocusNode.unfocus();
    searchController.text = result.displayAddress;
    _mapDebounce?.cancel();
    _applyKnownAddress(
      position: result.position,
      formattedAddress: result.resolvedAddress.displayAddress,
      addressDetail: '',
      deliveryNote: noteController.text,
      resolved: result.resolvedAddress,
    );
    moveMapTo(result.position);
  }

  Future<String?> locateMe() async {
    if (isLocating) return null;
    isLocating = true;
    _notify();
    try {
      final permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return AddressPickerStrings.locationPermission;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (_disposed) return null;
      final location = LatLng(position.latitude, position.longitude);
      _selectedPosition = location;
      detailController.clear();
      moveMapTo(location);
      _mapDebounce?.cancel();
      await fetchAddress(location);
      return null;
    } catch (_) {
      return AddressPickerStrings.locationUnavailable;
    } finally {
      if (!_disposed) {
        isLocating = false;
        _notify();
      }
    }
  }

  void moveMapTo(LatLng position) {
    _isProgrammaticMove = true;
    try {
      mapController.move(position, 18);
    } catch (_) {
      // Map có thể chưa mount khi item được chọn trong frame đầu tiên.
    }
    _programmaticMoveTimer?.cancel();
    _programmaticMoveTimer = Timer(const Duration(milliseconds: 300), () {
      _isProgrammaticMove = false;
    });
  }

  void _applyKnownAddress({
    required LatLng position,
    required String formattedAddress,
    required String addressDetail,
    required String deliveryNote,
    ReverseGeocodeResult? resolved,
  }) {
    _selectedPosition = position;
    resolvedAddress =
        resolved ??
        ReverseGeocodeResult(
          displayAddress: formattedAddress,
          rawDisplayName: formattedAddress,
          houseNumber: _inferHouseNumber(formattedAddress),
        );
    detailController.text = addressDetail;
    noteController.text = deliveryNote;
    searchResults = const [];
    searchError = null;
    resolutionError = null;
    detailError = null;
    isSearching = false;
    isResolving = false;
    activeTab = AddressPickerTab.map;
    _notify();
  }

  String? _inferHouseNumber(String address) {
    final firstPart = address.split(',').first.trim();
    final match = RegExp(r'\b\d+[A-Za-z0-9/-]*\b').firstMatch(firstPart);
    return match?.group(0);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _mapDebounce?.cancel();
    _searchDebounce?.cancel();
    _programmaticMoveTimer?.cancel();
    searchController.dispose();
    searchFocusNode.dispose();
    detailController.dispose();
    noteController.dispose();
    customLabelController.dispose();
    _searchService.dispose();
    _geocodingService.dispose();
    super.dispose();
  }
}
