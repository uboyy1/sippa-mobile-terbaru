import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 120),
        child: ResponsiveContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              _buildSearchAndFilter(),
              const SizedBox(height: 32),
              _buildHariIniSection(),
              const SizedBox(height: 40),
              _buildKemarinSection(),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // SEARCH & FILTER
  // ─────────────────────────────────────────────
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
          border: Border.all(color: outlineVariant.withOpacity(0.7)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
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
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Cari riwayat...',
                  hintStyle: GoogleFonts.inter(color: outline, fontSize: 14),
                ),
                style: GoogleFonts.inter(color: onSurface, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // HARI INI
  // ─────────────────────────────────────────────
  Widget _buildHariIniSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Aktivitas Hari Ini'),
          const SizedBox(height: 20),
          _riwayatCard(
            category: 'Pakan Otomatis',
            title: '06:00 - Pemberian Pakan Berhasil',
            desc: 'Porsi: 200g',
            icon: Icons.check_circle_rounded,
            iconColor: const Color(0xFF16A34A), // green-600
            iconBg: const Color(0xFFF0FDF4), // green-50
            borderColor: const Color(0xFF22C55E), // green-500
          ),
          const SizedBox(height: 16),
          _riwayatCard(
            category: 'Sensor Lingkungan',
            title: '09:45 - Peringatan Suhu Tinggi',
            desc: 'Suhu: 34°C (Batas: 32°C)',
            icon: Icons.warning_rounded,
            iconColor: const Color(0xFFEA580C), // orange-600
            iconBg: const Color(0xFFFFF7ED), // orange-50
            borderColor: const Color(0xFFF97316), // orange-500
            categoryColor: const Color(0xFFF97316).withOpacity(0.8),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // KEMARIN
  // ─────────────────────────────────────────────
  Widget _buildKemarinSection() {
    return Opacity(
      opacity: 0.7,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Aktivitas Kemarin'),
            const SizedBox(height: 20),
            _riwayatCard(
              category: 'Pakan Manual',
              title: '18:00 - Pemberian Pakan Berhasil',
              desc: 'Porsi: 200g',
              icon: Icons.check_circle_outline_rounded,
              iconColor: const Color(0xFF94A3B8), // slate-400
              iconBg: Colors.transparent,
              borderColor: const Color(0xFF94A3B8),
              bgColor: surfaceContainerLow,
            ),
            const SizedBox(height: 16),
            _riwayatCard(
              category: 'Pakan Otomatis',
              title: '12:00 - Pemberian Pakan Berhasil',
              desc: 'Porsi: 200g',
              icon: Icons.check_circle_outline_rounded,
              iconColor: const Color(0xFFCBD5E1), // slate-300
              iconBg: Colors.transparent,
              borderColor: const Color(0xFFCBD5E1),
              bgColor: surfaceContainerLow,
            ),
            const SizedBox(height: 16),
            _riwayatCard(
              category: 'Sistem Perangkat',
              title: '08:30 - Perangkat Terhubung Kembali',
              desc: 'Gateway: SI-Node 04',
              icon: Icons.wifi_rounded,
              iconColor: const Color(0xFF94A3B8), // slate-400
              iconBg: Colors.transparent,
              borderColor: const Color(0xFFCBD5E1),
              bgColor: surfaceContainerLow,
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────
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
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required Color borderColor,
    Color bgColor = Colors.white,
    Color? categoryColor,
  }) {
    return Container(
      height: 96,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: bgColor == Colors.white
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 32,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          // Left Border Indicator
          Container(
            width: 4,
            decoration: BoxDecoration(
              color: borderColor,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(12),
              ),
            ),
          ),
          // Content
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
                  ),
                ],
              ),
            ),
          ),
          // Icon
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
