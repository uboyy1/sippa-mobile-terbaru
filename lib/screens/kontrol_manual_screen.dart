import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import '../widgets/responsive_content.dart';

// ============================================================
//  COLOR CONSTANTS
// ============================================================
const Color kPrimary = Color(0xFFD62818);
const Color kPrimaryContainer = Color(0xFFE13A2A);
const Color kOnPrimary = Color(0xFFFFFFFF);
const Color kBackground = Color(0xFFFCF9F8);
const Color kSurfaceContainerLowest = Color(0xFFFFFFFF);
const Color kSurfaceContainerLow = Color(0xFFF6F3F2);
const Color kSurfaceContainer = Color(0xFFF0EDED);
const Color kSurfaceContainerHigh = Color(0xFFEAE7E7);
const Color kSurfaceContainerHighest = Color(0xFFE5E2E1);
const Color kSurfaceVariant = Color(0xFFE5E2E1);
const Color kOnSurface = Color(0xFF1B1C1C);
const Color kOnSurfaceVariant = Color(0xFF5B403D);
const Color kOutlineVariant = Color(0xFFE4BEBA);
const Color kOnPrimaryContainer = Color(0xFFFFF2F0);

// ============================================================
//  KONTROL MANUAL SCREEN
// ============================================================
class KontrolManualScreen extends StatefulWidget {
  const KontrolManualScreen({super.key});

  @override
  State<KontrolManualScreen> createState() => _KontrolManualScreenState();
}

