import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

class ManualControlBackend {
  const ManualControlBackend();

  Future<bool> isDeviceConnected() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return true;
  }

  Future<void> sendFeedCommand(int grams) async {
    await Future.delayed(const Duration(seconds: 2));
  }

  Future<void> sendWaterCommand(int milliliters) async {
    await Future.delayed(const Duration(seconds: 2));
  }
}

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
  final ManualControlBackend _backend = const ManualControlBackend();
  bool _isDeviceConnected = false;

  // --- State Pakan ---
  static const int _maxPorsiPakan = 500;
  int _porsiPakan = 200;
  bool _isLoadingPakan = false;

  // --- State Air ---
  static const int _maxVolumeAir = 1000;
  int _volumeAir = 150;
  bool _isLoadingAir = false;

  // --- Animation Controllers ---
  late AnimationController _pakanBtnController;
  late AnimationController _airBtnController;
  late Animation<double> _pakanBtnScale;
  late Animation<double> _airBtnScale;

  @override
  void initState() {
    super.initState();
    _loadDeviceStatus();
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

  Future<void> _loadDeviceStatus() async {
    final isConnected = await _backend.isDeviceConnected();
    if (!mounted) return;
    setState(() => _isDeviceConnected = isConnected);
  }

  @override
  void dispose() {
    _pakanBtnController.dispose();
    _airBtnController.dispose();
    super.dispose();
  }

  // --- Functions ---
  void _onBeriPakan() async {
    if (!_isDeviceConnected) {
      return;
    }

    await _pakanBtnController.forward();
    await _pakanBtnController.reverse();
    setState(() => _isLoadingPakan = true);
    await _backend.sendFeedCommand(_maxPorsiPakan);
    setState(() {
      _porsiPakan = _maxPorsiPakan;
      _isLoadingPakan = false;
    });
  }

  void _onBeriAir() async {
    if (!_isDeviceConnected) {
      return;
    }

    await _airBtnController.forward();
    await _airBtnController.reverse();
    setState(() => _isLoadingAir = true);
    await _backend.sendWaterCommand(_maxVolumeAir);
    setState(() {
      _volumeAir = _maxVolumeAir;
      _isLoadingAir = false;
    });
  }

  // --------------------------------------------------------
  //  BUILD
  // --------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: Column(
        children: [
          _buildTopAppBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
              child: ResponsiveContent(
                child: Column(
                  children: [
                    _buildDeviceStatus(),
                    const SizedBox(height: 20),
                    _buildBeriPakanCard(),
                    const SizedBox(height: 20),
                    _buildBeriAirCard(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------
  //  TOP APP BAR
  // --------------------------------------------------------
  Widget _buildTopAppBar() {
    return Container(
      color: const Color(0xFFD62818),
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
                  fontSize: 22, // Disesuaikan sedikit agar seimbang dengan Home
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

  // --------------------------------------------------------
  //  DEVICE STATUS
  // --------------------------------------------------------
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
        ],
      ),
    );
  }

  // --------------------------------------------------------
  //  BERI PAKAN CARD
  // --------------------------------------------------------
  Widget _buildBeriPakanCard() {
    final pakanProgress = _porsiPakan / _maxPorsiPakan;

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

          const SizedBox(height: 18),

          // Porsi Progress Bar
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
                '${(pakanProgress * 100).round()}%',
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
              value: pakanProgress,
              minHeight: 8,
              backgroundColor: kSurfaceContainerHighest,
              valueColor: const AlwaysStoppedAnimation<Color>(kPrimary),
            ),
          ),

          const SizedBox(height: 20),

          // Beri Pakan Button
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
                  gradient: const LinearGradient(
                    colors: [kPrimary, kPrimaryContainer],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
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
                      'Beri Pakan',
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

  // --------------------------------------------------------
  //  BERI AIR CARD
  // --------------------------------------------------------
  Widget _buildBeriAirCard() {
    final airProgress = _volumeAir / _maxVolumeAir;

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
                  color: const Color(0xFF1976D2).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.water_drop_rounded,
                  color: Color(0xFF1976D2),
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

          const SizedBox(height: 18),

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
                '${(airProgress * 100).round()}%',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1976D2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: airProgress,
              minHeight: 8,
              backgroundColor: kSurfaceContainerHighest,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF1976D2),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Beri Air Button
          ScaleTransition(
            scale: _airBtnScale,
            child: GestureDetector(
              onTap: _isLoadingAir || !_isDeviceConnected ? null : _onBeriAir,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 56,
                decoration: BoxDecoration(
                  color: _isLoadingAir
                      ? const Color(0xFF1976D2).withOpacity(0.8)
                      : const Color(0xFF1976D2),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1976D2).withOpacity(0.3),
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
                      'Beri Air',
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
