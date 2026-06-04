import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';
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

  // Semua jadwal dari Firebase, key = jadwal_id (e.g. "jadwal_1")
  Map<String, Map<String, dynamic>> _allSchedules = {};
  bool _isLoading = true;

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
  static const List<String> _dayLabels = ['S', 'S', 'R', 'K', 'J', 'S', 'M'];

  @override
  void initState() {
    super.initState();
    _schedulesRef = FirebaseDatabase.instance.ref('schedules');
    _listenSchedules();
  }

  // ── Firebase Listener ───────────────────────────────────
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
        final type = jadwal['type']?.toString() ?? 'pakan_air';

        parsed[key] = {
          'id': key,
          'time': jadwal['time']?.toString() ?? '00:00',
          'repeat': (jadwal['repeat'] == true) ? 'Setiap Hari' : 'Khusus',
          'pakan': type == 'pakan' || type == 'pakan_air',
          'air': type == 'air' || type == 'pakan_air',
          'type': type,
          'portion': (jadwal['portion'] as num?)?.toInt() ?? 0,
          'water': jadwal['water']?.toString() ?? '',
          'days': _dayLabels,
          'activeDays': activeDays,
          'isActive': jadwal['active'] == true,
        };
      });

      // Sort berdasarkan time
      final sortedEntries = parsed.entries.toList()
        ..sort((a, b) => a.value['time'].compareTo(b.value['time']));

      setState(() {
        _allSchedules = Map.fromEntries(sortedEntries);
        _isLoading = false;
      });
    });
  }

  // ── Helper: filter jadwal berdasarkan hari terpilih ─────
  List<MapEntry<String, Map<String, dynamic>>> get _filteredEntries {
    if (_selectedDay == 'Semua') return _allSchedules.entries.toList();
    final dayIdx = _dayIndexMap[_selectedDay];
    if (dayIdx == null) return _allSchedules.entries.toList();
    return _allSchedules.entries.where((e) {
      final activeDays = e.value['activeDays'] as List<bool>;
      return dayIdx < activeDays.length && activeDays[dayIdx];
    }).toList();
  }

  // Jadwal hari ini: isActive = true
  List<MapEntry<String, Map<String, dynamic>>> get _jadwalAktif =>
      _filteredEntries.where((e) => e.value['isActive'] == true).toList();

  // Jadwal tidak aktif (tampil di bawah sebagai "Jadwal Besok")
  List<MapEntry<String, Map<String, dynamic>>> get _jadwalNonAktif =>
      _filteredEntries.where((e) => e.value['isActive'] != true).toList();

  // Hitung jumlah jadwal aktif hari ini (tanpa filter hari)
  int get _totalAktifHariIni =>
      _allSchedules.values.where((v) => v['isActive'] == true).length;

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

    // Tentukan type dari flag pakan/air
    final pakan = data['pakan'] == true;
    final air = data['air'] == true;
    String type = 'pakan';
    if (pakan && air)
      type = 'pakan_air';
    else if (air)
      type = 'air';

    await _schedulesRef.child(id).set({
      'active': data['isActive'] ?? true,
      'days': daysMap,
      'portion': data['portion'] ?? 200,
      'repeat': data['repeat'] == 'Setiap Hari',
      'time': data['time'] ?? '08:00',
      'type': type,
      'water': data['water'] ?? '',
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
            Text(
              '$_totalAktifHariIni Jadwal Aktif Hari Ini',
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

  // ── Day Filter ───────────────────────────────────────────
  Widget _buildDayFilter() {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: _days.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Jadwal Aktif (Hari Ini)
          if (aktif.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Center(
                child: Text(
                  'Tidak ada jadwal aktif',
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

  // ── Jadwal Card (UI sama persis dengan versi dummy) ──────
  Widget _buildJadwalCard({
    required Map<String, dynamic> jadwal,
    required String id,
    required bool isBesok,
  }) {
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
      mainAxisSize: MainAxisSize.min,
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
