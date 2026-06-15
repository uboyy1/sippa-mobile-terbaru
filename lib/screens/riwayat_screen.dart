import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';
import '../widgets/responsive_content.dart';

class RiwayatScreen extends StatefulWidget {
  const RiwayatScreen({super.key});

  @override
  State<RiwayatScreen> createState() => _RiwayatScreenState();
}

class _RiwayatScreenState extends State<RiwayatScreen> {
  static const Color primary = Color(0xFFD62818);
  static const Color surfaceContainerLowest = Colors.white;
  static const Color surfaceContainerLow = Color(0xFFF6F3F2);
  static const Color surfaceContainerHighest = Color(0xFFE5E2E1);
  static const Color onSurface = Color(0xFF1B1C1C);
  static const Color onSurfaceVariant = Color(0xFF5B403D);
  static const Color outline = Color(0xFF8F6F6C);
  static const Color outlineVariant = Color(0xFFE4BEBA);

  late final DatabaseReference _logsRef;

  // Semua log dari Firebase, sudah diparse
  List<Map<String, dynamic>> _allLogs = [];
  List<Map<String, dynamic>> _filteredLogs = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _logsRef = FirebaseDatabase.instance.ref('logs');
    _listenLogs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Firebase: ambil semua log aktif 24 jam terakhir ─────
  void _listenLogs() {
    _logsRef.onValue.listen((event) {
      final raw = event.snapshot.value;
      if (!mounted) return;

      if (raw == null) {
        setState(() {
          _allLogs = [];
          _filteredLogs = [];
          _isLoading = false;
        });
        return;
      }

      final rawMap = Map<String, dynamic>.from(raw as Map);
      final parsed = <Map<String, dynamic>>[];

      rawMap.forEach((key, value) {
        final log = Map<String, dynamic>.from(value as Map);
        final timestamp = log['timestamp'];
        final dt = _parseTimestamp(timestamp);
        if (dt != null && _nowWita.difference(dt).inHours >= 24) {
          _logsRef.child(key.toString()).remove();
          return;
        }
        parsed.add({
          'id': key,
          'timestamp': timestamp,
          'type': log['type']?.toString() ?? 'sistem',
          'status': log['status']?.toString() ?? 'sukses',
          'title': log['title']?.toString() ?? '-',
          'desc': log['desc']?.toString() ?? '',
          'value': log['value'],
          'unit': log['unit']?.toString() ?? '',
        });
      });

      // Sort terbaru di atas (descending by key/timestamp)
      parsed.sort((a, b) {
        final aTime = _parseTimestamp(a['timestamp']);
        final bTime = _parseTimestamp(b['timestamp']);
        if (aTime != null && bTime != null) return bTime.compareTo(aTime);
        return b['id'].compareTo(a['id']);
      });

      setState(() {
        _allLogs = parsed;
        _filteredLogs = _applySearch(parsed, _searchQuery);
        _isLoading = false;
      });
    });
  }

  // ── Search filter ────────────────────────────────────────
  List<Map<String, dynamic>> _applySearch(
    List<Map<String, dynamic>> logs,
    String query,
  ) {
    if (query.isEmpty) return logs;
    final q = query.toLowerCase();
    return logs.where((log) {
      return log['title'].toString().toLowerCase().contains(q) ||
          log['desc'].toString().toLowerCase().contains(q) ||
          log['type'].toString().toLowerCase().contains(q);
    }).toList();
  }

  void _onSearch(String query) {
    setState(() {
      _searchQuery = query;
      _filteredLogs = _applySearch(_allLogs, query);
    });
  }

