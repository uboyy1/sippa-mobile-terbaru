import 'package:flutter/material.dart';
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
  int _porsiPakan = 200; // gram, range 50–500
  int _volumeAir = 500; // ml,   range 50–1000

  // S M T W T F S  (index 0..6)
  final List<bool> _hariAktif = [true, true, true, true, true, false, false];
  final List<String> _hariLabel = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  bool _ulangiSetiapMinggu = true;

  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;

  @override
  void initState() {
    super.initState();
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
      _porsiPakan = (initial['portion'] as num?)?.toInt() ?? 200;
      _porsiPakan = _porsiPakan.clamp(50, 500);

      final waterRaw = initial['water'];
      if (waterRaw is num) {
        _volumeAir = waterRaw.toInt().clamp(50, 1000);
      } else if (waterRaw is String && waterRaw.isNotEmpty) {
        _volumeAir = (int.tryParse(waterRaw) ?? 500).clamp(50, 1000);
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
  bool get _showPakan => _selectedJenis == 0 || _selectedJenis == 1;
  bool get _showAir => _selectedJenis == 0 || _selectedJenis == 2;

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
      actions: [
        TextButton(
          onPressed: _onSave,
          child: const Text(
            'Simpan',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ],
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
                    onChanged: (i) => setState(() => _selectedHour = i),
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
                    onChanged: (i) => setState(() => _selectedMinute = i * 5),
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
                  onTap: () => setState(() => _selectedJenis = i),
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
  Widget _buildPorsiSection() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Jumlah Pemberian', showUnderline: true),

          // ── Slider Porsi Pakan ───────────────────────────
          if (_showPakan) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: kPrimary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.grain_rounded,
                    color: kPrimary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
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
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: kPrimary,
                inactiveTrackColor: kSurfaceContainerHighest,
                thumbColor: kPrimary,
                overlayColor: kPrimary.withOpacity(0.12),
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              ),
              child: Slider(
                value: _porsiPakan.toDouble(),
                min: 50,
                max: 500,
                divisions: 9, // step 50g
                onChanged: (val) => setState(() => _porsiPakan = val.toInt()),
              ),
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
                    '500 g',
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
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1976D2).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.water_drop_rounded,
                    color: Color(0xFF1976D2),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
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
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: const Color(0xFF1976D2),
                inactiveTrackColor: kSurfaceContainerHighest,
                thumbColor: const Color(0xFF1976D2),
                overlayColor: const Color(0xFF1976D2).withOpacity(0.12),
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              ),
              child: Slider(
                value: _volumeAir.toDouble(),
                min: 50,
                max: 1000,
                divisions: 19, // step 50ml
                onChanged: (val) => setState(() => _volumeAir = val.toInt()),
              ),
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
                    '1000 ml',
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
  Widget _buildHariAktif() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _labelHeader('Hari Aktif', icon: Icons.calendar_month_outlined),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final active = _hariAktif[i];
              return GestureDetector(
                onTap: () => setState(() => _hariAktif[i] = !_hariAktif[i]),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active ? kPrimary : kSurfaceContainerHigh,
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
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: active ? kOnPrimary : kOnSurfaceVariant,
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
                onTap: () => setState(() => _hariAktif.fillRange(0, 7, true)),
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
            onChanged: (v) => setState(() => _ulangiSetiapMinggu = v),
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
            onPressed: _onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              foregroundColor: kOnPrimary,
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
    final aktif = <String>[];
    for (int i = 0; i < 7; i++) {
      if (_hariAktif[i]) aktif.add(_hariLabel[i]);
    }

    final time =
        '${_selectedHour.toString().padLeft(2, '0')}:${_selectedMinute.toString().padLeft(2, '0')}';

    final hasPakan = _selectedJenis == 0 || _selectedJenis == 1;
    final hasAir = _selectedJenis == 0 || _selectedJenis == 2;

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