class _KontrolManualScreenState extends State<KontrolManualScreen>
    with TickerProviderStateMixin {
  // ── Firebase refs ────────────────────────────────────────
  late final DatabaseReference _controlRef;
  late final DatabaseReference _statusRef;
  late final DatabaseReference _logsRef;
  late final DatabaseReference _notificationsRef;
  late final DatabaseReference _settingsRef;

  // ── Firebase data (control node) ─────────────────────────
  bool _manualFeed = false;
  bool _manualWater = false;
  int _portion = 0; // gram
  int _waterVolume = 500; // ml
  bool _reloadSched = false;

  // ── Firebase data (status node) ──────────────────────────
  double _feedWeight = 0; // kg — untuk progress bar sisa pakan
  double _waterWeight = 0; // liter — untuk progress bar sisa air
  bool _isDeviceConnected = false;

  // ── UI loading state ─────────────────────────────────────
  bool _isLoadingPakan = false;
  bool _isLoadingAir = false;
  bool _isInitializing = true;

  // ── Kapasitas maksimum dari settings ─────────────────────
  double _feedLimit = 500.0;
  double _waterLimit = 500.0;

  // ── Slider nilai sementara (sebelum dikirim) ─────────────
  static const int _stepAmount = 50;
  static const int _minPortion = 0;
  static const int _minWaterVolume = 0;
  int _sliderPortion = 200; // gram
  int _sliderWater = 500; // ml

  // ── Animation Controllers ─────────────────────────────────
  late AnimationController _pakanBtnController;
  late AnimationController _airBtnController;
  late Animation<double> _pakanBtnScale;
  late Animation<double> _airBtnScale;

  @override
  void initState() {
    super.initState();
    _controlRef = FirebaseDatabase.instance.ref('control');
    _statusRef = FirebaseDatabase.instance.ref('status');
    _logsRef = FirebaseDatabase.instance.ref('logs');
    _notificationsRef = FirebaseDatabase.instance.ref('notifications');
    _settingsRef = FirebaseDatabase.instance.ref('settings');

    _listenControl();
    _listenStatus();
    _listenSettings();

    _pakanBtnController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _airBtnController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _pakanBtnScale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pakanBtnController, curve: Curves.easeInOut),
    );
    _airBtnScale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _airBtnController, curve: Curves.easeInOut),
    );
  }

  // ── Firebase Listeners ────────────────────────────────────
  void _listenControl() {
    _controlRef.onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data == null) return;
      if (!mounted) return;

      setState(() {
        _manualFeed = data['manual_feed'] == true;
        _manualWater = data['manual_water'] == true;
        _portion = (data['portion'] as num?)?.toInt() ?? 0;
        _waterVolume = (data['water_volume'] as num?)?.toInt() ?? 500;
        _reloadSched = data['reload_sched'] == true;

        // Sync slider dengan nilai Firebase (hanya jika tidak sedang loading)
        if (!_isLoadingPakan) _sliderPortion = _normalizePortion(_portion);
        if (!_isLoadingAir) _sliderWater = _normalizeWaterVolume(_waterVolume);

        // Jika manual_feed berubah jadi false → loading selesai
        if (!_manualFeed && _isLoadingPakan) _isLoadingPakan = false;
        if (!_manualWater && _isLoadingAir) _isLoadingAir = false;

        _isInitializing = false;
      });
    });
  }

  void _listenStatus() {
    _statusRef.onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data == null) return;
      if (!mounted) return;

      setState(() {
        _feedWeight = _toStockUnit(data['feed_weight'], _feedLimit);
        _waterWeight = _toStockUnit(data['water_weight'], _waterLimit);
        if (!_isLoadingPakan) {
          _sliderPortion = _normalizePortion(_sliderPortion);
        }
        if (!_isLoadingAir) {
          _sliderWater = _normalizeWaterVolume(_sliderWater);
        }
        // Anggap perangkat terhubung jika ada data status masuk
        _isDeviceConnected = true;
      });
    });
  }

  void _listenSettings() {
    _settingsRef.onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data == null || !mounted) return;

      setState(() {
        _feedLimit = _toPositiveLimit(data['feed_limit'], _feedLimit);
        _waterLimit = _toPositiveLimit(data['water_limit'], _waterLimit);
        _feedWeight = _feedWeight.clamp(0, _feedLimit).toDouble();
        _waterWeight = _waterWeight.clamp(0, _waterLimit).toDouble();
        if (!_isLoadingPakan) {
          _sliderPortion = _normalizePortion(_sliderPortion);
        }
        if (!_isLoadingAir) {
          _sliderWater = _normalizeWaterVolume(_sliderWater);
        }
      });
    });
  }

  @override
  void dispose() {
    _pakanBtnController.dispose();
    _airBtnController.dispose();
    super.dispose();
  }

  // ── Helper: progress ─────────────────────────────────────
  double get _feedProgress => (_feedWeight / _feedLimit).clamp(0.0, 1.0);
  double get _waterProgress => (_waterWeight / _waterLimit).clamp(0.0, 1.0);
  int get _emptyFeedGram =>
      (_feedLimit - _feedWeight).clamp(0, _feedLimit).floor();
  int get _emptyWaterMl =>
      (_waterLimit - _waterWeight).clamp(0, _waterLimit).floor();
  int get _maxFeedAdd => _emptyFeedGram;
  int get _maxWaterAdd => _emptyWaterMl;

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

  int _normalizeStepValue(int value, int min, int max) {
    if (max <= min) return min;
    return value.clamp(min, max).toInt();
  }

  int _incrementStepValue(int value, int max) {
    if (value >= max) return max;
    final next = value + _stepAmount;
    return next >= max ? max : next;
  }

  int _decrementStepValue(int value, int min) {
    if (value <= min) return min;
    final next = value - _stepAmount;
    return next < min ? min : next;
  }

  int _normalizePortion(int value) {
    return _normalizeStepValue(value, _minPortion, _maxFeedAdd);
  }

  int _normalizeWaterVolume(int value) {
    return _normalizeStepValue(value, _minWaterVolume, _maxWaterAdd);
  }

  Future<void> _setFeedPortion(int value) async {
    final nextValue = _normalizePortion(value);
    if (mounted) {
      setState(() => _sliderPortion = nextValue);
    }
    await _controlRef.update({'portion': nextValue});
  }

  Future<void> _setWaterVolume(int value) async {
    final nextValue = _normalizeWaterVolume(value);
    if (mounted) {
      setState(() => _sliderWater = nextValue);
    }
    await _controlRef.update({'water_volume': nextValue});
  }

  DateTime get _nowWita => DateTime.now().toUtc().add(const Duration(hours: 8));

  Future<void> _recordManualEvent({
    required String type,
    required int amount,
    required String unit,
  }) async {
    final now = _nowWita;
    final key = 'manual_${type}_${DateFormat('yyyyMMdd_HHmmss').format(now)}';
    final label = type == 'pakan' ? 'Pakan' : 'Air';
    final desc = '$label $amount$unit berhasil dikirim secara manual.';

    await _logsRef.child(key).set({
      'timestamp': ServerValue.timestamp,
      'type': '${type}_manual',
      'status': 'sukses',
      'title': 'Pemberian $label Manual',
      'desc': desc,
      'value': amount,
      'unit': unit,
    });
    await _notificationsRef.child(key).set({
      'timestamp': ServerValue.timestamp,
      'type': '${type}_manual',
      'target': 'riwayat',
      'title': 'Pemberian $label Manual',
      'desc': desc,
      'read': false,
    });
  }

  // ── Aksi: Beri Pakan ──────────────────────────────────────
  void _showManualMessage(String message, {Color color = kPrimary}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _onBeriPakan() async {
    if (!_isDeviceConnected || _isLoadingPakan) return;
    if (_sliderPortion <= 0) {
      _showManualMessage('Porsi pakan harus lebih dari 0 gram.');
      return;
    }
    if (_sliderPortion > _emptyFeedGram) {
      _showManualMessage(
        'Porsi ${_sliderPortion}g melebihi ruang kosong pakan ${_emptyFeedGram}g.',
      );
      return;
    }

    await _pakanBtnController.forward();
    await _pakanBtnController.reverse();

    setState(() => _isLoadingPakan = true);

    // Tulis ke Firebase: set portion & nyalakan manual_feed
    await _controlRef.update({'portion': _sliderPortion, 'manual_feed': true});
    await _recordManualEvent(type: 'pakan', amount: _sliderPortion, unit: 'g');

    // Tampilkan snackbar konfirmasi
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Perintah beri pakan ${_sliderPortion}g dikirim',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: kPrimary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }

    // manual_feed akan di-reset ke false oleh ESP/device setelah selesai
    // _listenControl() akan otomatis set _isLoadingPakan = false
    // Safety fallback: timeout 10 detik
    await Future.delayed(const Duration(seconds: 10));
    if (mounted && _isLoadingPakan) {
      setState(() => _isLoadingPakan = false);
      await _controlRef.update({'manual_feed': false});
    }
  }

  // ── Aksi: Beri Air ────────────────────────────────────────
  Future<void> _onBeriAir() async {
    if (!_isDeviceConnected || _isLoadingAir) return;
    if (_sliderWater <= 0) {
      _showManualMessage(
        'Volume air harus lebih dari 0 ml.',
        color: const Color(0xFF1976D2),
      );
      return;
    }
    if (_sliderWater > _emptyWaterMl) {
      _showManualMessage(
        'Volume ${_sliderWater}ml melebihi ruang kosong air ${_emptyWaterMl}ml.',
        color: const Color(0xFF1976D2),
      );
      return;
    }

    await _airBtnController.forward();
    await _airBtnController.reverse();

    setState(() => _isLoadingAir = true);

    // Tulis ke Firebase: set water_volume & nyalakan manual_water
    await _controlRef.update({
      'water_volume': _sliderWater,
      'manual_water': true,
    });
    await _recordManualEvent(type: 'air', amount: _sliderWater, unit: 'ml');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Perintah beri air ${_sliderWater}ml dikirim',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFF1976D2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }

    // Safety fallback timeout
    await Future.delayed(const Duration(seconds: 10));
    if (mounted && _isLoadingAir) {
      setState(() => _isLoadingAir = false);
      await _controlRef.update({'manual_water': false});
    }
  }

  // ============================================================
  //  BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: Column(
        children: [
          _buildTopAppBar(),
          Expanded(
            child: _isInitializing
                ? const Center(
                    child: CircularProgressIndicator(color: kPrimary),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                    child: ResponsiveContent(
                      child: Column(
                        children: [
                          _buildBeriPakanCard(),
                          const SizedBox(height: 20),
                          _buildBeriAirCard(),
                          if (_reloadSched) ...[
                            const SizedBox(height: 20),
                            _buildReloadSchedBanner(),
                          ],
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
      color: kPrimary,
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
                'Kontrol Manual',
                style: GoogleFonts.manrope(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Reload Sched Banner ───────────────────────────────────
  Widget _buildReloadSchedBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.sync_rounded, color: Color(0xFFF59E0B), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Jadwal sedang dimuat ulang oleh perangkat...',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Beri Pakan Card ──────────────────────────────────────
  Widget _buildSeekBarWithButtons({
    required int value,
    required int min,
    required int max,
    required Color color,
    required bool enabled,
    required ValueChanged<int> onChanged,
    required ValueChanged<int> onChangeEnd,
  }) {
    final safeMax = max < min ? min : max;
    final safeValue = value.clamp(min, safeMax).toDouble();
    final canDecrease = enabled && value > min;
    final canIncrease = enabled && value < max;

    return Row(
      children: [
        _seekIconButton(
          icon: Icons.remove_rounded,
          color: color,
          enabled: canDecrease,
          onTap: () => onChangeEnd(_decrementStepValue(value, min)),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              inactiveTrackColor: kSurfaceContainerHighest,
              thumbColor: color,
              overlayColor: color.withOpacity(0.1),
              trackHeight: 4,
            ),
            child: Slider(
              value: safeValue,
              min: min.toDouble(),
              max: safeMax.toDouble(),
              divisions: null,
              onChanged: enabled ? (val) => onChanged(val.round()) : null,
              onChangeEnd: enabled ? (val) => onChangeEnd(val.round()) : null,
            ),
          ),
        ),
        _seekIconButton(
          icon: Icons.add_rounded,
          color: color,
          enabled: canIncrease,
          onTap: () => onChangeEnd(_incrementStepValue(value, max)),
        ),
      ],
    );
  }

  Widget _seekIconButton({
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

  Widget _buildBeriPakanCard() {
    final canSendFeed =
        !_isLoadingPakan &&
        _isDeviceConnected &&
        _sliderPortion > 0 &&
        _sliderPortion <= _maxFeedAdd;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kSurfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: kPrimary.withOpacity(0.05),
            blurRadius: 48,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: kPrimary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.grain_rounded,
                  color: kPrimary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Beri Pakan Sekarang',
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: kOnSurface,
                    letterSpacing: -0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Progress Sisa Pakan (dari status Firebase)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sisa pakan',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: kOnSurfaceVariant,
                ),
              ),
              Text(
                '${(_feedProgress * 100).round()}%  •  ${_feedWeight.round()} gram',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: kPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: _feedProgress,
              minHeight: 8,
              backgroundColor: kSurfaceContainerHighest,
              valueColor: const AlwaysStoppedAnimation<Color>(kPrimary),
            ),
          ),

          const SizedBox(height: 20),

          // Slider Porsi
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Porsi pakan',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: kOnSurfaceVariant,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: kPrimary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_sliderPortion gram',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: kPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildSeekBarWithButtons(
            value: _sliderPortion,
            min: _minPortion,
            max: _maxFeedAdd,
            color: kPrimary,
            enabled: !_isLoadingPakan && _maxFeedAdd > 0,
            onChanged: (val) {
              setState(() => _sliderPortion = _normalizePortion(val));
            },
            onChangeEnd: _setFeedPortion,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '0g',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: kOnSurfaceVariant,
                  ),
                ),
                Text(
                  '${_maxFeedAdd}g',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: kOnSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Tombol Beri Pakan
          ScaleTransition(
            scale: _pakanBtnScale,
            child: GestureDetector(
              onTap: canSendFeed ? _onBeriPakan : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: !canSendFeed
                        ? [
                            kPrimary.withOpacity(0.4),
                            kPrimaryContainer.withOpacity(0.4),
                          ]
                        : [kPrimary, kPrimaryContainer],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: !canSendFeed
                      ? []
                      : [
                          BoxShadow(
                            color: kPrimary.withOpacity(0.3),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isLoadingPakan)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    else
                      const Icon(
                        Icons.grain_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    const SizedBox(width: 10),
                    Text(
                      _isLoadingPakan ? 'Mengirim Pakan...' : 'Beri Pakan',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.5,
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

  // ── Beri Air Card ────────────────────────────────────────
  Widget _buildBeriAirCard() {
    const blueColor = Color(0xFF1976D2);
    final canSendWater =
        !_isLoadingAir &&
        _isDeviceConnected &&
        _sliderWater > 0 &&
        _sliderWater <= _maxWaterAdd;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kSurfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kSurfaceVariant.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 48,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: blueColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.water_drop_rounded,
                  color: blueColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Beri Air Sekarang',
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: kOnSurface,
                    letterSpacing: -0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Progress Sisa Air (dari status Firebase)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sisa air minum',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: kOnSurfaceVariant,
                ),
              ),
              Text(
                '${(_waterProgress * 100).round()}%  •  ${_waterWeight.round()} ml',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: blueColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: _waterProgress,
              minHeight: 8,
              backgroundColor: kSurfaceContainerHighest,
              valueColor: const AlwaysStoppedAnimation<Color>(blueColor),
            ),
          ),

          const SizedBox(height: 20),

          // Slider Volume Air
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Volume air',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: kOnSurfaceVariant,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: blueColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_sliderWater ml',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: blueColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildSeekBarWithButtons(
            value: _sliderWater,
            min: _minWaterVolume,
            max: _maxWaterAdd,
            color: blueColor,
            enabled: !_isLoadingAir && _maxWaterAdd > 0,
            onChanged: (val) {
              setState(() => _sliderWater = _normalizeWaterVolume(val));
            },
            onChangeEnd: _setWaterVolume,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '0ml',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: kOnSurfaceVariant,
                  ),
                ),
                Text(
                  '${_maxWaterAdd}ml',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: kOnSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Tombol Beri Air
          ScaleTransition(
            scale: _airBtnScale,
            child: GestureDetector(
              onTap: canSendWater ? _onBeriAir : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 56,
                decoration: BoxDecoration(
                  color: !canSendWater ? blueColor.withOpacity(0.4) : blueColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: !canSendWater
                      ? []
                      : [
                          BoxShadow(
                            color: blueColor.withOpacity(0.3),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isLoadingAir)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    else
                      const Icon(
                        Icons.water_drop_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    const SizedBox(width: 10),
                    Text(
                      _isLoadingAir ? 'Mengirim Air...' : 'Beri Air',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.5,
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
}
