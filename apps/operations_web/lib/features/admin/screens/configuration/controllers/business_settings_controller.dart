import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/business_settings_repository.dart';
import '../models/settings_fields.dart';
import '../settings_strings.dart';

class BusinessSettingsController extends ChangeNotifier {
  BusinessSettingsController(
    this.repository, {
    Stream<BusinessSettings>? updates,
  }) {
    _subscription = updates?.listen(
      _receive,
      onError: (Object _) {
        syncError = SettingsStrings.syncError;
        notifyListeners();
      },
    );
  }
  StreamSubscription<BusinessSettings>? _subscription;
  BusinessSettings? newer;
  BusinessSettings? _queued;
  String? syncError;
  bool _historyRefreshPending = false;
  final BusinessSettingsRepository repository;
  BusinessSettings? current;
  final texts = <String, String>{};
  final history = <SettingsRevision>[];
  String reason = '';
  String? error, historyError, message;
  bool loading = false, saving = false, historyLoading = false;
  bool moreHistory = false, attempted = false;
  int formGeneration = 0;
  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    super.dispose();
  }

  void _receive(BusinessSettings settings) {
    if (_disposed) return;
    syncError = null;
    if (settings.revision <= (current?.revision ?? -1)) {
      notifyListeners();
      return;
    }
    if (loading || saving) {
      if (settings.revision > (_queued?.revision ?? -1)) _queued = settings;
      return;
    }
    if (dirty || reason.trim().isNotEmpty) {
      if (settings.revision > (newer?.revision ?? -1)) newer = settings;
    } else {
      current = settings;
      newer = null;
      useValues(settings.values);
    }
    unawaited(loadHistory());
    notifyListeners();
  }

  void _drainUpdates() {
    final queued = _queued;
    _queued = null;
    if (queued != null) _receive(queued);
  }

  bool isFieldChanged(SettingsField field) =>
      current != null &&
      texts[field.key] != field.display(current!.values[field.key]!);

  Iterable<SettingsField> get changedFields =>
      settingsFields.where(isFieldChanged);
  bool get dirty => changedFields.isNotEmpty;
  int changesIn(SettingsGroup group) =>
      group.fields.where(isFieldChanged).length;

  Iterable<SettingsField> get invalidFields => settingsFields.where(
    (field) => field.validate(texts[field.key] ?? '') != null,
  );

  String? get relationsError => invalidFields.isNotEmpty
      ? null
      : validateSettingsRelations({
          for (final f in settingsFields) f.key: f.parse(texts[f.key] ?? ''),
        });

  Map<String, dynamic>? get validValues {
    final values = <String, dynamic>{};
    for (final field in settingsFields) {
      final text = texts[field.key] ?? '';
      if (field.validate(text) != null) return null;
      values[field.key] = field.parse(text);
    }
    return validateSettingsRelations(values) == null ? values : null;
  }

  void edit(String key, String text) {
    texts[key] = text;
    message = null;
    notifyListeners();
  }

  BusinessSettings? get draftPricing {
    if (current == null) return null;
    final values = Map<String, dynamic>.from(current!.asSingleRate().values);
    for (final key in pricingFieldKeys) {
      final field = settingsFields.firstWhere((f) => f.key == key);
      final text = texts[key] ?? '';
      if (field.validate(text) != null) return null;
      values[key] = field.parse(text);
    }
    return BusinessSettings(revision: current!.revision, values: values);
  }

  bool get pricingChanged =>
      current != null &&
      draftPricing != null &&
      (current!.usesLegacyPricing ||
          pricingFieldKeys.any(
            (key) => current!.values[key] != draftPricing!.values[key],
          ));

  void useValues(Map<String, dynamic> values) {
    for (final f in settingsFields) {
      texts[f.key] = f.display(values[f.key]!);
    }
    reason = '';
    attempted = false;
    formGeneration++;
    notifyListeners();
  }

  Future<void> load() async {
    if (loading || saving) return;
    loading = true;
    error = message = null;
    notifyListeners();
    try {
      var loaded = await repository.load();
      for (final candidate in [current, newer, _queued]) {
        if (candidate != null && candidate.revision > loaded.revision) {
          loaded = candidate;
        }
      }
      current = loaded;
      newer = _queued = null;
      syncError = null;
      useValues(current!.values);
    } catch (_) {
      error = SettingsStrings.loadError;
    }
    loading = false;
    _drainUpdates();
    notifyListeners();
  }

  Future<void> loadHistory({bool more = false}) async {
    if (historyLoading) {
      if (!more) _historyRefreshPending = true;
      return;
    }
    historyLoading = true;
    historyError = null;
    notifyListeners();
    try {
      final rows = await repository.history(
        beforeRevision: more && history.isNotEmpty
            ? history.last.settings.revision
            : null,
      );
      if (!more) history.clear();
      history.addAll(rows);
      moreHistory = rows.length == 20;
    } catch (_) {
      historyError = SettingsStrings.historyError;
    }
    historyLoading = false;
    notifyListeners();
    if (_historyRefreshPending && !_disposed) {
      _historyRefreshPending = false;
      unawaited(loadHistory());
    }
  }

  void restore(SettingsRevision revision) {
    useValues(revision.settings.values);
    message = revision.settings.usesLegacyPricing
        ? SettingsStrings.restoreLegacyHint
        : SettingsStrings.restoreHint;
    notifyListeners();
  }

  Future<bool> save() async {
    if (saving || loading || current == null || !dirty || newer != null) {
      return false;
    }
    attempted = true;
    final values = validValues;
    if (values == null ||
        reason.trim().length < 5 ||
        reason.trim().length > 500) {
      error = values == null
          ? 'Kiểm tra các giá trị và điều kiện giữa các trường.'
          : SettingsStrings.reasonError;
      notifyListeners();
      return false;
    }
    saving = true;
    error = message = null;
    notifyListeners();
    var success = false;
    try {
      current = await repository.save(
        BusinessSettings(revision: current!.revision, values: values),
        reason,
      );
      useValues(current!.values);
      message = SettingsStrings.saved;
      success = true;
    } on PostgrestException catch (e) {
      error = e.message == 'SETTINGS_CONFLICT'
          ? SettingsStrings.conflict
          : SettingsStrings.saveError;
    } catch (_) {
      error = SettingsStrings.saveError;
    }
    saving = false;
    _drainUpdates();
    notifyListeners();
    if (success) await loadHistory();
    return success;
  }
}
