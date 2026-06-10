import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'notifikasi_screen.dart';
import '../widgets/responsive_content.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onMenuTap;
  final Function(int) onNavigateTab;

  const HomeScreen({
    super.key,
    required this.onMenuTap,
    required this.onNavigateTab,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color primary = Color(0xFFD62818);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFDC2626);
  static const Color success = Color(0xFF16A34A);
  static const Color surfaceContainerLowest = Colors.white;
  static const Color surfaceContainerHigh = Color(0xFFEAE7E7);
  static const Color onSurface = Color(0xFF1B1C1C);
  static const Color onSurfaceVariant = Color(0xFF5B403D);
  static const Color outlineVariant = Color(0xFFE4BEBA);

  // ── Firebase state ──────────────────────────────────────
  late final DatabaseReference _statusRef;
  late final DatabaseReference _schedulesRef;
  late final DatabaseReference _scheduleRunsRef;
  late final DatabaseReference _controlRef;
  late final DatabaseReference _notificationsRef;
  late final DatabaseReference _logsRef;
  late final DatabaseReference _settingsRef;
  late final DatabaseReference _notificationStateRef;
  late final DatabaseReference _sensorHistoryRef;
  double _temperature = 0;
  double _humidity = 0;
  double _feedWeight = 0;
  double _waterWeight = 0;
  double _feedLimit = 500;
  double _waterLimit = 500;
  bool _stockAlertEnabled = true;
  bool _isLoading = true;
  int _unreadNotifications = 0;
  List<Map<String, dynamic>> _todaySchedules = [];
  Map<String, Map<String, dynamic>> _todayRunStatus = {};
  Timer? _dayRefreshTimer;
  StreamSubscription<DatabaseEvent>? _sensorHistorySubscription;
  bool _isRecordingStockAlerts = false;
  bool _pendingStockAlertCheck = false;

  // Untuk grafik: simpan history suhu & kelembaban per jam dari Firebase.
  final List<FlSpot> _suhuSpots = [];
  final List<FlSpot> _kelembabanSpots = [];
  String _sensorHistoryDateKey = '';

  @override
  void initState() {
    super.initState();
    _statusRef = FirebaseDatabase.instance.ref('status');
    _schedulesRef = FirebaseDatabase.instance.ref('schedules');
    _scheduleRunsRef = FirebaseDatabase.instance.ref('schedule_runs');
    _controlRef = FirebaseDatabase.instance.ref('control');
    _notificationsRef = FirebaseDatabase.instance.ref('notifications');
    _logsRef = FirebaseDatabase.instance.ref('logs');
    _settingsRef = FirebaseDatabase.instance.ref('settings');
    _notificationStateRef = FirebaseDatabase.instance.ref(
      'notification_state/stock_alerts',
    );
    _sensorHistoryRef = FirebaseDatabase.instance.ref('sensor_history');
    _listenFirebase();
    _listenSettings();
    _listenSchedules();
    _listenTodayRuns();
    _listenNotifications();
    _listenSensorHistoryForToday();
    _dayRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _listenSensorHistoryForToday();
      _listenSchedulesOnce();
      _refreshTodayRunsOnce();
    });
  }

  // ── Smart number formatter ───────────────────────────────
  /// Tampilkan angka tanpa trailing zero:
  /// 28.0 → "28", 28.5 → "28.5", 28.50 → "28.5"
  String _fmtNum(double value, {int maxDecimals = 1}) {
    if (value == value.roundToDouble()) return value.round().toString();
    return value
        .toStringAsFixed(maxDecimals)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  void _listenFirebase() {
    _statusRef.onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data == null) return;

      final newTemp =
          _toDoubleValue(data['temperature'] ?? data['suhu'] ?? data['temp']) ??
          0;
      final newHum =
          _toDoubleValue(
            data['humidity'] ?? data['kelembaban'] ?? data['hum'],
          ) ??
          0;

      setState(() {
        _temperature = newTemp;
        _humidity = newHum;
        _feedWeight = _toStockUnit(data['feed_weight'], _feedLimit);
        _waterWeight = _toStockUnit(data['water_weight'], _waterLimit);
        _isLoading = false;
      });

      unawaited(_recordSensorSnapshot(data, newTemp, newHum));
      _recordSensorEvents(newTemp, newHum);
      _queueStockAlertCheck();
    });
  }

  void _listenSettings() {
    _settingsRef.onValue.listen((event) {
      if (!mounted) return;
      final data = event.snapshot.value as Map?;
      if (data == null) return;
      final notifications = data['notifications'] as Map?;

      setState(() {
        _stockAlertEnabled = notifications?['stock_alert'] != false;
        _feedLimit = _toPositiveLimit(data['feed_limit'], _feedLimit);
        _waterLimit = _toPositiveLimit(data['water_limit'], _waterLimit);
        _feedWeight = _feedWeight.clamp(0, _feedLimit).toDouble();
        _waterWeight = _waterWeight.clamp(0, _waterLimit).toDouble();
      });
      _syncTodayRuns(_todaySchedules);
      _queueStockAlertCheck();
    });
  }

  DateTime get _nowWita => DateTime.now().toUtc().add(const Duration(hours: 8));
  String get _todayDateKey => DateFormat('yyyy-MM-dd').format(_nowWita);
  int get _todayIndex => _nowWita.weekday - 1;
  DateTime get _todayStart =>
      DateTime(_nowWita.year, _nowWita.month, _nowWita.day);
  DateTime get _todayEnd => _todayStart.add(const Duration(days: 1));

  double _toStockUnit(Object? raw, double limit) {
    final value = raw is num
        ? raw.toDouble()
        : double.tryParse(raw?.toString() ?? '') ?? 0;
    if (limit <= 0) return value;
    return value.clamp(0, limit).toDouble();
  }

  double _toPositiveLimit(Object? raw, double fallback) {
    final value = raw is num
        ? raw.toDouble()
        : double.tryParse(raw?.toString() ?? '') ?? 0;
    return value > 0 ? value : fallback;
  }

  DateTime _sensorTimestamp(Map data) {
    final timestamp =
        data['timestamp'] ??
        data['updated_at'] ??
        data['last_update'] ??
        data['last_updated'];
    final parsed = _parseFirebaseTimestamp(timestamp);
    if (parsed == null) return _nowWita;
    return DateFormat('yyyy-MM-dd').format(parsed) == _todayDateKey
        ? parsed
        : _nowWita;
  }

  Future<void> _recordSensorSnapshot(
    Map data,
    double temperature,
    double humidity,
  ) async {
    final dt = _sensorTimestamp(data);
    final dateKey = DateFormat('yyyy-MM-dd').format(dt);
    final hourKey = DateFormat('HH').format(dt);
    await _sensorHistoryRef.child(dateKey).child(hourKey).update({
      'temperature': temperature,
      'humidity': humidity,
      'hour': dt.hour,
      'minute': dt.minute,
      'timestamp': ServerValue.timestamp,
      'wita_time': DateFormat('yyyy-MM-dd HH:mm:ss').format(dt),
    });
  }

  void _listenSensorHistoryForToday() {
    final dateKey = _todayDateKey;
    if (_sensorHistoryDateKey == dateKey) return;
    _sensorHistoryDateKey = dateKey;
    _sensorHistorySubscription?.cancel();
    _sensorHistorySubscription = _sensorHistoryRef
        .child(dateKey)
        .onValue
        .listen((event) {
          if (!mounted) return;
          final raw = event.snapshot.value;
          if (raw == null) {
            setState(() {
              _suhuSpots.clear();
              _kelembabanSpots.clear();
            });
            return;
          }

          final rawMap = Map<String, dynamic>.from(raw as Map);
          final suhu = <FlSpot>[];
          final kelembaban = <FlSpot>[];
          rawMap.forEach((key, value) {
            if (value is! Map) return;
            final item = Map<String, dynamic>.from(value);
            final hour = _historyHour(key.toString(), item);
            final temperature = _toDoubleValue(
              item['temperature'] ?? item['suhu'] ?? item['temp'],
            );
            final humidity = _toDoubleValue(
              item['humidity'] ?? item['kelembaban'] ?? item['hum'],
            );
            if (temperature != null) suhu.add(FlSpot(hour, temperature));
            if (humidity != null) kelembaban.add(FlSpot(hour, humidity));
          });

          suhu.sort((a, b) => a.x.compareTo(b.x));
          kelembaban.sort((a, b) => a.x.compareTo(b.x));
          setState(() {
            _suhuSpots
              ..clear()
              ..addAll(suhu);
            _kelembabanSpots
              ..clear()
              ..addAll(kelembaban);
          });
        });
  }

  double _historyHour(String key, Map<String, dynamic> item) {
    final hourValue = _toDoubleValue(item['hour']);
    final minuteValue = _toDoubleValue(item['minute']) ?? 0;
    if (hourValue != null) {
      return (hourValue + (minuteValue / 60)).clamp(0, 24).toDouble();
    }
    final keyHour = double.tryParse(key);
    if (keyHour != null) return keyHour.clamp(0, 24).toDouble();
    final dt = _parseFirebaseTimestamp(item['wita_time'] ?? item['timestamp']);
    if (dt == null) return 0;
    return (dt.hour + (dt.minute / 60) + (dt.second / 3600))
        .clamp(0, 24)
        .toDouble();
  }

  double? _toDoubleValue(Object? raw) {
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString() ?? '');
  }

  bool _isScheduleDue(String time) {
    final parts = time.split(':');
    final hour = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
    final scheduled = DateTime(
      _nowWita.year,
      _nowWita.month,
      _nowWita.day,
      hour,
      minute,
    );
    return !_nowWita.isBefore(scheduled);
  }

  DateTime? _parseStartAt(Object? raw) {
    if (raw is num) {
      return DateTime.fromMillisecondsSinceEpoch(raw.toInt());
    }
    return DateTime.tryParse(raw?.toString() ?? '');
  }

  bool _startsAfterToday(Map<String, dynamic> schedule) {
    final startAt = _parseStartAt(schedule['start_at']);
    return startAt != null && !startAt.isBefore(_todayEnd);
  }

  bool _shouldCancelSchedule(Map<String, dynamic> schedule) {
    final pakan = schedule['pakan'] == true;
    final air = schedule['air'] == true;
    return (pakan && _feedPercent() > 50) || (air && _waterPercent() > 50);
  }

  String _cancelReason(Map<String, dynamic> schedule) {
    final reasons = <String>[];
    if (schedule['pakan'] == true && _feedPercent() > 50) {
      reasons.add('pakan ${_feedPercent()}%');
    }
    if (schedule['air'] == true && _waterPercent() > 50) {
      reasons.add('air ${_waterPercent()}%');
    }
    return reasons.join(' dan ');
  }

  Future<void> _listenSchedulesOnce() async {
    final snapshot = await _schedulesRef.get();
    if (!mounted) return;
    _parseSchedules(snapshot.value);
  }

  void _listenSchedules() {
    _schedulesRef.onValue.listen((event) {
      if (!mounted) return;
      _parseSchedules(event.snapshot.value);
    });
  }

  void _parseSchedules(Object? raw) {
    if (raw == null) {
      setState(() => _todaySchedules = []);
      return;
    }

    final rawMap = Map<String, dynamic>.from(raw as Map);
    final schedules = <Map<String, dynamic>>[];

    rawMap.forEach((key, value) {
      final jadwal = Map<String, dynamic>.from(value as Map);
      final activeDays = List<bool>.filled(7, false);
      final daysRaw = jadwal['days'];

      if (daysRaw is Map) {
        daysRaw.forEach((dayKey, dayValue) {
          final idx = int.tryParse(dayKey.toString());
          if (idx != null && idx >= 0 && idx < activeDays.length) {
            activeDays[idx] = dayValue == true;
          }
        });
      } else if (daysRaw is List) {
        for (int i = 0; i < daysRaw.length && i < activeDays.length; i++) {
          activeDays[i] = daysRaw[i] == true;
        }
      }

      if (jadwal['active'] != true || !activeDays[_todayIndex]) return;
      if (_startsAfterToday({'start_at': jadwal['start_at']})) return;

      final type = jadwal['type']?.toString() ?? 'pakan_air';
      final repeatRaw = jadwal['repeat'];
      final repeatsWeekly =
          repeatRaw == true ||
          repeatRaw == 'Setiap Minggu' ||
          repeatRaw == 'Setiap Hari';
      final waterRaw = jadwal['water'];
      final water = waterRaw is num
          ? waterRaw.toInt()
          : int.tryParse(waterRaw?.toString() ?? '') ?? 0;

      schedules.add({
        'id': key,
        'time': jadwal['time']?.toString() ?? '00:00',
        'repeat': repeatsWeekly ? 'Setiap Minggu' : 'Khusus',
        'pakan': type == 'pakan' || type == 'pakan_air',
        'air': type == 'air' || type == 'pakan_air',
        'portion': (jadwal['portion'] as num?)?.toInt() ?? 0,
        'water': water,
        'start_at': jadwal['start_at'],
      });
    });

    schedules.sort((a, b) => a['time'].compareTo(b['time']));
    _syncTodayRuns(schedules);
    setState(() => _todaySchedules = schedules);
  }

  void _listenTodayRuns() {
    _scheduleRunsRef.child(_todayDateKey).onValue.listen((event) {
      if (!mounted) return;
      final raw = event.snapshot.value;
      if (raw == null) {
        setState(() => _todayRunStatus = {});
        return;
      }

      final rawMap = Map<String, dynamic>.from(raw as Map);
      final parsed = <String, Map<String, dynamic>>{};
      rawMap.forEach((key, value) {
        parsed[key] = Map<String, dynamic>.from(value as Map);
      });
      setState(() => _todayRunStatus = parsed);
      _recordCompletedSchedules(parsed);
    });
  }

  Future<void> _refreshTodayRunsOnce() async {
    final snapshot = await _scheduleRunsRef.child(_todayDateKey).get();
    if (!mounted) return;
    final raw = snapshot.value;
    if (raw == null) {
      setState(() => _todayRunStatus = {});
      return;
    }
    final rawMap = Map<String, dynamic>.from(raw as Map);
    final parsed = <String, Map<String, dynamic>>{};
    rawMap.forEach((key, value) {
      parsed[key] = Map<String, dynamic>.from(value as Map);
    });
    setState(() => _todayRunStatus = parsed);
    _recordCompletedSchedules(parsed);
  }

  Future<void> _syncTodayRuns(List<Map<String, dynamic>> schedules) async {
    final today = _todayDateKey;
    final runsSnapshot = await _scheduleRunsRef.get();
    final runsRaw = runsSnapshot.value;
    if (runsRaw is Map) {
      for (final key in runsRaw.keys) {
        if (key.toString() != today) {
          await _scheduleRunsRef.child(key.toString()).remove();
        }
      }
    }

    final todayRef = _scheduleRunsRef.child(today);
    for (final schedule in schedules) {
      final id = schedule['id']?.toString();
      if (id == null || id.isEmpty) continue;
      final existingSnapshot = await todayRef.child(id).get();
      final existing = existingSnapshot.value is Map
          ? Map<String, dynamic>.from(existingSnapshot.value as Map)
          : <String, dynamic>{};
      final time = schedule['time']?.toString() ?? '00:00';
      final due = _isScheduleDue(time);
      final isCancelled =
          existing['cancelled'] == true || existing['status'] == 'dibatalkan';
      final isDone =
          !isCancelled &&
          (existing['done'] == true ||
              existing['status'] == 'selesai' ||
              (due && !_shouldCancelSchedule(schedule)));
      final shouldCancel = !isDone && due && _shouldCancelSchedule(schedule);
      final shouldDispatch = isDone && due && existing['dispatched_at'] == null;
      await todayRef.child(id).update({
        'time': time,
        'pakan': schedule['pakan'],
        'air': schedule['air'],
        'portion': schedule['portion'],
        'water': schedule['water'],
        'status': shouldCancel
            ? 'dibatalkan'
            : (isDone ? 'selesai' : 'menunggu'),
        'done': isDone,
        'cancelled': shouldCancel || isCancelled,
        if (shouldCancel) 'cancel_reason': _cancelReason(schedule),
        if (isDone && existing['completed_at'] == null)
          'completed_at': ServerValue.timestamp,
        if (shouldDispatch) 'dispatched_at': ServerValue.timestamp,
        if (shouldCancel && existing['cancelled_at'] == null)
          'cancelled_at': ServerValue.timestamp,
        'date': today,
      });
      if (shouldCancel) {
        await _recordCancelledSchedule(id, schedule, time);
      } else if (shouldDispatch) {
        await _dispatchAutomaticSchedule(schedule);
      }
      if ((shouldCancel || isDone) && schedule['repeat'] != 'Setiap Minggu') {
        await _schedulesRef.child(id).update({'active': false});
      }
    }
  }

  Future<void> _dispatchAutomaticSchedule(Map<String, dynamic> schedule) async {
    final updates = <String, Object?>{};
    if (schedule['pakan'] == true) {
      final emptyFeed = (_feedLimit - _feedWeight).clamp(0, _feedLimit).floor();
      updates['portion'] = ((schedule['portion'] as num?)?.toInt() ?? 0)
          .clamp(0, emptyFeed)
          .toInt();
      updates['manual_feed'] = true;
    }
    if (schedule['air'] == true) {
      final emptyWater = (_waterLimit - _waterWeight)
          .clamp(0, _waterLimit)
          .floor();
      updates['water_volume'] = ((schedule['water'] as num?)?.toInt() ?? 0)
          .clamp(0, emptyWater)
          .toInt();
      updates['manual_water'] = true;
    }
    if (updates.isNotEmpty) {
      await _controlRef.update(updates);
    }
  }

  void _listenNotifications() {
    _notificationsRef.onValue.listen((event) {
      if (!mounted) return;
      final raw = event.snapshot.value;
      if (raw == null) {
        setState(() => _unreadNotifications = 0);
        return;
      }

      final rawMap = Map<String, dynamic>.from(raw as Map);
      var unreadCount = 0;
      for (final entry in rawMap.entries) {
        final value = entry.value;
        if (value is! Map) continue;
        final notif = Map<String, dynamic>.from(value);
        final dt = _parseFirebaseTimestamp(notif['timestamp']);
        if (dt != null && _nowWita.difference(dt).inHours >= 24) {
          _notificationsRef.child(entry.key.toString()).remove();
          continue;
        }
        if (notif['read'] != true && notif['isRead'] != true) {
          unreadCount++;
        }
      }

      setState(() => _unreadNotifications = unreadCount);
    });
  }

  DateTime? _parseFirebaseTimestamp(Object? raw) {
    if (raw is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        raw.toInt(),
        isUtc: true,
      ).add(const Duration(hours: 8));
    }
    final text = raw?.toString() ?? '';
    if (text.isEmpty) return null;
    final parsed = DateTime.tryParse(text.replaceAll(' ', 'T'));
    if (parsed == null) return null;
    return parsed.isUtc ? parsed.toUtc().add(const Duration(hours: 8)) : parsed;
  }

  Future<void> _recordCancelledSchedule(
    String id,
    Map<String, dynamic> schedule,
    String time,
  ) async {
    final pakan = schedule['pakan'] == true;
    final air = schedule['air'] == true;
    final label = pakan && air ? 'pakan dan air' : (pakan ? 'pakan' : 'air');
    final desc =
        'Jadwal pemberian $label pukul $time dibatalkan karena persediaan ${_cancelReason(schedule)} masih mencukupi (di atas 50%).';
    final key = 'jadwal_batal_${_todayDateKey}_$id';

    await _logsRef.child(key).update({
      'timestamp': ServerValue.timestamp,
      'type': 'jadwal_dibatalkan',
      'status': 'dibatalkan',
      'title': 'Jadwal $time dibatalkan',
      'desc': desc,
    });
    final notificationSnapshot = await _notificationsRef.child(key).get();
    if (!notificationSnapshot.exists) {
      await _notificationsRef.child(key).set({
        'timestamp': ServerValue.timestamp,
        'type': 'jadwal_dibatalkan',
        'target': 'jadwal',
        'title': 'Jadwal Otomatis Dibatalkan',
        'desc': desc,
        'read': false,
      });
    }
  }

  Future<void> _recordCompletedSchedules(
    Map<String, Map<String, dynamic>> runs,
  ) async {
    for (final entry in runs.entries) {
      final run = entry.value;
      if (run['cancelled'] == true || run['status'] == 'dibatalkan') continue;
      final done = run['done'] == true || run['status'] == 'selesai';
      if (!done) continue;
      final schedule = _todaySchedules.cast<Map<String, dynamic>?>().firstWhere(
        (item) => item?['id'] == entry.key,
        orElse: () => null,
      );
      final time =
          run['time']?.toString() ?? schedule?['time']?.toString() ?? '';
      final pakan = run['pakan'] == true || schedule?['pakan'] == true;
      final air = run['air'] == true || schedule?['air'] == true;
      final portion =
          (run['portion'] as num?)?.toInt() ??
          (schedule?['portion'] as num?)?.toInt() ??
          0;
      final water =
          (run['water'] as num?)?.toInt() ??
          (schedule?['water'] as num?)?.toInt() ??
          0;
      final parts = <String>[
        if (pakan) '${portion}g pakan',
        if (air) '${water}ml air',
      ];
      final key = 'jadwal_${_todayDateKey}_${entry.key}';
      await _logsRef.child(key).update({
        'timestamp': run['completed_at'] ?? ServerValue.timestamp,
        'type': pakan && air
            ? 'pakan_air_otomatis'
            : (pakan ? 'pakan_otomatis' : 'air_otomatis'),
        'status': 'sukses',
        'title': 'Jadwal $time selesai',
        'desc': parts.isEmpty
            ? 'Pemberian otomatis selesai.'
            : 'Pemberian ${parts.join(' dan ')} selesai sesuai jadwal.',
      });
      final notificationSnapshot = await _notificationsRef.child(key).get();
      if (!notificationSnapshot.exists) {
        await _notificationsRef.child(key).set({
          'timestamp': run['completed_at'] ?? ServerValue.timestamp,
          'type': 'jadwal_selesai',
          'target': 'riwayat',
          'title': 'Jadwal $time Selesai',
          'desc': parts.isEmpty
              ? 'Pemberian otomatis selesai.'
              : '${parts.join(' dan ')} berhasil diberikan.',
          'read': false,
        });
      }
    }
  }

  Future<void> _recordSensorEvents(double temperature, double humidity) async {
    final hourKey = DateFormat('yyyyMMdd_HH').format(_nowWita);
    if (temperature > 29 || temperature < 22) {
      final key = 'sensor_suhu_$hourKey';
      await _logsRef.child(key).update({
        'timestamp': ServerValue.timestamp,
        'type': 'sensor_suhu',
        'status': 'peringatan',
        'title': 'Peringatan Suhu',
        'desc': 'Suhu kandang ${_fmtNum(temperature)}°C di luar batas ideal.',
        'value': temperature,
        'unit': '°C',
      });
      final notificationSnapshot = await _notificationsRef.child(key).get();
      if (!notificationSnapshot.exists) {
        await _notificationsRef.child(key).set({
          'timestamp': ServerValue.timestamp,
          'type': 'suhu',
          'target': 'dashboard',
          'title': 'Peringatan Suhu',
          'desc': 'Suhu kandang ${_fmtNum(temperature)}°C di luar batas ideal.',
          'read': false,
        });
      }
    }
    if (humidity < 50 || humidity > 70) {
      final key = 'sensor_kelembaban_$hourKey';
      await _logsRef.child(key).update({
        'timestamp': ServerValue.timestamp,
        'type': 'sensor_kelembaban',
        'status': 'peringatan',
        'title': 'Peringatan Kelembaban',
        'desc': 'Kelembaban kandang ${_fmtNum(humidity)}% di luar batas ideal.',
        'value': humidity,
        'unit': '%',
      });
      final notificationSnapshot = await _notificationsRef.child(key).get();
      if (!notificationSnapshot.exists) {
        await _notificationsRef.child(key).set({
          'timestamp': ServerValue.timestamp,
          'type': 'kelembaban',
          'target': 'dashboard',
          'title': 'Peringatan Kelembaban',
          'desc':
              'Kelembaban kandang ${_fmtNum(humidity)}% di luar batas ideal.',
          'read': false,
        });
      }
    }
  }

  void _queueStockAlertCheck() {
    if (!_stockAlertEnabled) return;
    if (_isRecordingStockAlerts) {
      _pendingStockAlertCheck = true;
      return;
    }
    unawaited(_recordStockAlerts());
  }

  Future<void> _recordStockAlerts() async {
    if (!_stockAlertEnabled || _isRecordingStockAlerts) return;
    _isRecordingStockAlerts = true;
    try {
      final alerts = [
        (
          stateKey: 'pakan',
          type: 'stok_pakan',
          title: 'Peringatan Pakan Rendah',
          subject: 'pakan',
          refillTarget: 'pakan',
          amount: _feedWeight,
          limit: _feedLimit,
          unit: 'gram',
          percent: _feedPercent(),
        ),
        (
          stateKey: 'air',
          type: 'stok_air',
          title: 'Peringatan Air Rendah',
          subject: 'air',
          refillTarget: 'air',
          amount: _waterWeight,
          limit: _waterLimit,
          unit: 'ml',
          percent: _waterPercent(),
        ),
      ];

      for (final alert in alerts) {
        if (alert.limit <= 0) continue;
        final threshold = alert.limit * 0.10;
        final isLow = alert.amount <= threshold;
        final stateRef = _notificationStateRef.child(alert.stateKey);
        final stateSnapshot = await stateRef.get();
        final state = stateSnapshot.value is Map
            ? Map<String, dynamic>.from(stateSnapshot.value as Map)
            : <String, dynamic>{};
        final wasLow = state['is_low'] == true;
        final lastLimit = _toDoubleValue(state['limit']) ?? 0;
        final sameLimit = (lastLimit - alert.limit).abs() < 0.001;

        if (!isLow) {
          if (wasLow) {
            await stateRef.update({
              'is_low': false,
              'amount': alert.amount,
              'limit': alert.limit,
              'threshold': threshold,
              'recovered_at': ServerValue.timestamp,
            });
          }
          continue;
        }

        if (wasLow && sameLimit) continue;

        final key =
            'stok_${alert.stateKey}_${DateFormat('yyyyMMdd_HHmmss').format(_nowWita)}';
        final amountText = _formatStockAmount(alert.amount);
        final limitText = _formatStockAmount(alert.limit);
        final thresholdText = _formatStockAmount(threshold);
        final desc =
            'Peringatan! Sisa ${alert.subject} berada di bawah 10% dari kapasitas maksimum. '
            'Segera isi ulang ${alert.refillTarget} untuk memastikan sistem tetap berjalan dengan baik. '
            'Sisa $amountText ${alert.unit} dari kapasitas $limitText ${alert.unit} '
            '(ambang $thresholdText ${alert.unit}).';

        await _logsRef.child(key).update({
          'timestamp': ServerValue.timestamp,
          'type': alert.type,
          'status': 'peringatan',
          'title': alert.title,
          'desc': desc,
          'value': alert.amount,
          'limit': alert.limit,
          'threshold': threshold,
          'percent': alert.percent,
          'unit': alert.unit,
        });
        await _notificationsRef.child(key).set({
          'timestamp': ServerValue.timestamp,
          'type': alert.type,
          'target': 'dashboard',
          'title': alert.title,
          'desc': desc,
          'read': false,
          'value': alert.amount,
          'limit': alert.limit,
          'threshold': threshold,
          'percent': alert.percent,
          'unit': alert.unit,
        });
        await stateRef.update({
          'is_low': true,
          'amount': alert.amount,
          'limit': alert.limit,
          'threshold': threshold,
          'last_alert_key': key,
          'last_alert_at': ServerValue.timestamp,
        });
      }
    } finally {
      _isRecordingStockAlerts = false;
      if (_pendingStockAlertCheck) {
        _pendingStockAlertCheck = false;
        _queueStockAlertCheck();
      }
    }
  }

  String _formatStockAmount(double value) {
    if (value % 1 == 0) return value.round().toString();
    return value.toStringAsFixed(1);
  }

  @override
  void dispose() {
    _dayRefreshTimer?.cancel();
    _sensorHistorySubscription?.cancel();
    super.dispose();
  }

  // ── Status helpers ───────────────────────────────────────
  ({String label, Color color}) _temperatureStatus(double value) {
    if (value >= 22 && value <= 25) return (label: 'Normal', color: success);
    if (value >= 26 && value <= 29) return (label: 'Waspada', color: warning);
    return (label: 'Bahaya', color: danger);
  }

  ({String label, Color color}) _humidityStatus(double value) {
    if (value < 50) return (label: 'Terlalu Kering', color: warning);
    if (value <= 70) return (label: 'Ideal', color: success);
    return (label: 'Terlalu Lembab', color: danger);
  }

  int _stockPercent(double amount, double limit) {
    if (limit <= 0) return 0;
    return (amount / limit * 100).clamp(0, 100).round();
  }

  int _feedPercent() => _stockPercent(_feedWeight, _feedLimit);
  int _waterPercent() => _stockPercent(_waterWeight, _waterLimit);

  /// Hanya return data nyata dari Firebase, tanpa titik artifisial.
  List<FlSpot> _dailyChartSpots(List<FlSpot> source, double minY, double maxY) {
    if (source.isEmpty) return [];
    return source
        .map(
          (spot) => FlSpot(
            spot.x.clamp(0, 24).toDouble(),
            spot.y.clamp(minY, maxY).toDouble(),
          ),
        )
        .toList()
      ..sort((a, b) => a.x.compareTo(b.x));
  }

  // ── Build ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCF9F8),
      body: Column(
        children: [
          _buildTopAppBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: primary))
                : SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 100),
                    child: ResponsiveContent(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 24),
                          _buildSectionStatusKandang(),
                          const SizedBox(height: 32),
                          _buildSectionGrafik(),
                          const SizedBox(height: 32),
                          _buildSectionAksiCepat(),
                          const SizedBox(height: 32),
                          _buildSectionJadwal(),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Top App Bar ──────────────────────────────────────────
  Widget _buildTopAppBar() {
    return Container(
      color: const Color(0xFFD62818),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 16,
      ),
      child: ResponsiveContent(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              context.isDesktopWidth
                  ? const SizedBox(width: 40)
                  : _iconButton(Icons.menu_rounded, onTap: widget.onMenuTap),
              Text(
                'SIPPA',
                style: GoogleFonts.manrope(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              Stack(
                children: [
                  _iconButton(
                    Icons.notifications_outlined,
                    onTap: () async {
                      final targetTab = await Navigator.push<int>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotifikasiScreen(),
                        ),
                      );
                      if (targetTab != null) widget.onNavigateTab(targetTab);
                    },
                  ),
                  if (_unreadNotifications > 0)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Center(
                          child: Text(
                            _unreadNotifications > 99
                                ? '99+'
                                : '$_unreadNotifications',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconButton(IconData icon, {required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  // ── Section: Status Kandang ──────────────────────────────
  Widget _buildSectionStatusKandang() {
    final suhuStatus = _temperatureStatus(_temperature);
    final kelembabanStatus = _humidityStatus(_humidity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Status Kandang',
            style: GoogleFonts.manrope(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: onSurface,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 155,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              _statusCard(
                icon: Icons.thermostat_rounded,
                iconColor: primary,
                borderColor: primary,
                label: 'Suhu',
                // ✅ Pakai _fmtNum: 28.0 → "28°C", 28.5 → "28.5°C"
                value: '${_fmtNum(_temperature)}°C',
                status: suhuStatus.label,
                statusColor: suhuStatus.color,
              ),
              const SizedBox(width: 16),
              _statusCard(
                icon: Icons.water_drop_rounded,
                leadingIcon: _humidityIcon(),
                iconColor: primary,
                borderColor: primary,
                label: 'Kelembaban',
                // ✅ Pakai _fmtNum: 65.0 → "65%", 65.3 → "65.3%"
                value: '${_fmtNum(_humidity)}%',
                status: kelembabanStatus.label,
                statusColor: kelembabanStatus.color,
              ),
              const SizedBox(width: 16),
              _stockCard(
                icon: Icons.grain_rounded,
                label: 'Stok Pakan',
                percentage: _feedPercent(),
                amount: '${_feedWeight.round()} gram',
              ),
              const SizedBox(width: 16),
              _stockCard(
                icon: Icons.water_drop_rounded,
                label: 'Stok Air Minum',
                percentage: _waterPercent(),
                amount: '${_waterWeight.round()} ml',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statusCard({
    required IconData icon,
    Widget? leadingIcon,
    required Color iconColor,
    required Color borderColor,
    required String label,
    required String value,
    required String status,
    required Color statusColor,
  }) {
    return Container(
      width: 168,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: borderColor, width: 4)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD62818).withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              leadingIcon ?? Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: onSurfaceVariant,
                    letterSpacing: 0.8,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.manrope(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: onSurface,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            status,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _humidityIcon() {
    return SizedBox(
      width: 20,
      height: 20,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            left: 0,
            top: 1,
            child: Icon(Icons.water_drop_rounded, color: primary, size: 17),
          ),
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: surfaceContainerLowest,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.percent_rounded, color: primary, size: 9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stockCard({
    required IconData icon,
    required String label,
    required int percentage,
    required String amount,
  }) {
    return Container(
      width: 168,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: const Border(left: BorderSide(color: primary, width: 4)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD62818).withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: primary, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: onSurfaceVariant,
                    letterSpacing: 0.8,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '$percentage%',
              style: GoogleFonts.manrope(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: onSurface,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            amount,
            style: GoogleFonts.inter(fontSize: 11, color: onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  // ── Section: Grafik ──────────────────────────────────────
  Widget _buildSectionGrafik() {
    final suhuSpots = _dailyChartSpots(_suhuSpots, 20, 40);
    final kelembabanSpots = _dailyChartSpots(_kelembabanSpots, 0, 100);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          _lineChartCard(
            title: 'Suhu Kandang Hari Ini',
            spots: suhuSpots,
            minY: 20,
            maxY: 40,
            interval: 5,
            unit: '°',
            color: const Color(0xFFF59E0B),
            // Zone ideal suhu: 22–29°C
            idealMin: 22,
            idealMax: 29,
          ),
          const SizedBox(height: 20),
          _lineChartCard(
            title: 'Kelembaban Kandang Hari Ini',
            spots: kelembabanSpots,
            minY: 0,
            maxY: 100,
            interval: 20,
            unit: '%',
            color: const Color(0xFF1976D2),
            // Zone ideal kelembaban: 50–70%
            idealMin: 50,
            idealMax: 70,
          ),
        ],
      ),
    );
  }

  Widget _lineChartCard({
    required String title,
    required List<FlSpot> spots,
    required double minY,
    required double maxY,
    required double interval,
    required String unit,
    required Color color,
    double? idealMin,
    double? idealMax,
  }) {
    final nowHour =
        _nowWita.hour + (_nowWita.minute / 60) + (_nowWita.second / 3600);
    final hasData = spots.isNotEmpty;

    // Nilai terkini untuk badge
    final latestValue = hasData ? spots.last.y : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      decoration: BoxDecoration(
        color: surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD62818).withOpacity(0.04),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: judul + badge nilai terkini ─────────
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.manrope(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: onSurface,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              if (latestValue != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    // ✅ Badge juga pakai _fmtNum
                    '${_fmtNum(latestValue)}$unit',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Chart area ───────────────────────────────────
          SizedBox(
            height: 170,
            child: !hasData
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.show_chart_rounded,
                          color: outlineVariant,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Belum ada data hari ini',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: 24,
                      minY: minY,
                      maxY: maxY,
                      clipData: const FlClipData.all(),

                      // ── Tooltip interaktif ───────────────
                      lineTouchData: LineTouchData(
                        enabled: true,
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (_) => onSurface.withOpacity(0.88),
                          tooltipRoundedRadius: 8,
                          tooltipPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          getTooltipItems: (touchedSpots) => touchedSpots.map((
                            s,
                          ) {
                            final h = s.x.floor();
                            final m = ((s.x - h) * 60).round();
                            return LineTooltipItem(
                              '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}\n',
                              GoogleFonts.inter(
                                fontSize: 10,
                                color: Colors.white54,
                              ),
                              children: [
                                TextSpan(
                                  // ✅ Tooltip juga pakai _fmtNum
                                  text: '${_fmtNum(s.y)}$unit',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: color,
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),

                      // ── Grid ────────────────────────────
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: true,
                        verticalInterval: 6,
                        horizontalInterval: interval,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: outlineVariant.withOpacity(0.4),
                          strokeWidth: 1,
                          dashArray: [4, 4],
                        ),
                        getDrawingVerticalLine: (_) => FlLine(
                          color: outlineVariant.withOpacity(0.25),
                          strokeWidth: 1,
                          dashArray: [4, 4],
                        ),
                      ),

                      // ── Border ───────────────────────────
                      borderData: FlBorderData(
                        show: true,
                        border: Border(
                          left: BorderSide(
                            color: outlineVariant.withOpacity(0.5),
                          ),
                          bottom: BorderSide(
                            color: outlineVariant.withOpacity(0.5),
                          ),
                        ),
                      ),

                      // ── Titles ───────────────────────────
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 44,
                            interval: interval,
                            getTitlesWidget: (val, _) => Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Text(
                                // ✅ Y-axis labels juga pakai _fmtNum
                                '${_fmtNum(val)}$unit',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  color: onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            interval: 3,
                            getTitlesWidget: (val, _) {
                              final hour = val.round();
                              if (hour % 3 != 0 || hour < 0 || hour > 24) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '${hour.toString().padLeft(2, '0')}:00',
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    color: onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),

                      // ── Line data ────────────────────────
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          curveSmoothness: 0.3,
                          color: color,
                          barWidth: 2.5,
                          // Dot kecil & bersih hanya di titik data nyata
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, _, __, ___) =>
                                FlDotCirclePainter(
                                  radius: 3,
                                  color: color,
                                  strokeWidth: 1.5,
                                  strokeColor: Colors.white,
                                ),
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                color.withOpacity(0.20),
                                color.withOpacity(0.0),
                              ],
                            ),
                          ),
                        ),
                      ],

                      // ── Extra lines: "Sekarang" + zone ideal ──
                      extraLinesData: ExtraLinesData(
                        // Garis vertikal waktu sekarang
                        verticalLines: [
                          VerticalLine(
                            x: nowHour,
                            color: primary.withOpacity(0.5),
                            strokeWidth: 1.5,
                            dashArray: [4, 4],
                            label: VerticalLineLabel(
                              show: true,
                              alignment: Alignment.topRight,
                              padding: const EdgeInsets.only(
                                right: 4,
                                bottom: 4,
                              ),
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                color: primary,
                                fontWeight: FontWeight.w600,
                              ),
                              labelResolver: (_) => 'Sekarang',
                            ),
                          ),
                        ],
                        // Garis horizontal batas ideal (atas & bawah)
                        horizontalLines: [
                          if (idealMin != null)
                            HorizontalLine(
                              y: idealMin,
                              color: success.withOpacity(0.4),
                              strokeWidth: 1,
                              dashArray: [6, 4],
                              label: HorizontalLineLabel(
                                show: true,
                                alignment: Alignment.topRight,
                                padding: const EdgeInsets.only(
                                  right: 4,
                                  bottom: 2,
                                ),
                                style: GoogleFonts.inter(
                                  fontSize: 8,
                                  color: success,
                                  fontWeight: FontWeight.w600,
                                ),
                                labelResolver: (_) =>
                                    'Min ideal (${_fmtNum(idealMin)}$unit)',
                              ),
                            ),
                          if (idealMax != null)
                            HorizontalLine(
                              y: idealMax,
                              color: success.withOpacity(0.4),
                              strokeWidth: 1,
                              dashArray: [6, 4],
                              label: HorizontalLineLabel(
                                show: true,
                                alignment: Alignment.topRight,
                                padding: const EdgeInsets.only(
                                  right: 4,
                                  bottom: 2,
                                ),
                                style: GoogleFonts.inter(
                                  fontSize: 8,
                                  color: success,
                                  fontWeight: FontWeight.w600,
                                ),
                                labelResolver: (_) =>
                                    'Maks ideal (${_fmtNum(idealMax)}$unit)',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Section: Aksi Cepat ──────────────────────────────────
  Widget _buildSectionAksiCepat() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Aksi Cepat',
            style: GoogleFonts.manrope(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: onSurface,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 720;
              return GridView.count(
                crossAxisCount: isWide ? 4 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: isWide ? 2.25 : 1.55,
                children: [
                  _aksiButton(
                    icon: Icons.grain_rounded,
                    label: 'Beri Pakan',
                    onTap: () => widget.onNavigateTab(1),
                  ),
                  _aksiButton(
                    icon: Icons.water_drop_rounded,
                    label: 'Beri Air',
                    onTap: () => widget.onNavigateTab(1),
                  ),
                  _aksiButton(
                    icon: Icons.calendar_today_rounded,
                    label: 'Atur Jadwal',
                    onTap: () => widget.onNavigateTab(2),
                  ),
                  _aksiButton(
                    icon: Icons.history_rounded,
                    label: 'Riwayat',
                    onTap: () => widget.onNavigateTab(3),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _aksiButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: surfaceContainerLowest,
      borderRadius: BorderRadius.circular(14),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: primary.withOpacity(0.1),
        highlightColor: primary.withOpacity(0.05),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: outlineVariant.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: primary),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: onSurface,
                  letterSpacing: 0.2,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Section: Jadwal ──────────────────────────────────────
  Widget _buildSectionJadwal() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD62818).withOpacity(0.04),
              blurRadius: 32,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Jadwal Aktif Hari Ini',
              style: GoogleFonts.manrope(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: onSurface,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 20),
            if (_todaySchedules.isEmpty)
              Text(
                'Tidak ada jadwal aktif hari ini',
                style: GoogleFonts.inter(fontSize: 13, color: onSurfaceVariant),
              )
            else
              ..._todaySchedules.asMap().entries.map((entry) {
                final schedule = entry.value;
                final run = _todayRunStatus[schedule['id']];
                final hasPakan = schedule['pakan'] == true;
                final hasAir = schedule['air'] == true;
                final labelParts = <String>[
                  if (hasPakan) '${schedule['portion']}g pakan',
                  if (hasAir) '${schedule['water']}ml air',
                ];

                return Padding(
                  padding: EdgeInsets.only(
                    bottom: entry.key == _todaySchedules.length - 1 ? 0 : 16,
                  ),
                  child: _jadwalItem(
                    time: schedule['time']?.toString() ?? '00:00',
                    label: labelParts.join(' + '),
                    status: run?['status']?.toString() ?? 'menunggu',
                    isDone: run?['done'] == true || run?['status'] == 'selesai',
                    isCancelled:
                        run?['cancelled'] == true ||
                        run?['status'] == 'dibatalkan',
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _jadwalItem({
    required String time,
    required String label,
    required String status,
    required bool isDone,
    required bool isCancelled,
  }) {
    final statusColor = isDone
        ? const Color(0xFF16A34A)
        : (isCancelled ? const Color(0xFFF97316) : onSurfaceVariant);
    final statusLabel = isDone
        ? 'Selesai'
        : (isCancelled
              ? 'Dibatalkan'
              : (status == 'menunggu' ? 'Menunggu' : status));

    return Opacity(
      opacity: isDone || isCancelled ? 1.0 : 0.6,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDone
                  ? const Color(0xFFF0FDF4)
                  : (isCancelled
                        ? const Color(0xFFFFF7ED)
                        : surfaceContainerHigh),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isDone
                  ? Icons.check_rounded
                  : (isCancelled
                        ? Icons.block_rounded
                        : Icons.schedule_rounded),
              size: 18,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  time,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: onSurface,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            statusLabel,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: statusColor,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
