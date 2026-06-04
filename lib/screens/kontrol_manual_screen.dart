import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';
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

  // ── Kapasitas maksimum (sesuaikan dengan hardware) ───────
  static const double _maxFeedKg = 5.0; // 5 kg
  static const double _maxWaterLiter = 20.0; // 20 liter

  // ── Slider nilai sementara (sebelum dikirim) ─────────────
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

    _listenControl();
    _listenStatus();

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
        if (!_isLoadingPakan) _sliderPortion = _portion.clamp(50, 500);
        if (!_isLoadingAir) _sliderWater = _waterVolume.clamp(50, 1000);

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
        _feedWeight = (data['feed_weight'] as num?)?.toDouble() ?? 0;
        _waterWeight = (data['water_weight'] as num?)?.toDouble() ?? 0;
        // Anggap perangkat terhubung jika ada data status masuk
        _isDeviceConnected = true;
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
  double get _feedProgress => (_feedWeight / _maxFeedKg).clamp(0.0, 1.0);
  double get _waterProgress => (_waterWeight / _maxWaterLiter).clamp(0.0, 1.0);

  // ── Aksi: Beri Pakan ──────────────────────────────────────
  Future<void> _onBeriPakan() async {
    if (!_isDeviceConnected || _isLoadingPakan) return;

    await _pakanBtnController.forward();
    await _pakanBtnController.reverse();

    setState(() => _isLoadingPakan = true);

    // Tulis ke Firebase: set portion & nyalakan manual_feed
    await _controlRef.update({'portion': _sliderPortion, 'manual_feed': true});

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

    await _airBtnController.forward();
    await _airBtnController.reverse();

    setState(() => _isLoadingAir = true);

    // Tulis ke Firebase: set water_volume & nyalakan manual_water
    await _controlRef.update({
      'water_volume': _sliderWater,
      'manual_water': true,
    });

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
                          _buildDeviceStatus(),
                          const SizedBox(height: 20),
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

  // ── Device Status ────────────────────────────────────────
  Widget _buildDeviceStatus() {
    final statusColor = _isDeviceConnected
        ? const Color(0xFF10B981)
        : const Color(0xFFEF4444);
    final statusText = _isDeviceConnected
        ? 'Perangkat Terhubung'
        : 'Perangkat Tidak Terhubung';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: kSurfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: statusColor.withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              statusText,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: kOnSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Live indicator ketika ada aksi berjalan
          if (_manualFeed || _manualWater)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: kPrimary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _manualFeed ? 'Memberi Pakan...' : 'Memberi Air...',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: kPrimary,
                ),
              ),
            ),
        ],
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
  Widget _buildBeriPakanCard() {
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
                '${(_feedProgress * 100).round()}%  •  ${_feedWeight.toStringAsFixed(1)} kg',
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
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: kPrimary,
              inactiveTrackColor: kSurfaceContainerHighest,
              thumbColor: kPrimary,
              overlayColor: kPrimary.withOpacity(0.1),
              trackHeight: 4,
            ),
            child: Slider(
              value: _sliderPortion.toDouble(),
              min: 50,
              max: 500,
              divisions: 9,
              onChanged: _isLoadingPakan
                  ? null
                  : (val) => setState(() => _sliderPortion = val.toInt()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '50g',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: kOnSurfaceVariant,
                  ),
                ),
                Text(
                  '500g',
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
              onTap: _isLoadingPakan || !_isDeviceConnected
                  ? null
                  : _onBeriPakan,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isLoadingPakan || !_isDeviceConnected
                        ? [
                            kPrimary.withOpacity(0.4),
                            kPrimaryContainer.withOpacity(0.4),
                          ]
                        : [kPrimary, kPrimaryContainer],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _isLoadingPakan || !_isDeviceConnected
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
                '${(_waterProgress * 100).round()}%  •  ${_waterWeight.toStringAsFixed(1)} L',
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
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: blueColor,
              inactiveTrackColor: kSurfaceContainerHighest,
              thumbColor: blueColor,
              overlayColor: blueColor.withOpacity(0.1),
              trackHeight: 4,
            ),
            child: Slider(
              value: _sliderWater.toDouble(),
              min: 50,
              max: 1000,
              divisions: 19,
              onChanged: _isLoadingAir
                  ? null
                  : (val) => setState(() => _sliderWater = val.toInt()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '50ml',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: kOnSurfaceVariant,
                  ),
                ),
                Text(
                  '1000ml',
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
              onTap: _isLoadingAir || !_isDeviceConnected ? null : _onBeriAir,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 56,
                decoration: BoxDecoration(
                  color: _isLoadingAir || !_isDeviceConnected
                      ? blueColor.withOpacity(0.4)
                      : blueColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _isLoadingAir || !_isDeviceConnected
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
