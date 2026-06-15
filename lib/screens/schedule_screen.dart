import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'tambah_jadwal_screen.dart';
import '../widgets/responsive_content.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  static const Color primary = Color(0xFFD62818);
  static const Color primaryContainer = Color(0xFFE13A2A);
  static const Color surfaceContainerLowest = Colors.white;
  static const Color surfaceContainerHigh = Color(0xFFEAE7E7);
  static const Color surfaceVariant = Color(0xFFE5E2E1);
  static const Color onSurface = Color(0xFF1B1C1C);
  static const Color onSurfaceVariant = Color(0xFF5B403D);
  static const Color outlineVariant = Color(0xFFE4BEBA);

  // ── Firebase ────────────────────────────────────────────
  late final DatabaseReference _schedulesRef;
  late final DatabaseReference _scheduleRunsRef;
  late final DatabaseReference _controlRef;
  late final DatabaseReference _statusRef;
  late final DatabaseReference _notificationsRef;
  late final DatabaseReference _logsRef;
  late final DatabaseReference _settingsRef;

  // Semua jadwal dari Firebase, key = jadwal_id (e.g. "jadwal_1")
  Map<String, Map<String, dynamic>> _allSchedules = {};
  Map<String, Map<String, dynamic>> _todayRunStatus = {};
  double _feedWeight = 0;
  double _waterWeight = 0;
  double _feedLimit = 500;
  double _waterLimit = 500;
  bool _scheduleConfirmationEnabled = true;
  bool _settingsLoaded = false;
  bool _isLoading = true;
  Timer? _clockTimer;

  // ── Filter ──────────────────────────────────────────────
  String _selectedDay = 'Semua';
  final List<String> _days = [
    'Semua',
    'Sen',
    'Sel',
    'Rab',
    'Kam',
    'Jum',
    'Sab',
    'Min',
  ];

  // Mapping label hari → index di Firebase days array (0=Sen, 6=Min)
  static const Map<String, int> _dayIndexMap = {
    'Sen': 0,
    'Sel': 1,
    'Rab': 2,
    'Kam': 3,
    'Jum': 4,
    'Sab': 5,
    'Min': 6,
  };

  // Label singkat hari untuk pill (urutan sesuai Firebase days index)
  static const List<String> _dayLabels = [
    'Sen',
    'Sel',
    'Rab',
    'Kam',
    'Jum',
    'Sab',
    'Min',
  ];

  DateTime get _nowWita => DateTime.now().toUtc().add(const Duration(hours: 8));
  int get _todayWitaIndex => _nowWita.weekday - 1;
  String get _todayDateKey => DateFormat('yyyy-MM-dd').format(_nowWita);
  DateTime get _todayStart =>
      DateTime(_nowWita.year, _nowWita.month, _nowWita.day);
  DateTime get _todayEnd => _todayStart.add(const Duration(days: 1));

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

  bool _isActiveOnToday(Map<String, dynamic> schedule) {
    final activeDays = List<bool>.from(schedule['activeDays']);
    return schedule['isActive'] == true &&
        _todayWitaIndex < activeDays.length &&
        activeDays[_todayWitaIndex] &&
        !_startsAfterToday(schedule);
  }

  int _feedPercent() => (_feedWeight / _feedLimit * 100).clamp(0, 100).toInt();
  int _waterPercent() =>
      (_waterWeight / _waterLimit * 100).clamp(0, 100).toInt();

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

  int _toIntValue(Object? raw) {
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  String _scheduleTypeFromData(Map<String, dynamic> data) {
    final rawType = data['type']?.toString();
    final portion = _toIntValue(data['portion']);
    final water = _toIntValue(data['water']);
    if (rawType == 'pakan_air' || rawType == 'pakan' || rawType == 'air') {
      if (rawType == 'pakan' && water > 0) {
        return portion > 0 ? 'pakan_air' : 'air';
      }
      return rawType!;
    }

    final hasPakan = data['pakan'] == true || portion > 0;
    final hasAir = data['air'] == true || water > 0;
    if (hasPakan && hasAir) return 'pakan_air';
    if (hasAir) return 'air';
    return 'pakan';
  }

  bool _shouldCancelSchedule(Map<String, dynamic> schedule) {
    return _scheduleCancelReasons(schedule).isNotEmpty;
  }

  String _cancelReason(Map<String, dynamic> schedule) {
    return _scheduleCancelReasons(schedule).join(' dan ');
  }

  List<String> _scheduleCancelReasons(Map<String, dynamic> schedule) {
    final reasons = <String>[];
    if (schedule['pakan'] == true) {
      final portion = _toIntValue(schedule['portion']);
      final emptyFeed = (_feedLimit - _feedWeight).clamp(0, _feedLimit).floor();
      if (_feedPercent() > 50) {
        reasons.add('stok pakan ${_feedPercent()}% masih di atas 50%');
      } else if (portion <= 0) {
        reasons.add('jumlah pakan belum diatur');
      } else if (portion > emptyFeed) {
        reasons.add('pakan ${portion}g melebihi ruang kosong ${emptyFeed}g');
      }
    }
    if (schedule['air'] == true) {
      final water = _toIntValue(schedule['water']);
      final emptyWater = (_waterLimit - _waterWeight)
          .clamp(0, _waterLimit)
          .floor();
      if (_waterPercent() > 50) {
        reasons.add('stok air ${_waterPercent()}% masih di atas 50%');
      } else if (water <= 0) {
        reasons.add('jumlah air belum diatur');
      } else if (water > emptyWater) {
        reasons.add('air ${water}ml melebihi ruang kosong ${emptyWater}ml');
      }
    }
    return reasons;
  }

  ({int portion, int water}) _scheduleRunAmounts(
    Map<String, dynamic> schedule,
  ) {
    final portion = schedule['pakan'] == true
        ? _toIntValue(schedule['portion'])
        : 0;
    final water = schedule['air'] == true ? _toIntValue(schedule['water']) : 0;
    return (portion: portion, water: water);
  }

  @override
  void initState() {
    super.initState();
    _schedulesRef = FirebaseDatabase.instance.ref('schedules');
    _scheduleRunsRef = FirebaseDatabase.instance.ref('schedule_runs');
    _controlRef = FirebaseDatabase.instance.ref('control');
    _statusRef = FirebaseDatabase.instance.ref('status');
    _notificationsRef = FirebaseDatabase.instance.ref('notifications');
    _logsRef = FirebaseDatabase.instance.ref('logs');
    _settingsRef = FirebaseDatabase.instance.ref('settings');
    _listenStatus();
    _listenSettings();
    _listenSchedules();
    _listenTodayRuns();
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      _syncTodayRuns(_allSchedules.values.toList());
      setState(() {});
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  // ── Firebase Listener ───────────────────────────────────
  void _listenStatus() {
    _statusRef.onValue.listen((event) {
      if (!mounted) return;
      final data = event.snapshot.value as Map?;
      if (data == null) return;
      setState(() {
        _feedWeight = _toStockUnit(data['feed_weight'], _feedLimit);
        _waterWeight = _toStockUnit(data['water_weight'], _waterLimit);
      });
      _syncTodayRuns(_allSchedules.values.toList());
      _recordCompletedSchedules(_todayRunStatus);
    });
  }

  void _listenSettings() {
    _settingsRef.onValue.listen((event) {
      if (!mounted) return;
      final data = event.snapshot.value as Map?;
      if (data == null) return;
      final notifications = data['notifications'] as Map?;

      setState(() {
        _scheduleConfirmationEnabled =
            notifications?['schedule_confirmation'] != false;
        _feedLimit = _toPositiveLimit(data['feed_limit'], _feedLimit);
        _waterLimit = _toPositiveLimit(data['water_limit'], _waterLimit);
        _feedWeight = _feedWeight.clamp(0, _feedLimit).toDouble();
        _waterWeight = _waterWeight.clamp(0, _waterLimit).toDouble();
        _settingsLoaded = true;
      });
      _syncTodayRuns(_allSchedules.values.toList());
    });
  }

  void _listenSchedules() {
    _schedulesRef.onValue.listen((event) {
      final raw = event.snapshot.value;
      if (!mounted) return;

      if (raw == null) {
        setState(() {
          _allSchedules = {};
          _isLoading = false;
        });
        return;
      }

      final rawMap = Map<String, dynamic>.from(raw as Map);
      final parsed = <String, Map<String, dynamic>>{};

      rawMap.forEach((key, value) {
        final jadwal = Map<String, dynamic>.from(value as Map);

        // Parsing days: Firebase menyimpan sebagai Map {0: true, 1: false, ...}
        final daysRaw = jadwal['days'];
        List<bool> activeDays = List.filled(7, false);
        if (daysRaw is Map) {
          daysRaw.forEach((k, v) {
            final idx = int.tryParse(k.toString());
            if (idx != null && idx >= 0 && idx < 7) {
              activeDays[idx] = v == true;
            }
          });
        } else if (daysRaw is List) {
          for (int i = 0; i < daysRaw.length && i < 7; i++) {
            activeDays[i] = daysRaw[i] == true;
          }
        }

        // type: "pakan" | "air" | "pakan_air"
        final type = _scheduleTypeFromData(jadwal);
        final repeatRaw = jadwal['repeat'];
        final repeatsWeekly =
            repeatRaw == true ||
            repeatRaw == 'Setiap Minggu' ||
            repeatRaw == 'Setiap Hari';
        parsed[key] = {
          'id': key,
          'time': jadwal['time']?.toString() ?? '00:00',
          'repeat': repeatsWeekly ? 'Setiap Minggu' : 'Khusus',
          'pakan': type == 'pakan' || type == 'pakan_air',
          'air': type == 'air' || type == 'pakan_air',
          'type': type,
          'portion': _toIntValue(jadwal['portion']),
          'water': _toIntValue(jadwal['water']),
          'days': _dayLabels,
          'activeDays': activeDays,
          'isActive': jadwal['active'] == true,
          'start_at': jadwal['start_at'],
        };
      });

      // Sort berdasarkan time
      final sortedEntries = parsed.entries.toList()
        ..sort((a, b) => a.value['time'].compareTo(b.value['time']));

      _syncTodayRuns(sortedEntries.map((e) => e.value).toList());
      setState(() {
        _allSchedules = Map.fromEntries(sortedEntries);
        _isLoading = false;
      });
    });
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
      if (!_isActiveOnToday(schedule)) {
        continue;
      }

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
      final schedulePortion = _toIntValue(schedule['portion']);
      final scheduleWater = _toIntValue(schedule['water']);
      final dispatchAmounts = _scheduleRunAmounts(schedule);
      final runPortion = schedule['pakan'] == true
          ? (shouldDispatch
                ? dispatchAmounts.portion
                : (isDone && existing.containsKey('portion')
                      ? _toIntValue(existing['portion'])
                      : schedulePortion))
          : 0;
      final runWater = schedule['air'] == true
          ? (shouldDispatch
                ? dispatchAmounts.water
                : (isDone && existing.containsKey('water')
                      ? _toIntValue(existing['water'])
                      : scheduleWater))
          : 0;
      await todayRef.child(id).update({
        'time': time,
        'pakan': schedule['pakan'],
        'air': schedule['air'],
        'portion': runPortion,
        'water': runWater,
        'requested_portion': schedulePortion,
        'requested_water': scheduleWater,
        'status': shouldCancel || isCancelled
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
        await _dispatchAutomaticSchedule(
          schedule,
          portion: runPortion,
          water: runWater,
        );
        await _recordCompletedSchedule(
          id: id,
          time: time,
          pakan: schedule['pakan'] == true,
          air: schedule['air'] == true,
          portion: runPortion,
          water: runWater,
          timestamp: existing['completed_at'] ?? ServerValue.timestamp,
        );
      }
      if ((shouldCancel || isDone) && schedule['repeat'] != 'Setiap Minggu') {
        await _schedulesRef.child(id).update({'active': false});
      }
    }
  }

  Future<void> _dispatchAutomaticSchedule(
    Map<String, dynamic> schedule, {
    required int portion,
    required int water,
  }) async {
    final updates = <String, Object?>{};
    if (schedule['pakan'] == true) {
      updates['portion'] = portion;
      updates['manual_feed'] = true;
    }
    if (schedule['air'] == true) {
      updates['water_volume'] = water;
      updates['manual_water'] = true;
    }
    if (updates.isNotEmpty) {
      await _controlRef.update(updates);
    }
  }

  Future<void> _recordCancelledSchedule(
    String id,
    Map<String, dynamic> schedule,
    String time,
  ) async {
    final pakan = schedule['pakan'] == true;
    final air = schedule['air'] == true;
    final label = pakan && air ? 'pakan dan air' : (pakan ? 'pakan' : 'air');
    final reason = _cancelReason(schedule);
    final desc =
        'Jadwal pemberian $label pukul $time dibatalkan karena $reason.';
    final key = 'jadwal_batal_${_todayDateKey}_$id';

    await _logsRef.child(key).update({
      'timestamp': ServerValue.timestamp,
      'type': 'jadwal_dibatalkan',
      'status': 'dibatalkan',
      'title': 'Jadwal $time dibatalkan',
      'desc': desc,
    });
    final notificationSnapshot = await _notificationsRef.child(key).get();
    if (_settingsLoaded &&
        _scheduleConfirmationEnabled &&
        !notificationSnapshot.exists) {
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
      final schedule = _allSchedules[entry.key];
      final time =
          run['time']?.toString() ?? schedule?['time']?.toString() ?? '';
      final pakan = run['pakan'] == true || schedule?['pakan'] == true;
      final air = run['air'] == true || schedule?['air'] == true;
      final portion = run.containsKey('portion')
          ? _toIntValue(run['portion'])
          : _toIntValue(schedule?['portion']);
      final water = run.containsKey('water')
          ? _toIntValue(run['water'])
          : _toIntValue(schedule?['water']);

      await _recordCompletedSchedule(
        id: entry.key,
        time: time,
        pakan: pakan,
        air: air,
        portion: portion,
        water: water,
        timestamp: run['completed_at'] ?? ServerValue.timestamp,
      );
    }
  }

  Future<void> _recordCompletedSchedule({
    required String id,
    required String time,
    required bool pakan,
    required bool air,
    required int portion,
    required int water,
    Object? timestamp,
  }) async {
    final parts = <String>[
      if (pakan) '${portion}g pakan',
      if (air) '${water}ml air',
    ];
    final type = pakan && air
        ? 'pakan_air_otomatis'
        : (pakan ? 'pakan_otomatis' : 'air_otomatis');
    final label = pakan && air ? 'Pakan & Air' : (pakan ? 'Pakan' : 'Air');
    final title = 'Jadwal $label $time selesai';
    final desc = parts.isEmpty
        ? 'Pemberian otomatis selesai.'
        : 'Pemberian ${parts.join(' dan ')} selesai sesuai jadwal.';
    final key = 'jadwal_${_todayDateKey}_$id';
    final eventTimestamp = timestamp ?? ServerValue.timestamp;

    await _logsRef.child(key).update({
      'timestamp': eventTimestamp,
      'type': type,
      'status': 'sukses',
      'title': title,
      'desc': desc,
      'schedule_id': id,
      'date': _todayDateKey,
      'pakan': pakan,
      'air': air,
      'portion': portion,
      'water': water,
    });
    final notificationSnapshot = await _notificationsRef.child(key).get();
    if (_scheduleConfirmationEnabled && !notificationSnapshot.exists) {
      await _notificationsRef.child(key).set({
        'timestamp': eventTimestamp,
        'type': type,
        'target': 'riwayat',
        'title': title,
        'desc': parts.isEmpty
            ? 'Pemberian otomatis selesai.'
            : '${parts.join(' dan ')} berhasil diberikan sesuai jadwal.',
        'schedule_id': id,
        'date': _todayDateKey,
        'pakan': pakan,
        'air': air,
        'portion': portion,
        'water': water,
        'read': false,
      });
    }
  }

  // ── Helper: filter jadwal berdasarkan hari terpilih ─────
  List<MapEntry<String, Map<String, dynamic>>> get _filteredEntries {
    if (_selectedDay == 'Semua') return _allSchedules.entries.toList();
    final dayIdx = _dayIndexMap[_selectedDay];
    if (dayIdx == null) return _allSchedules.entries.toList();
    return _allSchedules.entries.where((e) {
      final activeDays = e.value['activeDays'] as List<bool>;
      final isSelectedDayActive =
          dayIdx < activeDays.length && activeDays[dayIdx];
      return isSelectedDayActive;
    }).toList();
  }

  // Jadwal hari ini: isActive = true
  List<MapEntry<String, Map<String, dynamic>>> get _jadwalAktif =>
      _filteredEntries.where((e) => e.value['isActive'] == true).toList();

  // Jadwal tidak aktif (tampil di bawah sebagai "Jadwal Besok")
  List<MapEntry<String, Map<String, dynamic>>> get _jadwalNonAktif =>
      _filteredEntries.where((e) => e.value['isActive'] != true).toList();

  // Hitung jumlah jadwal aktif hari ini (tanpa filter hari)
  int get _totalAktifHariIni => _allSchedules.values.where((v) {
    return _isActiveOnToday(v);
  }).length;

  int get _totalJadwalAktif => _allSchedules.values.where((v) {
    return v['isActive'] == true;
  }).length;

  // ── Toggle active di Firebase ───────────────────────────
  Future<void> _toggleActive(String id, bool currentValue) async {
    await _schedulesRef.child(id).update({'active': !currentValue});
  }

  // ── Hapus jadwal di Firebase ────────────────────────────
  Future<void> _deleteJadwal(String id) async {
    await _schedulesRef.child(id).remove();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Jadwal berhasil dihapus'),
        backgroundColor: primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Edit jadwal ─────────────────────────────────────────
  Future<void> _editJadwal(String id, Map<String, dynamic> jadwal) async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => TambahJadwalScreen(initialJadwal: jadwal),
      ),
    );
    if (!mounted || result == null) return;

    // Konversi hasil TambahJadwalScreen kembali ke format Firebase
    await _saveToFirebase(id, result);
  }

  // ── Tambah jadwal baru ───────────────────────────────────
  Future<void> _navigateToTambahJadwal() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const TambahJadwalScreen()),
    );
    if (!mounted || result == null) return;

    // Buat key baru otomatis (jadwal_timestamp)
    final newKey = 'jadwal_${DateTime.now().millisecondsSinceEpoch}';
    await _saveToFirebase(newKey, result);
  }

  // ── Helper: simpan Map jadwal ke Firebase ────────────────
  Future<void> _saveToFirebase(String id, Map<String, dynamic> data) async {
    // Konversi activeDays List<bool> → Map {0: true, 1: false, ...}
    final activeDays =
        data['activeDays'] as List<bool>? ?? List.filled(7, true);
    final daysMap = <String, bool>{};
    for (int i = 0; i < activeDays.length; i++) {
      daysMap[i.toString()] = activeDays[i];
    }

    // Tentukan type dari flag pakan/air, fallback ke type untuk payload lama.
    final type = _scheduleTypeFromData(data);
    final pakan = type == 'pakan' || type == 'pakan_air';
    final air = type == 'air' || type == 'pakan_air';
    final repeatRaw = data['repeat'];
    final repeatsWeekly =
        repeatRaw == true ||
        repeatRaw == 'Setiap Minggu' ||
        repeatRaw == 'Setiap Hari';

    await _schedulesRef.child(id).set({
      'active': data['isActive'] ?? data['active'] ?? true,
      'days': daysMap,
      'portion': pakan ? data['portion'] ?? 200 : 0,
      'repeat': repeatsWeekly,
      'time': data['time'] ?? '08:00',
      'type': type,
      'water': air ? data['water'] ?? 0 : 0,
      'start_at': data['start_at'],
    });
  }

  // ============================================================
  //  BUILD
  // ============================================================
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
                    padding: const EdgeInsets.only(bottom: 120),
                    child: ResponsiveContent(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 24),
                          _buildSummaryStrip(),
                          const SizedBox(height: 24),
                          _buildDayFilter(),
                          const SizedBox(height: 24),
                          _buildJadwalList(),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  // ── Top App Bar ──────────────────────────────────────────
  Widget _buildTopAppBar() {
    return Container(
      color: primary,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 16,
      ),
      child: ResponsiveContent(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Text(
                'Jadwal Pakan & Air',
                style: GoogleFonts.manrope(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Summary Strip ────────────────────────────────────────
  Widget _buildSummaryStrip() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [primary, primaryContainer],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: primary.withOpacity(0.25),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_rounded,
              color: Colors.white,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${_allSchedules.length} Jadwal Tersimpan | $_totalJadwalAktif Aktif | $_totalAktifHariIni Hari Ini',
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Day Filter ───────────────────────────────────────────
  Widget _buildDayFilter() {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: _days.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final isSelected = _selectedDay == _days[i];
          return GestureDetector(
            onTap: () => setState(() => _selectedDay = _days[i]),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? primary : surfaceContainerLowest,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isSelected ? primary : outlineVariant,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: primary.withOpacity(0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : [],
              ),
              child: Text(
                _days[i],
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : primary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Jadwal List ──────────────────────────────────────────
  Widget _buildJadwalList() {
    final aktif = _jadwalAktif;
    final nonAktif = _jadwalNonAktif;
    final emptyText = _selectedDay == 'Semua'
        ? 'Belum ada jadwal aktif tersimpan'
        : 'Tidak ada jadwal aktif untuk hari $_selectedDay';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Jadwal aktif
          if (aktif.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Center(
                child: Text(
                  emptyText,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            ...aktif.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildJadwalCard(
                  jadwal: e.value,
                  id: e.key,
                  isBesok: false,
                ),
              ),
            ),

          // Separator Jadwal Non-Aktif
          if (nonAktif.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Jadwal Tidak Aktif',
                style: GoogleFonts.manrope(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: onSurface,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            ...nonAktif.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildJadwalCard(
                  jadwal: e.value,
                  id: e.key,
                  isBesok: true,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Jadwal Card ─────────────────────────────────────────
  Widget _buildJadwalCard({
    required Map<String, dynamic> jadwal,
    required String id,
    required bool isBesok,
  }) {
    final bool isActive = jadwal['isActive'] as bool;
    final List<String> days = List<String>.from(jadwal['days']);
    final List<bool> activeDays = List<bool>.from(jadwal['activeDays']);
    final isActiveToday = _isActiveOnToday(jadwal);
    final run = isActiveToday ? _todayRunStatus[id] : null;
    final isCancelled =
        run?['cancelled'] == true || run?['status'] == 'dibatalkan';
    final isDone =
        !isCancelled && (run?['done'] == true || run?['status'] == 'selesai');
    final statusLabel = !isActive
        ? 'Nonaktif'
        : (isActiveToday
              ? (isDone ? 'Selesai' : (isCancelled ? 'Dibatalkan' : 'Menunggu'))
              : 'Terjadwal');
    final statusColor = !isActive
        ? onSurfaceVariant
        : (isDone
              ? const Color(0xFF16A34A)
              : (isCancelled ? const Color(0xFFF97316) : onSurfaceVariant));
    final repeatLabel = jadwal['repeat'] == 'Setiap Minggu'
        ? 'Berulang setiap minggu'
        : 'Tidak berulang';

    return Opacity(
      opacity: isBesok ? 0.85 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Left accent bar
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 4,
                  color: isActive ? primary : surfaceVariant,
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.start,
                      children: [
                        // Time & Badge
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  jadwal['time'],
                                  style: GoogleFonts.manrope(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w800,
                                    color: isActive
                                        ? primary
                                        : onSurfaceVariant,
                                    letterSpacing: -1,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: isActive
                                          ? primary
                                          : outlineVariant,
                                    ),
                                  ),
                                  child: Text(
                                    statusLabel,
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: statusColor,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        // Toggle + More
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => _toggleActive(id, isActive),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                width: 44,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: isActive ? primary : surfaceVariant,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: AnimatedAlign(
                                  duration: const Duration(milliseconds: 250),
                                  alignment: isActive
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  child: Container(
                                    margin: const EdgeInsets.all(3),
                                    width: 20,
                                    height: 20,
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(999),
                              child: InkWell(
                                onTap: () => _showJadwalActions(
                                  jadwal: jadwal,
                                  id: id,
                                  isBesok: isBesok,
                                ),
                                borderRadius: BorderRadius.circular(999),
                                child: Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: Icon(
                                    Icons.more_vert_rounded,
                                    color: onSurfaceVariant,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Pakan & Air Info
                    Wrap(
                      spacing: 20,
                      runSpacing: 8,
                      children: [
                        if (jadwal['pakan'] == true)
                          _infoChip(
                            Icons.grain_rounded,
                            'Pakan ${jadwal['portion']}g',
                          ),
                        if (jadwal['air'] == true)
                          _infoChip(
                            Icons.water_drop_rounded,
                            'Air ${jadwal['water']}ml',
                          ),
                        _infoChip(Icons.repeat_rounded, repeatLabel),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Day Pills
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: List.generate(days.length, (i) {
                        final active = activeDays[i];
                        return Container(
                          width: 38,
                          height: 30,
                          decoration: BoxDecoration(
                            color: active ? primary : surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(999),
                            border: active
                                ? null
                                : Border.all(color: outlineVariant),
                          ),
                          child: Center(
                            child: Text(
                              days[i],
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: active ? Colors.white : onSurfaceVariant,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: onSurfaceVariant),
        const SizedBox(width: 5),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width - 96,
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(fontSize: 13, color: onSurfaceVariant),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ── Bottom Sheet Actions ─────────────────────────────────
  Future<void> _showJadwalActions({
    required Map<String, dynamic> jadwal,
    required String id,
    required bool isBesok,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: surfaceContainerLowest,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: surfaceVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                _scheduleActionTile(
                  icon: Icons.edit_calendar_rounded,
                  title: 'Edit Jadwal',
                  subtitle: 'Ubah waktu, jenis pemberian, dan hari aktif',
                  onTap: () {
                    Navigator.of(context).pop();
                    _editJadwal(id, jadwal);
                  },
                ),
                const SizedBox(height: 8),
                _scheduleActionTile(
                  icon: Icons.delete_outline_rounded,
                  title: 'Hapus Jadwal',
                  subtitle: 'Hapus jadwal ini dari daftar',
                  isDanger: true,
                  onTap: () {
                    Navigator.of(context).pop();
                    _deleteJadwal(id);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _scheduleActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    final color = isDanger ? primary : onSurface;
    return Material(
      color: isDanger ? primary.withOpacity(0.06) : const Color(0xFFFCF9F8),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isDanger
                      ? primary.withOpacity(0.12)
                      : surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDanger
                        ? primary.withOpacity(0.18)
                        : outlineVariant,
                  ),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  // ── FAB ──────────────────────────────────────────────────
  Widget _buildFAB() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _navigateToTambahJadwal,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: surfaceContainerLowest,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: primary.withOpacity(0.15)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              'Tambah Jadwal',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: primary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        FloatingActionButton(
          onPressed: _navigateToTambahJadwal,
          backgroundColor: primary,
          elevation: 6,
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
        ),
      ],
    );
  }
}
