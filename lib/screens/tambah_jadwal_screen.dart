import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../widgets/responsive_content.dart';

// ============================================================
//  COLOR CONSTANTS
// ============================================================
const Color kPrimary = Color(0xFFD62818);
const Color kOnPrimary = Color(0xFFFFFFFF);
const Color kBackground = Color(0xFFFCF9F8);
const Color kSurfaceContainerLowest = Color(0xFFFFFFFF);
const Color kSurfaceContainerLow = Color(0xFFF6F3F2);
const Color kSurfaceContainerHigh = Color(0xFFEAE7E7);
const Color kSurfaceContainerHighest = Color(0xFFE5E2E1);
const Color kOnSurface = Color(0xFF1B1C1C);
const Color kOnSurfaceVariant = Color(0xFF5B403D);
const Color kPrimaryFixed = Color(0xFFFFDAD6);

// ============================================================
//  FIREBASE SCHEDULE TYPE CONSTANTS
//  Matches Firebase node: type: "pakan_air" | "pakan" | "air"
// ============================================================
const String kTypePakanAir = 'pakan_air';
const String kTypePakan = 'pakan';
const String kTypeAir = 'air';

// ============================================================
//  TAMBAH JADWAL SCREEN
// ============================================================
class TambahJadwalScreen extends StatefulWidget {
  const TambahJadwalScreen({super.key, this.initialJadwal});

  final Map<String, dynamic>? initialJadwal;

  @override
  State<TambahJadwalScreen> createState() => _TambahJadwalScreenState();
}

class _TambahJadwalScreenState extends State<TambahJadwalScreen> {
  // --- State ---
  int _selectedHour = 6;
  int _selectedMinute = 30;

  // 0 = Pakan + Air, 1 = Pakan Saja, 2 = Air Saja
  int _selectedJenis = 0;

  static const int _stepAmount = 50;
  static const int _minAmount = 0;
  int _feedLimit = 500;
  int _waterLimit = 500;

  int _porsiPakan = 200;
  int _volumeAir = 500;
  double _feedAmountGram = 0;
  double _waterAmountMl = 0;
  late final DatabaseReference _statusRef;
  late final DatabaseReference _settingsRef;

  // Senin sampai Minggu (index 0..6)
  final List<bool> _hariAktif = [true, true, true, true, true, false, false];
  final List<String> _hariLabel = [
    'Sen',
    'Sel',
    'Rab',
    'Kam',
    'Jum',
    'Sab',
    'Min',
  ];

  // TRUE  = jadwal berulang setiap minggu pada hari-hari yang dipilih
  // FALSE = jadwal hanya dijalankan SEKALI pada tanggal terdekat yang valid
  bool _ulangiSetiapMinggu = true;

  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;

