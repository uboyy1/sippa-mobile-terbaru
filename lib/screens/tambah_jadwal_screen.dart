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

  // ── NEWː Porsi pakan & volume air ───────────────────────
  static const int _stepAmount = 50;
  static const int _minAmount = 50;
  int _feedLimit = 500;
  int _waterLimit = 500;

  int _porsiPakan = 200; // gram, range 50-500
  int _volumeAir = 500; // ml, range 50-500
  double _feedAmountGram = 0;
  double _waterAmountMl = 0;
  bool _isStatusLoaded = false;
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
      final time = (initial['time'] as String? ?? '06:30').split(':');
      _selectedHour = int.tryParse(time.first) ?? 6;
      _selectedMinute = time.length > 1 ? int.tryParse(time[1]) ?? 30 : 30;

      final hasPakan = initial['pakan'] == true;
      final hasAir = initial['air'] == true;
      if (hasPakan && hasAir) {
        _selectedJenis = 0;
      } else if (hasPakan) {
        _selectedJenis = 1;
      } else {
        _selectedJenis = 2;
      }

      // Load porsi & volume dari Firebase jika ada
      _porsiPakan = _normalizePakan(
        (initial['portion'] as num?)?.toInt() ?? 200,
      );

      final waterRaw = initial['water'];
      if (waterRaw is num) {
        _volumeAir = _normalizeAir(waterRaw.toInt());
      } else if (waterRaw is String && waterRaw.isNotEmpty) {
        _volumeAir = _normalizeAir(int.tryParse(waterRaw) ?? 500);
      }

      final activeDays = initial['activeDays'];
      if (activeDays is List && activeDays.length == 7) {
        _hariAktif
          ..clear()
          ..addAll(activeDays.map((d) => d == true));
      }

      _ulangiSetiapMinggu =
          initial['repeat'] == 'Setiap Minggu' ||
          initial['repeat'] == 'Setiap Hari';
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

  // ── Apakah pakan ditampilkan? ────────────────────────────
  int _normalizeAmount(int value, int max) {
    if (max <= _minAmount) return _minAmount;
    if (value >= max) return max;
    final clamped = value.clamp(_minAmount, max);
    final stepped = ((clamped / _stepAmount).round() * _stepAmount).toInt();
    return stepped.clamp(_minAmount, max).toInt();
  }

  int _normalizePakan(int value) => _normalizeAmount(value, _feedLimit);
  int _normalizeAir(int value) => _normalizeAmount(value, _waterLimit);

  bool get _showPakan => _selectedJenis == 0 || _selectedJenis == 1;
  bool get _showAir => _selectedJenis == 0 || _selectedJenis == 2;
  double get _feedProgress => (_feedAmountGram / _feedLimit).clamp(0.0, 1.0);
  double get _waterProgress => (_waterAmountMl / _waterLimit).clamp(0.0, 1.0);
  int get _feedPercent => (_feedProgress * 100).round();
  int get _waterPercent => (_waterProgress * 100).round();
  int get _emptyFeedGram =>
      (_feedLimit - _feedAmountGram).clamp(0, _feedLimit).floor();
  int get _emptyWaterMl =>
      (_waterLimit - _waterAmountMl).clamp(0, _waterLimit).floor();
  int get _maxAddFeed => _normalizeMaxAdd(_emptyFeedGram);
  int get _maxAddWater => _normalizeMaxAdd(_emptyWaterMl);
  bool get _isSelectedStockLowEnough =>
      (!_showPakan || _feedPercent <= 50) && (!_showAir || _waterPercent <= 50);

  bool get _isAmountAvailable {
    if (!_isStatusLoaded) return false;
    if (!_isSelectedStockLowEnough) return false;
    if (_showPakan && (_maxAddFeed < _minAmount || _porsiPakan > _maxAddFeed)) {
      return false;
    }
    if (_showAir && (_maxAddWater < _minAmount || _volumeAir > _maxAddWater)) {
      return false;
    }
    return true;
  }

  DateTime get _nowWita => DateTime.now().toUtc().add(const Duration(hours: 8));

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
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 7));
    }
    return scheduled;
  }

  DateTime? _firstRunAt() {
    DateTime? first;
    for (var i = 0; i < _hariAktif.length; i++) {
      if (!_hariAktif[i]) continue;
      final date = _ulangiSetiapMinggu
          ? _nextScheduleDateForDay(i)
          : _scheduleDateForDay(i);
      if (first == null || date.isBefore(first)) {
        first = date;
      }
    }
    return first;
  }

  bool _isDayTimePast(int dayIndex) {
    if (_ulangiSetiapMinggu) return false;
    return !_scheduleDateForDay(dayIndex).isAfter(_nowWita);
  }

  void _sanitizeOneTimeDays() {
    if (_ulangiSetiapMinggu) return;
    for (var i = 0; i < _hariAktif.length; i++) {
      if (_isDayTimePast(i)) {
        _hariAktif[i] = false;
      }
    }
  }

  bool get _hasSelectableDay {
    for (var i = 0; i < _hariAktif.length; i++) {
      if (_hariAktif[i] && !_isDayTimePast(i)) return true;
    }
    return false;
  }

  int _normalizeMaxAdd(int value) {
    if (value < _minAmount) return 0;
    return value;
  }

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
    return value >= _minAmount ? value : fallback;
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
        _porsiPakan = _normalizeSelectedAmount(_porsiPakan, _maxAddFeed);
        _volumeAir = _normalizeSelectedAmount(_volumeAir, _maxAddWater);
      });
    });
  }

  void _listenStatus() {
    _statusRef.onValue.listen((event) {
      if (!mounted) return;
      final data = event.snapshot.value as Map?;
      if (data == null) {
        setState(() => _isStatusLoaded = true);
        return;
      }

      final feed = _toScheduleUnit(data['feed_weight']).clamp(0, _feedLimit);
      final water = _toScheduleUnit(data['water_weight']).clamp(0, _waterLimit);
      setState(() {
        _feedAmountGram = feed.toDouble();
        _waterAmountMl = water.toDouble();
        _isStatusLoaded = true;
        _porsiPakan = _normalizeSelectedAmount(_porsiPakan, _maxAddFeed);
        _volumeAir = _normalizeSelectedAmount(_volumeAir, _maxAddWater);
      });
    });
  }

  int _normalizeSelectedAmount(int value, int maxAdd) {
    if (maxAdd < _minAmount) return _minAmount;
    return _normalizeAmount(value, maxAdd);
  }

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

  String _stockRequirementMessage() {
    final parts = <String>[];
    if (_showPakan && _feedPercent > 50) {
      parts.add('pakan $_feedPercent%');
    }
    if (_showAir && _waterPercent > 50) {
      parts.add('air $_waterPercent%');
    }
    return 'Jadwal otomatis belum dapat dibuat karena persediaan ${parts.join(' dan ')} masih di atas 50%. Silakan tunggu hingga stok turun sampai setengah kapasitas atau kurang.';
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
              // ── NEW: Porsi section (muncul sesuai jenis) ──
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
                    onChanged: (i) => setState(() {
                      _selectedHour = i;
                      _sanitizeOneTimeDays();
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
                    onChanged: (i) => setState(() {
                      _selectedMinute = i * 5;
                      _sanitizeOneTimeDays();
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
                    _porsiPakan = _normalizeSelectedAmount(
                      _porsiPakan,
                      _maxAddFeed,
                    );
                    _volumeAir = _normalizeSelectedAmount(
                      _volumeAir,
                      _maxAddWater,
                    );
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

  // ── Section 3 (NEW): Porsi Pakan & Volume Air ────────────
  Widget buildCapacityInfo() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Kapasitas Tersedia', showUnderline: true),
          const SizedBox(height: 16),
          if (!_isStatusLoaded)
            const Center(child: CircularProgressIndicator(color: kPrimary))
          else ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 620;
                final cards = [
                  capacityTile(
                    icon: Icons.grain_rounded,
                    title: 'Sisa Pakan Saat Ini',
                    current: '${_feedAmountGram.round()} g',
                    percent: _feedPercent,
                    emptyLabel: 'Kapasitas kosong $_emptyFeedGram g',
                    maxLabel: 'Maksimal tambah $_maxAddFeed g',
                    color: kPrimary,
                  ),
                  capacityTile(
                    icon: Icons.water_drop_rounded,
                    title: 'Sisa Air Saat Ini',
                    current: '${_waterAmountMl.round()} ml',
                    percent: _waterPercent,
                    emptyLabel: 'Kapasitas kosong $_emptyWaterMl ml',
                    maxLabel: 'Maksimal tambah $_maxAddWater ml',
                    color: const Color(0xFF1976D2),
                  ),
                ];
                if (!isWide) {
                  return Column(
                    children: [cards[0], const SizedBox(height: 12), cards[1]],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: 12),
                    Expanded(child: cards[1]),
                  ],
                );
              },
            ),
            if (!_isSelectedStockLowEnough) ...[
              const SizedBox(height: 14),
              capacityWarning(_stockRequirementMessage()),
            ] else if (!_isAmountAvailable) ...[
              const SizedBox(height: 14),
              capacityWarning(
                'Jumlah yang dimasukkan melebihi kapasitas yang tersedia. Silakan sesuaikan dengan kapasitas kosong saat ini.',
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget capacityTile({
    required IconData icon,
    required String title,
    required String current,
    required int percent,
    required String emptyLabel,
    required String maxLabel,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kSurfaceContainerHighest),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: kOnSurface,
                  ),
                ),
              ),
              Text(
                '$percent%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 8,
              backgroundColor: kSurfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            current,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
              fontFamily: 'Manrope',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            emptyLabel,
            style: const TextStyle(fontSize: 12, color: kOnSurfaceVariant),
          ),
          const SizedBox(height: 2),
          Text(
            maxLabel,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: kOnSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget capacityWarning(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF97316)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFFF97316),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: Color(0xFF9A3412),
              ),
            ),
          ),
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
              divisions: ((usableMax - _minAmount) / _stepAmount).ceil().clamp(
                1,
                100,
              ),
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

  Widget _buildPorsiSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Jumlah Pemberian', showUnderline: true),

          // ── Slider Porsi Pakan ───────────────────────────
          if (_showPakan) ...[
            const SizedBox(height: 20),
            _amountGroupTitle('Pakan', kPrimary),
            const SizedBox(height: 12),
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
                      Text(
                        'Porsi Pakan',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: kOnSurface,
                        ),
                      ),
                      // Badge nilai
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
              max: _maxAddFeed,
              color: kPrimary,
              enabled: _maxAddFeed >= _minAmount,
              onChanged: (val) {
                final next = _normalizeSelectedAmount(val, _maxAddFeed);
                if (val > _maxAddFeed) {
                  _showCapacityMessage(
                    'Jumlah yang dimasukkan melebihi kapasitas yang tersedia. Silakan sesuaikan dengan kapasitas kosong saat ini.',
                  );
                }
                setState(() => _porsiPakan = next);
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '50 g',
                    style: TextStyle(fontSize: 11, color: kOnSurfaceVariant),
                  ),
                  Text(
                    '${_maxAddFeed > 0 ? _maxAddFeed : 0} g',
                    style: TextStyle(fontSize: 11, color: kOnSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],

          // Divider jika keduanya tampil
          if (_showPakan && _showAir) ...[
            const SizedBox(height: 12),
            Divider(color: kSurfaceContainerHighest, thickness: 1),
          ],

          // ── Slider Volume Air ───────────────────────────
          if (_showAir) ...[
            const SizedBox(height: 12),
            _amountGroupTitle('Air Minum', const Color(0xFF1976D2)),
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
                      Text(
                        'Volume Air',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: kOnSurface,
                        ),
                      ),
                      // Badge nilai
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
              max: _maxAddWater,
              color: const Color(0xFF1976D2),
              enabled: _maxAddWater >= _minAmount,
              onChanged: (val) {
                final next = _normalizeSelectedAmount(val, _maxAddWater);
                if (val > _maxAddWater) {
                  _showCapacityMessage(
                    'Jumlah yang dimasukkan melebihi kapasitas yang tersedia. Silakan sesuaikan dengan kapasitas kosong saat ini.',
                  );
                }
                setState(() => _volumeAir = next);
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '50 ml',
                    style: TextStyle(fontSize: 11, color: kOnSurfaceVariant),
                  ),
                  Text(
                    '${_maxAddWater > 0 ? _maxAddWater : 0} ml',
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

  // ── Section 4: Hari Aktif ────────────────────────────────
  Widget _amountGroupTitle(String label, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

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
                        'Waktu jadwal untuk hari ${_hariLabel[i]} telah terlewati. Pilih hari atau jam yang belum lewat, atau aktifkan Ulangi Setiap Minggu.',
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

  // ── Section 5: Ulangi ────────────────────────────────────
  Widget _buildUlangi() {
    return _card(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
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
              _sanitizeOneTimeDays();
            }),
            activeColor: kPrimary,
            activeTrackColor: kPrimary.withOpacity(0.3),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: kSurfaceContainerHigh,
          ),
        ],
      ),
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
    final time =
        '${_selectedHour.toString().padLeft(2, '0')}:${_selectedMinute.toString().padLeft(2, '0')}';

    final hasPakan = _selectedJenis == 0 || _selectedJenis == 1;
    final hasAir = _selectedJenis == 0 || _selectedJenis == 2;

    if (!_isSelectedStockLowEnough) {
      _showCapacityMessage(_stockRequirementMessage());
      return;
    }
    _sanitizeOneTimeDays();
    if (!_hasSelectableDay) {
      _showCapacityMessage(
        'Tidak ada hari aktif yang valid. Pilih hari dan waktu yang belum terlewati, atau aktifkan Ulangi Setiap Minggu.',
      );
      return;
    }
    if (!_isAmountAvailable) {
      _showCapacityMessage(
        'Jumlah yang dimasukkan melebihi kapasitas yang tersedia. Silakan sesuaikan dengan kapasitas kosong saat ini.',
      );
      return;
    }

    final result = {
      'time': time,
      'repeat': _ulangiSetiapMinggu ? 'Setiap Minggu' : 'Khusus',
      'pakan': hasPakan,
      'air': hasAir,
      // ── NEW fields ──
      'portion': hasPakan ? _porsiPakan : 0,
      'water': hasAir ? _volumeAir : 0,
      // ────────────────
      'days': List<String>.from(_hariLabel),
      'activeDays': List<bool>.from(_hariAktif),
      'isActive': true,
      'start_at': _firstRunAt()?.millisecondsSinceEpoch,
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Jadwal $time — '
          '${hasPakan ? '$_porsiPakan g pakan' : ''}'
          '${hasPakan && hasAir ? ' & ' : ''}'
          '${hasAir ? '$_volumeAir ml air' : ''}'
          ' berhasil disimpan!',
        ),
        backgroundColor: kPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    Navigator.of(context).pop(result);
  }

  // ── Helpers ──────────────────────────────────────────────
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
