import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

  // Data jadwal
  final List<Map<String, dynamic>> _jadwalHariIni = [
    {
      'time': '06:00',
      'repeat': 'Setiap Hari',
      'pakan': true,
      'air': true,
      'days': ['S', 'S', 'R', 'K', 'J', 'S', 'M'],
      'activeDays': [true, true, true, true, true, true, true],
      'isActive': true,
    },
    {
      'time': '12:00',
      'repeat': 'Setiap Hari',
      'pakan': true,
      'air': false,
      'days': ['S', 'S', 'R', 'K', 'J', 'S', 'M'],
      'activeDays': [true, true, true, true, true, true, true],
      'isActive': true,
    },
  ];

  final List<Map<String, dynamic>> _jadwalBesok = [
    {
      'time': '08:00',
      'repeat': 'Khusus',
      'pakan': false,
      'air': true,
      'days': ['S', 'S', 'R', 'K', 'J', 'S', 'M'],
      'activeDays': [false, true, false, false, false, false, false],
      'isActive': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCF9F8),
      body: Column(
        children: [
          _buildTopAppBar(),
          Expanded(
            child: SingleChildScrollView(
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

  // ─────────────────────────────────────────────
  // TOP APP BAR
  // ─────────────────────────────────────────────
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
                'Jadwal Pakan',
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

  // ─────────────────────────────────────────────
  // SUMMARY STRIP
  // ─────────────────────────────────────────────
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
            Text(
              '5 Jadwal Aktif Hari Ini',
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // DAY FILTER
  // ─────────────────────────────────────────────
  Widget _buildDayFilter() {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: _days.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
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

  // ─────────────────────────────────────────────
  // JADWAL LIST
  // ─────────────────────────────────────────────
  Widget _buildJadwalList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Jadwal Hari Ini
          ..._jadwalHariIni.asMap().entries.map((e) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildJadwalCard(e.value, false, e.key),
            );
          }),

          // Separator Besok
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Jadwal Besok',
              style: GoogleFonts.manrope(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: onSurface,
                letterSpacing: -0.5,
              ),
            ),
          ),

          // Jadwal Besok
          ..._jadwalBesok.asMap().entries.map((e) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildJadwalCard(e.value, true, e.key),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildJadwalCard(
    Map<String, dynamic> jadwal,
    bool isBesok,
    int index,
  ) {
    final bool isActive = jadwal['isActive'] as bool;
    final List<String> days = List<String>.from(jadwal['days']);
    final List<bool> activeDays = List<bool>.from(jadwal['activeDays']);

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
                    // Time + Badge + Toggle
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
                                    jadwal['repeat'],
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: isActive
                                          ? primary
                                          : onSurfaceVariant,
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
                            // Custom Toggle
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (isBesok) {
                                    _jadwalBesok[index]['isActive'] = !isActive;
                                  } else {
                                    _jadwalHariIni[index]['isActive'] =
                                        !isActive;
                                  }
                                });
                              },
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
                                onTap: () =>
                                    _showJadwalActions(jadwal, isBesok, index),
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
                          _infoChip(Icons.grain_rounded, 'Pakan'),
                        if (jadwal['air'] == true)
                          _infoChip(Icons.water_drop_rounded, 'Air'),
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
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: active ? primary : surfaceContainerHigh,
                            shape: BoxShape.circle,
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
      children: [
        Icon(icon, size: 16, color: onSurfaceVariant),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 13, color: onSurfaceVariant),
        ),
      ],
    );
  }

  Future<void> _showJadwalActions(
    Map<String, dynamic> jadwal,
    bool isBesok,
    int index,
  ) async {
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
                    _editJadwal(jadwal, isBesok, index);
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
                    _deleteJadwal(isBesok, index);
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

  Future<void> _editJadwal(
    Map<String, dynamic> jadwal,
    bool isBesok,
    int index,
  ) async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => TambahJadwalScreen(initialJadwal: jadwal),
      ),
    );

    if (!mounted || result == null) return;
    setState(() {
      if (isBesok) {
        _jadwalBesok[index] = result;
      } else {
        _jadwalHariIni[index] = result;
      }
    });
  }

  void _deleteJadwal(bool isBesok, int index) {
    setState(() {
      if (isBesok) {
        _jadwalBesok.removeAt(index);
      } else {
        _jadwalHariIni.removeAt(index);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Jadwal berhasil dihapus'),
        backgroundColor: primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // FAB
  // ─────────────────────────────────────────────
  Widget _buildFAB() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => _navigateToTambahJadwal(),
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
          onPressed: () => _navigateToTambahJadwal(),
          backgroundColor: primary,
          elevation: 6,
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
        ),
      ],
    );
  }

  Future<void> _navigateToTambahJadwal() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const TambahJadwalScreen()),
    );

    if (!mounted || result == null) return;
    setState(() {
      _jadwalHariIni.add(result);
    });
  }
}
