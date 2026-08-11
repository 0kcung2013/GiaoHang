import 'package:flutter/foundation.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

import '../data/risk_report_repository.dart';

class RiskReportFormState {
  const RiskReportFormState({
    this.step = 0,
    this.category,
    this.description = '',
    this.photos = const [],
    this.latitude,
    this.longitude,
    this.locationCapturedAt,
    this.messageIds = const [],
    this.categoryError,
    this.descriptionError,
    this.photoError,
    this.isSubmitting = false,
    this.errorMessage,
    this.result,
  });

  final int step;
  final RiskCategory? category;
  final String description;
  final List<RiskPhotoInput> photos;
  final double? latitude;
  final double? longitude;
  final DateTime? locationCapturedAt;
  final List<String> messageIds;
  final String? categoryError;
  final String? descriptionError;
  final String? photoError;
  final bool isSubmitting;
  final String? errorMessage;
  final RiskReportSubmissionResult? result;

  RiskReportFormState copyWith({
    int? step,
    RiskCategory? category,
    String? description,
    List<RiskPhotoInput>? photos,
    double? latitude,
    double? longitude,
    DateTime? locationCapturedAt,
    List<String>? messageIds,
    String? categoryError,
    String? descriptionError,
    String? photoError,
    bool? isSubmitting,
    String? errorMessage,
    RiskReportSubmissionResult? result,
    bool clearCategoryError = false,
    bool clearDescriptionError = false,
    bool clearPhotoError = false,
    bool clearErrorMessage = false,
    bool clearLocation = false,
  }) {
    return RiskReportFormState(
      step: step ?? this.step,
      category: category ?? this.category,
      description: description ?? this.description,
      photos: photos ?? this.photos,
      latitude: clearLocation ? null : latitude ?? this.latitude,
      longitude: clearLocation ? null : longitude ?? this.longitude,
      locationCapturedAt: clearLocation
          ? null
          : locationCapturedAt ?? this.locationCapturedAt,
      messageIds: messageIds ?? this.messageIds,
      categoryError: clearCategoryError
          ? null
          : categoryError ?? this.categoryError,
      descriptionError: clearDescriptionError
          ? null
          : descriptionError ?? this.descriptionError,
      photoError: clearPhotoError ? null : photoError ?? this.photoError,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
      result: result ?? this.result,
    );
  }
}

class RiskReportFormController extends ChangeNotifier {
  RiskReportFormController({
    required this.orderId,
    required ParticipantRiskReportRepository repository,
  }) : _repository = repository;

  final String orderId;
  final ParticipantRiskReportRepository _repository;
  RiskReportFormState _state = const RiskReportFormState();
  Future<RiskReportSubmissionResult?>? _inFlight;

  RiskReportFormState get state => _state;

  void selectCategory(RiskCategory category) {
    _update(_state.copyWith(category: category, clearCategoryError: true));
  }

  void setDescription(String value) {
    _update(_state.copyWith(description: value, clearDescriptionError: true));
  }

  void setPhotos(List<RiskPhotoInput> value) {
    _update(
      _state.copyWith(photos: List.unmodifiable(value), clearPhotoError: true),
    );
  }

  void setLocation({
    required double latitude,
    required double longitude,
    DateTime? capturedAt,
  }) {
    _update(
      _state.copyWith(
        latitude: latitude,
        longitude: longitude,
        locationCapturedAt: capturedAt ?? DateTime.now(),
      ),
    );
  }

  void clearLocation() => _update(_state.copyWith(clearLocation: true));

  void setMessageIds(List<String> value) {
    _update(_state.copyWith(messageIds: List.unmodifiable(value)));
  }

  bool next() {
    if (_state.step == 0 && _state.category == null) {
      _update(_state.copyWith(categoryError: 'Vui lòng chọn loại sự cố.'));
      return false;
    }
    if (_state.step == 1) {
      final descriptionValid = _state.description.trim().length >= 10;
      final photosValid = _state.photos.length <= 5;
      if (!descriptionValid || !photosValid) {
        _update(
          _state.copyWith(
            descriptionError: descriptionValid
                ? null
                : 'Mô tả cần có ít nhất 10 ký tự.',
            photoError: photosValid
                ? null
                : 'Bạn chỉ có thể chọn tối đa 5 ảnh.',
            clearDescriptionError: descriptionValid,
            clearPhotoError: photosValid,
          ),
        );
        return false;
      }
    }
    if (_state.step >= 2) return false;
    _update(_state.copyWith(step: _state.step + 1, clearErrorMessage: true));
    return true;
  }

  void back() {
    if (_state.step == 0 || _state.isSubmitting) return;
    _update(_state.copyWith(step: _state.step - 1, clearErrorMessage: true));
  }

  Future<RiskReportSubmissionResult?> submit() {
    final existing = _inFlight;
    if (existing != null) return existing;
    final future = _submitOnce();
    _inFlight = future;
    future.whenComplete(() => _inFlight = null);
    return future;
  }

  Future<RiskReportSubmissionResult?> _submitOnce() async {
    final category = _state.category;
    if (category == null || _state.description.trim().length < 10) {
      _update(
        _state.copyWith(
          categoryError: category == null ? 'Vui lòng chọn loại sự cố.' : null,
          descriptionError: _state.description.trim().length < 10
              ? 'Mô tả cần có ít nhất 10 ký tự.'
              : null,
        ),
      );
      return null;
    }

    _update(_state.copyWith(isSubmitting: true, clearErrorMessage: true));
    try {
      final result = await _repository.submit(
        ParticipantRiskReportDraft(
          orderId: orderId,
          category: category,
          description: _state.description,
          photos: _state.photos,
          latitude: _state.latitude,
          longitude: _state.longitude,
          locationCapturedAt: _state.locationCapturedAt,
          messageIds: _state.messageIds,
        ),
      );
      _update(_state.copyWith(result: result));
      return result;
    } on RiskReportRepositoryException catch (error) {
      _update(_state.copyWith(errorMessage: error.userMessage));
      return null;
    } catch (_) {
      _update(
        _state.copyWith(
          errorMessage: 'Chưa thể gửi báo cáo. Vui lòng thử lại.',
        ),
      );
      return null;
    } finally {
      _update(_state.copyWith(isSubmitting: false));
    }
  }

  void _update(RiskReportFormState value) {
    _state = value;
    notifyListeners();
  }
}
