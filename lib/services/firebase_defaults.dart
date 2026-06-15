import 'package:firebase_database/firebase_database.dart';

Future<void> ensureFirebaseDefaults() async {
  final database = FirebaseDatabase.instance;
  await Future.wait([
    _ensureSettingsDefaults(database.ref('settings')),
    _ensureControlDefaults(database.ref('control')),
  ]);
}

Future<void> _ensureSettingsDefaults(DatabaseReference settingsRef) async {
  final snapshot = await settingsRef.get();
  final raw = snapshot.value;
  final data = raw is Map ? Map<String, dynamic>.from(raw) : {};
  final notificationsRaw = data['notifications'];
  final notifications = notificationsRaw is Map
      ? Map<String, dynamic>.from(notificationsRaw)
      : <String, dynamic>{};

  final updates = <String, Object>{};
  void setIfMissing(String key, Object value) {
    if (!data.containsKey(key) || data[key] == null) updates[key] = value;
  }

  void setNotificationIfMissing(String key, bool value) {
    if (!notifications.containsKey(key) || notifications[key] == null) {
      updates['notifications/$key'] = value;
    }
  }

  setIfMissing('feed_limit', 500);
  setIfMissing('water_limit', 500);
  setIfMissing('fill_percent', 100);
  setIfMissing('refill_percent', 10);
  setNotificationIfMissing('stock_alert', true);
  setNotificationIfMissing('temperature_alert', true);
  setNotificationIfMissing('schedule_confirmation', true);
  setNotificationIfMissing('offline_alert', true);

  if (updates.isNotEmpty) await settingsRef.update(updates);
}

Future<void> _ensureControlDefaults(DatabaseReference controlRef) async {
  final snapshot = await controlRef.get();
  final raw = snapshot.value;
  final data = raw is Map ? Map<String, dynamic>.from(raw) : {};
  final updates = <String, Object>{};

  void setIfMissing(String key, Object value) {
    if (!data.containsKey(key) || data[key] == null) updates[key] = value;
  }

  setIfMissing('portion', 0);
  setIfMissing('feed_amount', 0);
  setIfMissing('pakan_amount', 0);
  setIfMissing('water_volume', 0);
  setIfMissing('water_amount', 0);
  setIfMissing('air_volume', 0);
  setIfMissing('manual_feed', false);
  setIfMissing('manual_water', false);
  setIfMissing('reload_sched', false);
  setIfMissing('auto_refill_target', '');
  setIfMissing('auto_refill_amount', 0);
  setIfMissing('auto_refill_request_id', '');
  setIfMissing('last_command', '');

  if (updates.isNotEmpty) await controlRef.update(updates);
}