  @override
  void initState() {
    super.initState();
    _statusRef = FirebaseDatabase.instance.ref('status');
    _settingsRef = FirebaseDatabase.instance.ref('settings');
    _listenStatus();
    _listenSettings();

    final initial = widget.initialJadwal;
    if (initial != null) {
      // ── Waktu ──────────────────────────────────────────
      final time = (initial['time'] as String? ?? '06:30').split(':');
      _selectedHour = int.tryParse(time.first) ?? 6;
      _selectedMinute = time.length > 1 ? int.tryParse(time[1]) ?? 30 : 30;

      // ── Type (sesuai Firebase: "pakan_air" | "pakan" | "air") ──
      final type = initial['type'] as String? ?? kTypePakanAir;
      if (type == kTypePakanAir) {
        _selectedJenis = 0;
      } else if (type == kTypePakan) {
        _selectedJenis = 1;
      } else {
        _selectedJenis = 2;
      }

      // ── Porsi & Volume ─────────────────────────────────
      _porsiPakan = _normalizePakan(
        (initial['portion'] as num?)?.toInt() ?? 200,
      );
      final waterRaw = initial['water'];
      if (waterRaw is num) {
        _volumeAir = _normalizeAir(waterRaw.toInt());
      } else if (waterRaw is String && waterRaw.isNotEmpty) {
        _volumeAir = _normalizeAir(int.tryParse(waterRaw) ?? 500);
      }

      // ─3─ Hari Aktif ─────────────────────────────────────
      final activeDays = initial['activeDays'];
      if (activeDays is List && activeDays.length == 7) {
        _hariAktif
          ..clear()
          ..addAll(activeDays.map((d) => d == true));
      }

      // ── Repeat — Firebase simpan sebagai bool ──────────
      // repeat: true  → berulang setiap minggu
      // repeat: false → sekali jalan
      final repeatRaw = initial['repeat'];
      if (repeatRaw is bool) {
        _ulangiSetiapMinggu = repeatRaw;
      } else if (repeatRaw is String) {
        // fallback kompatibilitas data lama
        _ulangiSetiapMinggu =
            repeatRaw == 'Setiap Minggu' || repeatRaw == 'true';
      } else {
        _ulangiSetiapMinggu = true;
      }
    }

    _hourController = FixedExtentScrollController(initialItem: _selectedHour);
    _minuteController = FixedExtentScrollController(
      initialItem: _selectedMinute ~/ 5,
    );
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  // ============================================================
  //  HELPERS — NORMALISASI AMOUNT
  // ============================================================
  int _normalizeAmount(int value, int max) {
    if (max <= _minAmount) return _minAmount;
    return value.clamp(_minAmount, max).toInt();
  }

  int _normalizePakan(int value) => _normalizeAmount(value, _feedLimit);
  int _normalizeAir(int value) => _normalizeAmount(value, _waterLimit);

  int _incrementStepValue(int value, int max) {
    if (value >= max) return max;
    final next = value + _stepAmount;
    return next >= max ? max : next;
  }

  int _decrementStepValue(int value) {
    if (value <= _minAmount) return _minAmount;
    final next = value - _stepAmount;
    return next < _minAmount ? _minAmount : next;
  }

  // ============================================================
  //  GETTERS — TYPE & STOCK
  // ============================================================
  bool get _showPakan => _selectedJenis == 0 || _selectedJenis == 1;
  bool get _showAir => _selectedJenis == 0 || _selectedJenis == 2;

  /// Konversi index jenis → string Firebase
  String get _typeString {
    switch (_selectedJenis) {
      case 1:
        return kTypePakan;
      case 2:
        return kTypeAir;
      default:
        return kTypePakanAir;
    }
  }

  double get _feedProgress => (_feedAmountGram / _feedLimit).clamp(0.0, 1.0);
  double get _waterProgress => (_waterAmountMl / _waterLimit).clamp(0.0, 1.0);
  int get _feedPercent => (_feedProgress * 100).round();
  int get _waterPercent => (_waterProgress * 100).round();

  bool get _isAmountAvailable {
    if (_showPakan && (_porsiPakan <= 0 || _porsiPakan > _feedLimit)) {
      return false;
    }
    if (_showAir && (_volumeAir <= 0 || _volumeAir > _waterLimit)) {
      return false;
    }
    return true;
  }

  // ============================================================
  //  WAKTU — WITA (UTC+8)
  // ============================================================
  DateTime get _nowWita => DateTime.now().toUtc().add(const Duration(hours: 8));

  /// Apakah slot waktu untuk [dayIndex] pada MINGGU INI sudah terlewati?
  ///
  /// [FIX] Fungsi ini sekarang HANYA dipakai untuk:
  ///   1. Menampilkan visual disabled pada chip hari (UI hint)
  ///   2. Validasi final di _onSave()
  ///
  /// Fungsi ini TIDAK lagi dipanggil saat scroll drum waktu berlangsung,
  /// sehingga hari aktif tidak ikut dimatikan saat user sedang memilih jam.
  bool _isDayTimePast(int dayIndex) {
    // Saat mode repeat-weekly, semua hari selalu bisa dipilih
    // karena jadwal akan otomatis diulang minggu depan jika minggu ini sudah lewat.
    if (_ulangiSetiapMinggu) return false;

    final now = _nowWita;
    final todayIndex = now.weekday - 1; // Senin=0 … Minggu=6

    if (dayIndex < todayIndex) {
      // Hari sebelum hari ini di minggu ini → sudah lewat
      return true;
    }
    if (dayIndex > todayIndex) {
      // Hari setelah hari ini → belum lewat
      return false;
    }
    // Hari yang sama (hari ini): cek apakah jam:menit sudah lewat
    final scheduledToday = DateTime(
      now.year,
      now.month,
      now.day,
      _selectedHour,
      _selectedMinute,
    );
    return !scheduledToday.isAfter(now);
  }

  /// Tanggal eksekusi pertama untuk [dayIndex] mode one-time
  DateTime _scheduleDateForDay(int dayIndex) {
    final now = _nowWita;
    final todayIndex = now.weekday - 1;
    final daysAhead = dayIndex - todayIndex;
    return DateTime(
      now.year,
      now.month,
      now.day + daysAhead,
      _selectedHour,
      _selectedMinute,
    );
  }

  /// Tanggal eksekusi berikutnya untuk [dayIndex] mode weekly
  /// (auto-geser ke minggu depan kalau minggu ini sudah lewat)
  DateTime _nextScheduleDateForDay(int dayIndex) {
    final now = _nowWita;
    final todayIndex = now.weekday - 1;
    var daysAhead = dayIndex - todayIndex;
    if (daysAhead < 0) daysAhead += 7;

    var scheduled = DateTime(
      now.year,
      now.month,
      now.day + daysAhead,
      _selectedHour,
      _selectedMinute,
    );
    // Jika waktunya sudah lewat hari ini, geser ke minggu depan
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 7));
    }
    return scheduled;
  }

  /// Waktu pertama kali jadwal akan dieksekusi (diambil yang paling awal)
  DateTime? _firstRunAt() {
    DateTime? first;
    for (var i = 0; i < _hariAktif.length; i++) {
      if (!_hariAktif[i]) continue;
      final date = _ulangiSetiapMinggu
          ? _nextScheduleDateForDay(i)
          : _scheduleDateForDay(i);
      if (first == null || date.isBefore(first)) first = date;
    }
    return first;
  }

  // ============================================================
  //  [FIX] _sanitizeOneTimeDays — HANYA dipanggil saat save & toggle repeat
  //
  //  SEBELUMNYA: dipanggil di onChanged drum jam/menit, menyebabkan hari
  //  aktif hari ini langsung dimatikan saat user scroll melewati jam
  //  yang sudah lewat, meski jam tujuan akhirnya masih valid.
  //
  //  SESUDAHNYA: hanya dipanggil di:
  //    - _onSave()               → validasi sebelum simpan
  //    - _buildUlangi() toggle   → saat user matikan "Ulangi Setiap Minggu"
  //  Drum jam/menit TIDAK lagi memanggil fungsi ini.
  // ============================================================
  void _sanitizeOneTimeDays() {
    if (_ulangiSetiapMinggu) return;
    for (var i = 0; i < _hariAktif.length; i++) {
      if (_isDayTimePast(i)) _hariAktif[i] = false;
    }
  }

  bool get _hasSelectableDay {
    for (var i = 0; i < _hariAktif.length; i++) {
      if (_hariAktif[i] && !_isDayTimePast(i)) return true;
    }
    return false;
  }

  // ============================================================
  //  FIREBASE LISTENERS
  // ============================================================
  double _toScheduleUnit(Object? raw) {
    final value = raw is num
        ? raw.toDouble()
        : double.tryParse(raw?.toString() ?? '') ?? 0;
    return value;
  }

  int _toPositiveLimit(Object? raw, int fallback) {
    final value = raw is num
        ? raw.toInt()
        : int.tryParse(raw?.toString() ?? '') ?? 0;
    return value > 0 ? value : fallback;
  }

  void _listenSettings() {
    _settingsRef.onValue.listen((event) {
      if (!mounted) return;
      final data = event.snapshot.value as Map?;
      if (data == null) return;
      setState(() {
        _feedLimit = _toPositiveLimit(data['feed_limit'], _feedLimit);
        _waterLimit = _toPositiveLimit(data['water_limit'], _waterLimit);
        _feedAmountGram = _feedAmountGram.clamp(0, _feedLimit).toDouble();
        _waterAmountMl = _waterAmountMl.clamp(0, _waterLimit).toDouble();
        _porsiPakan = _normalizePakan(_porsiPakan);
        _volumeAir = _normalizeAir(_volumeAir);
      });
    });
  }

  void _listenStatus() {
    _statusRef.onValue.listen((event) {
      if (!mounted) return;
      final data = event.snapshot.value as Map?;
      if (data == null) {
        return;
      }
      final feed = _toScheduleUnit(data['feed_weight']).clamp(0, _feedLimit);
      final water = _toScheduleUnit(data['water_weight']).clamp(0, _waterLimit);
      setState(() {
        _feedAmountGram = feed.toDouble();
        _waterAmountMl = water.toDouble();
        _porsiPakan = _normalizePakan(_porsiPakan);
        _volumeAir = _normalizeAir(_volumeAir);
      });
    });
  }

  // ============================================================
  //  SNACKBAR HELPERS
  // ============================================================
  void _showCapacityMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: kPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ============================================================
  //  BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: _buildAppBar(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: ResponsiveContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWaktuPemberian(),
              const SizedBox(height: 20),
              _buildJenisPemberian(),
              const SizedBox(height: 20),
              if (_showPakan || _showAir) ...[
                _buildPorsiSection(),
                const SizedBox(height: 20),
              ],
              _buildHariAktif(),
              const SizedBox(height: 20),
              _buildUlangi(),
              const SizedBox(height: 32),
              _buildActions(context),
            ],
          ),
        ),
      ),
    );
  }

  // ── App Bar ──────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: kPrimary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        widget.initialJadwal == null ? 'Tambah Jadwal' : 'Edit Jadwal',
        style: const TextStyle(
          fontFamily: 'Manrope',
          fontWeight: FontWeight.w700,
          fontSize: 18,
          color: Colors.white,
        ),
      ),
    );
  }

  // ── Section 1: Waktu Pemberian ───────────────────────────
  Widget _buildWaktuPemberian() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Waktu Pemberian', showUnderline: true),
          const SizedBox(height: 20),
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: kSurfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 80,
                  child: _buildTimeDrum(
                    controller: _hourController,
                    itemCount: 24,
                    label: (i) => i.toString().padLeft(2, '0'),
                    // [FIX] Hapus _sanitizeOneTimeDays() dari sini.
                    // Dulu pemanggilan di sini menyebabkan hari aktif hari ini
                    // langsung dimatikan saat scroll melewati jam yang sudah lewat,
                    // meski jam tujuan akhir user masih valid (lebih dari jam sekarang).
                    onChanged: (i) => setState(() {
                      _selectedHour = i;
                    }),
                  ),
                ),
                const Text(
                  ':',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    color: kPrimary,
                    fontFamily: 'Manrope',
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: _buildTimeDrum(
                    controller: _minuteController,
                    itemCount: 12,
                    label: (i) => (i * 5).toString().padLeft(2, '0'),
                    // [FIX] Sama seperti jam — tidak perlu sanitize saat scroll.
                    onChanged: (i) => setState(() {
                      _selectedMinute = i * 5;
                    }),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeDrum({
    required FixedExtentScrollController controller,
    required int itemCount,
    required String Function(int) label,
    required ValueChanged<int> onChanged,
  }) {
    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white,
          Colors.transparent,
          Colors.transparent,
          Colors.white,
        ],
        stops: [0.0, 0.25, 0.75, 1.0],
      ).createShader(rect),
      blendMode: BlendMode.dstOut,
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: 52,
        perspective: 0.003,
        diameterRatio: 1.5,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: onChanged,
        childDelegate: ListWheelChildBuilderDelegate(
          builder: (context, index) {
            final isSelected = controller.selectedItem == index;
            return Center(
              child: Text(
                label(index),
                style: TextStyle(
                  fontSize: isSelected ? 44 : 28,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Manrope',
                  color: isSelected
                      ? kPrimary
                      : kOnSurfaceVariant.withOpacity(0.35),
                ),
              ),
            );
          },
          childCount: itemCount,
        ),
      ),
    );
  }

  // ── Section 2: Jenis Pemberian ───────────────────────────
  Widget _buildJenisPemberian() {
    final items = ['Pakan + Air', 'Pakan Saja', 'Air Saja'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _labelHeader('Jenis Pemberian'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: kSurfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: List.generate(
              items.length,
              (i) => Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _selectedJenis = i;
                    _porsiPakan = _normalizePakan(_porsiPakan);
                    _volumeAir = _normalizeAir(_volumeAir);
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _selectedJenis == i
                          ? kPrimary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: _selectedJenis == i
                          ? [
                              BoxShadow(
                                color: kPrimary.withOpacity(0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : [],
                    ),
                    child: Text(
                      items[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: _selectedJenis == i
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: _selectedJenis == i
                            ? kOnPrimary
                            : kOnSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Section 3: Porsi Pakan & Volume Air ─────────────────
  Widget _buildPorsiSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Jumlah Pemberian', showUnderline: true),

          // ── Slider Porsi Pakan ───────────────────────────
          if (_showPakan) ...[
            const SizedBox(height: 20),
            _stockProgressRow(
              label: 'Sisa pakan',
              percent: _feedPercent,
              amount: '${_feedAmountGram.round()} gram',
              color: kPrimary,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Porsi Pakan',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: kOnSurface,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: kPrimary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$_porsiPakan g',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: kOnPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildAmountSeekBar(
              value: _porsiPakan,
              max: _feedLimit,
              color: kPrimary,
              enabled: _feedLimit > 0,
              onChanged: (val) {
                setState(() => _porsiPakan = _normalizePakan(val));
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '0 g',
                    style: TextStyle(fontSize: 11, color: kOnSurfaceVariant),
                  ),
                  Text(
                    '$_feedLimit g',
                    style: TextStyle(fontSize: 11, color: kOnSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],

          if (_showPakan && _showAir) ...[
            const SizedBox(height: 12),
            Divider(color: kSurfaceContainerHighest, thickness: 1),
          ],

          // ── Slider Volume Air ───────────────────────────
          if (_showAir) ...[
            const SizedBox(height: 12),
            _stockProgressRow(
              label: 'Sisa air minum',
              percent: _waterPercent,
              amount: '${_waterAmountMl.round()} ml',
              color: const Color(0xFF1976D2),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Volume Air',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: kOnSurface,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1976D2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$_volumeAir ml',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: kOnPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildAmountSeekBar(
              value: _volumeAir,
              max: _waterLimit,
              color: const Color(0xFF1976D2),
              enabled: _waterLimit > 0,
              onChanged: (val) {
                setState(() => _volumeAir = _normalizeAir(val));
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '0 ml',
                    style: TextStyle(fontSize: 11, color: kOnSurfaceVariant),
                  ),
                  Text(
                    '$_waterLimit ml',
                    style: TextStyle(fontSize: 11, color: kOnSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAmountSeekBar({
    required int value,
    required int max,
    required Color color,
    required bool enabled,
    required ValueChanged<int> onChanged,
  }) {
    final usableMax = max < _minAmount ? _minAmount : max;
    final safeValue = value.clamp(_minAmount, usableMax).toDouble();
    return Row(
      children: [
        _amountButton(
          icon: Icons.remove_rounded,
          color: color,
          enabled: enabled && value > _minAmount,
          onTap: () => onChanged(_decrementStepValue(value)),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              inactiveTrackColor: kSurfaceContainerHighest,
              thumbColor: color,
              overlayColor: color.withOpacity(0.12),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: safeValue,
              min: _minAmount.toDouble(),
              max: usableMax.toDouble(),
              divisions: null,
              onChanged: enabled ? (val) => onChanged(val.round()) : null,
            ),
          ),
        ),
        _amountButton(
          icon: Icons.add_rounded,
          color: color,
          enabled: enabled && value < max,
          onTap: () => onChanged(_incrementStepValue(value, max)),
        ),
      ],
    );
  }

  Widget _amountButton({
    required IconData icon,
    required Color color,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Material(
      color: enabled ? color.withOpacity(0.08) : kSurfaceContainerHigh,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(
            icon,
            color: enabled ? color : kOnSurfaceVariant.withOpacity(0.35),
          ),
        ),
      ),
    );
  }

  Widget _stockProgressRow({
    required String label,
    required int percent,
    required String amount,
    required Color color,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: kOnSurfaceVariant,
              ),
            ),
            Text(
              '$percent%  •  $amount',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: percent / 100,
            minHeight: 8,
            backgroundColor: kSurfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  // ── Section 4: Hari Aktif ────────────────────────────────
  Widget _buildHariAktif() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _labelHeader('Hari Aktif', icon: Icons.calendar_month_outlined),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(7, (i) {
              final active = _hariAktif[i];
              final disabled = _isDayTimePast(i);
              return GestureDetector(
                onTap: disabled
                    ? () => _showCapacityMessage(
                        'Waktu jadwal untuk hari ${_hariLabel[i]} telah terlewati. '
                        'Pilih hari atau jam yang belum lewat, atau aktifkan Ulangi Setiap Minggu.',
                      )
                    : () => setState(() => _hariAktif[i] = !_hariAktif[i]),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: disabled
                        ? kSurfaceContainerLow
                        : (active ? kPrimary : kSurfaceContainerHigh),
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: kPrimary.withOpacity(0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      _hariLabel[i],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: disabled
                            ? kOnSurfaceVariant.withOpacity(0.35)
                            : (active ? kOnPrimary : kOnSurfaceVariant),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _dayActionButton(
                icon: Icons.done_all_rounded,
                label: 'Pilih Semua',
                isPrimary: true,
                onTap: () => setState(() {
                  for (var i = 0; i < _hariAktif.length; i++) {
                    _hariAktif[i] = !_isDayTimePast(i);
                  }
                }),
              ),
              _dayActionButton(
                icon: Icons.clear_all_rounded,
                label: 'Hapus Semua',
                onTap: () => setState(() => _hariAktif.fillRange(0, 7, false)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dayActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return Material(
      color: isPrimary ? kPrimary : kSurfaceContainerLowest,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isPrimary ? kPrimary : kSurfaceContainerHighest,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isPrimary ? kOnPrimary : kOnSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isPrimary ? kOnPrimary : kOnSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Section 5: Ulangi Setiap Minggu ─────────────────────
  Widget _buildUlangi() {
    return _card(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Ulangi Setiap Minggu',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: kOnSurface,
                ),
              ),
              Switch(
                value: _ulangiSetiapMinggu,
                onChanged: (v) => setState(() {
                  _ulangiSetiapMinggu = v;
                  // Saat dimatikan, sanitasi hari yang sudah lewat.
                  // [FIX] _sanitizeOneTimeDays() tetap dipanggil di sini
                  // karena ini adalah aksi eksplisit user, bukan side-effect scroll.
                  if (!v) _sanitizeOneTimeDays();
                }),
                activeColor: kPrimary,
                activeTrackColor: kPrimary.withOpacity(0.3),
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: kSurfaceContainerHigh,
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Deskripsi kontekstual supaya tidak ambigu
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _ulangiSetiapMinggu
                ? _repeatHint(
                    key: const ValueKey('on'),
                    icon: Icons.repeat_rounded,
                    color: kPrimary,
                    text:
                        'Jadwal akan dijalankan setiap minggu pada hari-hari yang dipilih.',
                  )
                : _repeatHint(
                    key: const ValueKey('off'),
                    icon: Icons.looks_one_rounded,
                    color: kOnSurfaceVariant,
                    text:
                        'Jadwal hanya dijalankan sekali pada tanggal terdekat yang valid, '
                        'lalu otomatis dinonaktifkan.',
                  ),
          ),
        ],
      ),
    );
  }

  Widget _repeatHint({
    required Key key,
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Row(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: kOnSurfaceVariant,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  // ── Actions ──────────────────────────────────────────────
  Widget _buildActions(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isAmountAvailable && _hasSelectableDay ? _onSave : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              disabledBackgroundColor: kSurfaceContainerHigh,
              foregroundColor: kOnPrimary,
              disabledForegroundColor: kOnSurfaceVariant,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
              shadowColor: kPrimary.withOpacity(0.3),
            ),
            child: const Text(
              'Simpan Jadwal',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              foregroundColor: kPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Batalkan',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }

  // ── Save Handler ─────────────────────────────────────────
  void _onSave() {
    // [FIX] _sanitizeOneTimeDays() dipanggil di sini (saat save),
    // bukan saat scroll drum. Ini memastikan validasi hari tetap ketat
    // tanpa merusak state pilihan user selama proses editing berlangsung.
    _sanitizeOneTimeDays();

    if (!_hasSelectableDay) {
      _showCapacityMessage(
        'Tidak ada hari aktif yang valid. '
        'Pilih hari dan waktu yang belum terlewati, atau aktifkan Ulangi Setiap Minggu.',
      );
      return;
    }
    if (!_isAmountAvailable) {
      _showCapacityMessage(
        'Jumlah pemberian harus lebih dari 0 dan tidak boleh melebihi kapasitas maksimum.',
      );
      return;
    }

    final time =
        '${_selectedHour.toString().padLeft(2, '0')}:${_selectedMinute.toString().padLeft(2, '0')}';

    // ── Payload sesuai skema Firebase ──────────────────────
    // type  : "pakan_air" | "pakan" | "air"
    // repeat: bool (true = weekly, false = one-time)
    final result = {
      'time': time,
      'type': _typeString,
      'pakan': _showPakan,
      'air': _showAir,
      'repeat': _ulangiSetiapMinggu,
      'portion': _showPakan ? _porsiPakan : 0,
      'water': _showAir ? _volumeAir : 0,
      'days': List<String>.from(_hariLabel),
      'activeDays': List<bool>.from(_hariAktif),
      'active': true,
      'isActive': true,
      'start_at': _firstRunAt()?.millisecondsSinceEpoch,
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Jadwal $time — '
          '${_showPakan ? '$_porsiPakan g pakan' : ''}'
          '${_showPakan && _showAir ? ' & ' : ''}'
          '${_showAir ? '$_volumeAir ml air' : ''}'
          ' berhasil disimpan!',
        ),
        backgroundColor: kPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    Navigator.of(context).pop(result);
  }

  // ── Helpers UI ───────────────────────────────────────────
  Widget _card({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kSurfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kSurfaceContainerLow),
        boxShadow: [
          BoxShadow(
            color: kPrimary.withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String title, {bool showUnderline = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: kOnSurface,
          ),
        ),
        if (showUnderline) ...[
          const SizedBox(height: 4),
          Container(
            width: 60,
            height: 3,
            decoration: BoxDecoration(
              color: kPrimary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ],
    );
  }

  Widget _labelHeader(String label, {IconData? icon}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: kOnSurfaceVariant),
          const SizedBox(width: 6),
        ],
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: kOnSurfaceVariant,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}