  Future<void> _deleteAllLogs() async {
    await _logsRef.remove();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Semua riwayat berhasil dihapus',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: primary,
      ),
    );
  }

  // ── Kelompokkan logs berdasarkan tanggal ─────────────────
  Map<String, List<Map<String, dynamic>>> _groupByDate(
    List<Map<String, dynamic>> logs,
  ) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (final log in logs) {
      String dateKey;
      if (_isPakanAirLog(log)) {
        dateKey = 'Aktivitas Hari Ini';
      } else {
        dateKey = 'Riwayat Sensor';
      }
      grouped.putIfAbsent(dateKey, () => []).add(log);
    }
    return grouped;
  }

  // ── Visual config per type & status ──────────────────────
  ({
    IconData icon,
    Color iconColor,
    Color iconBg,
    Color borderColor,
    Color? categoryColor,
    String categoryLabel,
    Color bgColor,
  })
  _logVisual(Map<String, dynamic> log) {
    final type = log['type'].toString();
    final status = log['status'].toString();
    final isOld = type.contains('kemarin') || log['_isOld'] == true;

    // Warna berdasarkan status
    if (status == 'peringatan') {
      return (
        icon: Icons.warning_rounded,
        iconColor: const Color(0xFFEA580C),
        iconBg: const Color(0xFFFFF7ED),
        borderColor: const Color(0xFFF97316),
        categoryColor: const Color(0xFFF97316).withValues(alpha: 0.8),
        categoryLabel: _categoryLabel(type),
        bgColor: Colors.white,
      );
    }

    if (status == 'gagal') {
      return (
        icon: Icons.cancel_rounded,
        iconColor: primary,
        iconBg: const Color(0xFFFFF2F0),
        borderColor: primary,
        categoryColor: primary,
        categoryLabel: _categoryLabel(type),
        bgColor: Colors.white,
      );
    }

    // sukses — bedakan berdasarkan type
    switch (type) {
      case 'pakan_otomatis':
      case 'pakan_air_otomatis':
      case 'pakan_manual':
      case 'auto_refill_pakan':
        return (
          icon: isOld
              ? Icons.check_circle_outline_rounded
              : Icons.check_circle_rounded,
          iconColor: isOld ? const Color(0xFF94A3B8) : const Color(0xFF16A34A),
          iconBg: isOld ? Colors.transparent : const Color(0xFFF0FDF4),
          borderColor: isOld
              ? const Color(0xFF94A3B8)
              : const Color(0xFF22C55E),
          categoryColor: null,
          categoryLabel: _categoryLabel(type),
          bgColor: isOld ? surfaceContainerLow : Colors.white,
        );
      case 'air_otomatis':
      case 'air_manual':
      case 'auto_refill_air':
        return (
          icon: isOld
              ? Icons.check_circle_outline_rounded
              : Icons.check_circle_rounded,
          iconColor: isOld ? const Color(0xFF94A3B8) : const Color(0xFF1976D2),
          iconBg: isOld ? Colors.transparent : const Color(0xFFE3F2FD),
          borderColor: isOld
              ? const Color(0xFF94A3B8)
              : const Color(0xFF1976D2),
          categoryColor: null,
          categoryLabel: _categoryLabel(type),
          bgColor: isOld ? surfaceContainerLow : Colors.white,
        );
      case 'sistem':
      default:
        return (
          icon: Icons.wifi_rounded,
          iconColor: const Color(0xFF94A3B8),
          iconBg: Colors.transparent,
          borderColor: const Color(0xFFCBD5E1),
          categoryColor: null,
          categoryLabel: _categoryLabel(type),
          bgColor: isOld ? surfaceContainerLow : Colors.white,
        );
    }
  }

  String _categoryLabel(String type) {
    switch (type) {
      case 'pakan_otomatis':
        return 'Pakan Otomatis';
      case 'pakan_air_otomatis':
        return 'Pakan & Air Otomatis';
      case 'pakan_manual':
        return 'Pakan Manual';
      case 'auto_refill_pakan':
        return 'Isi Ulang Pakan Otomatis';
      case 'air_otomatis':
        return 'Air Otomatis';
      case 'air_manual':
        return 'Air Manual';
      case 'auto_refill_air':
        return 'Isi Ulang Air Otomatis';
      case 'sensor':
        return 'Sensor Lingkungan';
      case 'sensor_suhu':
        return 'Sensor Suhu';
      case 'sensor_kelembaban':
        return 'Sensor Kelembaban';
      case 'stok_pakan':
        return 'Stok Pakan';
      case 'stok_air':
        return 'Stok Air';
      case 'sistem':
        return 'Sistem Perangkat';
      case 'perangkat_offline':
        return 'Perangkat Offline';
      default:
        return type;
    }
  }

  DateTime get _nowWita => DateTime.now().toUtc().add(const Duration(hours: 8));

  DateTime? _parseTimestamp(Object? raw) {
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

  bool _isPakanAirLog(Map<String, dynamic> log) {
    final type = log['type'].toString();
    return const {
      'pakan_otomatis',
      'pakan_air_otomatis',
      'pakan_manual',
      'auto_refill_pakan',
      'stok_pakan',
      'air_otomatis',
      'air_manual',
      'auto_refill_air',
      'stok_air',
    }.contains(type);
  }

  String _relativeTime(Object? raw) {
    final dt = _parseTimestamp(raw);
    if (dt == null) return '-';
    final diff = _nowWita.difference(dt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inHours < 1) return '${diff.inMinutes} menit lalu';
    return '${diff.inHours} jam lalu';
  }

  // ── Parse jam dari timestamp ─────────────────────────────
  // ============================================================
  //  BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCF9F8),
      appBar: AppBar(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Riwayat',
          style: GoogleFonts.manrope(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: _allLogs.isEmpty ? null : _deleteAllLogs,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white.withValues(alpha: 0.45),
            ),
            icon: const Icon(Icons.delete_sweep_rounded, size: 18),
            label: Text(
              'Hapus Semua',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 120),
              child: ResponsiveContent(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    _buildSearchAndFilter(),
                    const SizedBox(height: 32),
                    if (_filteredLogs.isEmpty)
                      _buildEmptyState()
                    else
                      _buildGroupedLogs(),
                  ],
                ),
              ),
            ),
    );
  }

  // ── Search Bar ───────────────────────────────────────────
  Widget _buildSearchAndFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        height: 56,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: outlineVariant.withValues(alpha: 0.7)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 28,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, color: outline, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: _onSearch,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Cari riwayat...',
                  hintStyle: GoogleFonts.inter(color: outline, fontSize: 14),
                ),
                style: GoogleFonts.inter(color: onSurface, fontSize: 14),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchController.clear();
                  _onSearch('');
                },
                child: const Icon(
                  Icons.close_rounded,
                  color: outline,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Grouped Logs ─────────────────────────────────────────
  Widget _buildGroupedLogs() {
    final grouped = _groupByDate(_filteredLogs);

    // Urutan: Hari Ini → Kemarin → tanggal lainnya
    final orderedKeys = <String>[];
    if (grouped.containsKey('Aktivitas Hari Ini')) {
      orderedKeys.add('Aktivitas Hari Ini');
    }
    if (grouped.containsKey('Riwayat Sensor')) {
      orderedKeys.add('Riwayat Sensor');
    }
    for (final k in grouped.keys) {
      if (!orderedKeys.contains(k)) {
        orderedKeys.add(k);
      }
    }

    return Column(
      children: orderedKeys.asMap().entries.map((entry) {
        final dateLabel = entry.value;
        final logs = grouped[dateLabel]!;

        return Padding(
          padding: const EdgeInsets.only(bottom: 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(dateLabel),
                const SizedBox(height: 20),
                ...logs.asMap().entries.map((e) {
                  final logData = Map<String, dynamic>.from(e.value);
                  final visual = _logVisual(logData);
                  final time = _relativeTime(logData['timestamp']);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _riwayatCard(
                      category: visual.categoryLabel,
                      title: logData['title'],
                      desc: logData['desc'],
                      time: time,
                      icon: visual.icon,
                      iconColor: visual.iconColor,
                      iconBg: visual.iconBg,
                      borderColor: visual.borderColor,
                      bgColor: visual.bgColor,
                      categoryColor: visual.categoryColor,
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Empty State ──────────────────────────────────────────
  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.history_rounded, size: 56, color: outlineVariant),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty
                  ? 'Belum ada riwayat aktivitas'
                  : 'Tidak ada hasil untuk "$_searchQuery"',
              style: GoogleFonts.inter(fontSize: 14, color: onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────
  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: onSurface,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: Container(height: 1, color: surfaceContainerHighest)),
      ],
    );
  }

  Widget _riwayatCard({
    required String category,
    required String title,
    required String desc,
    required String time,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required Color borderColor,
    Color bgColor = Colors.white,
    Color? categoryColor,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 108),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: bgColor == Colors.white
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 32,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            decoration: BoxDecoration(
              color: borderColor,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(12),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    category.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: categoryColor ?? outlineVariant,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: onSurface,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: GoogleFonts.inter(fontSize: 12, color: outline),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    time,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 64,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
