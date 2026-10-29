import 'dart:async';

import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'refresh_on_changes.dart';

/// One revision-only Broadcast channel per client. Values always come from the
/// authorized API; Broadcast payloads (including public client messages) are never trusted.
class BusinessSettingsLive {
  BusinessSettingsLive._(this.client) {
    _changes = StreamController<void>.broadcast(
      onListen: _start,
      onCancel: _stop,
    );
  }

  static final _instances = Expando<BusinessSettingsLive>();
  factory BusinessSettingsLive(SupabaseClient client) =>
      _instances[client] ??= BusinessSettingsLive._(client);

  final SupabaseClient client;
  late final StreamController<void> _changes;
  RealtimeChannel? _channel;
  StreamSubscription<AuthState>? _auth;
  Timer? _coalesce;
  Timer? _recovery;
  int _generation = 0;

  Future<BusinessSettings> load() async => BusinessSettings.fromJson(
    Map<String, dynamic>.from(await client.rpc('get_business_settings') as Map),
  );

  Future<BusinessSettings> contact() async {
    final response = await client.functions.invoke('business-contact');
    return BusinessSettings(
      values: Map<String, dynamic>.from(response.data as Map),
    );
  }

  Stream<BusinessSettings> watch() => refreshOnChanges(_changes.stream, load);

  Stream<BusinessSettings> watchContact() =>
      refreshOnChanges(_changes.stream, contact).distinct(
        (a, b) =>
            a.companyName == b.companyName &&
            a.supportPhone == b.supportPhone &&
            a.supportEmail == b.supportEmail,
      );

  /// Also called on foreground/resume; a recovery tick covers missed messages.
  void refresh() {
    if (!_changes.hasListener || _coalesce != null) return;
    _coalesce = Timer(const Duration(milliseconds: 200), () {
      _coalesce = null;
      if (_changes.hasListener) _changes.add(null);
    });
  }

  void _start() {
    final generation = ++_generation;
    final channel = client.channel('business-settings');
    _channel = channel;
    channel
        .onBroadcast(event: 'settings_changed', callback: (_) => refresh())
        .subscribe((status, error) {
          if (generation != _generation) return;
          // Fetch after every join, including reconnect: closes fetch/join races.
          if (status == RealtimeSubscribeStatus.subscribed) refresh();
        });
    _auth = client.auth.onAuthStateChange.listen((_) => refresh());
    _recovery = Timer.periodic(const Duration(seconds: 60), (_) => refresh());
  }

  void _stop() {
    ++_generation;
    _coalesce?.cancel();
    _coalesce = null;
    _recovery?.cancel();
    _recovery = null;
    unawaited(_auth?.cancel());
    _auth = null;
    final channel = _channel;
    _channel = null;
    if (channel != null) unawaited(client.removeChannel(channel));
  }
}
