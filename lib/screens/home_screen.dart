import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'notifikasi_screen.dart';
import '../widgets/responsive_content.dart';

// Pastikan riwayat_screen.dart sudah ada di folder yang sama
// import 'riwayat_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onMenuTap;
  final Function(int) onNavigateTab;

  const HomeScreen({
    super.key,
    required this.onMenuTap,
    required this.onNavigateTab,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color primary = Color(0xFFD62818);
  static const Color primaryContainer = Color(0xFFE13A2A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFDC2626);
  static const Color success = Color(0xFF16A34A);
  static const Color surfaceContainerLowest = Colors.white;
  static const Color surfaceContainerHigh = Color(0xFFEAE7E7);
  static const Color onSurface = Color(0xFF1B1C1C);
  static const Color onSurfaceVariant = Color(0xFF5B403D);
  static const Color outlineVariant = Color(0xFFE4BEBA);

  ({String label, Color color}) _temperatureStatus(int value) {
    if (value >= 22 && value <= 25) return (label: 'Normal', color: success);
    if (value >= 26 && value <= 29) return (label: 'Waspada', color: warning);
    return (label: 'Bahaya', color: danger);
  }

  ({String label, Color color}) _humidityStatus(int value) {
    if (value < 50) return (label: 'Terlalu Kering', color: warning);
    if (value <= 70) return (label: 'Ideal', color: success);
    return (label: 'Terlalu Lembab', color: danger);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCF9F8),
      body: Column(
        children: [
          _buildTopAppBar(),
          _buildStatusStrip(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 100),
              child: ResponsiveContent(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    _buildSectionStatusKandang(),
                    const SizedBox(height: 32),
                    _buildSectionGrafik(),
                    const SizedBox(height: 32),
                    _buildSectionAksiCepat(),
                    const SizedBox(height: 32),
                    _buildSectionJadwal(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopAppBar() {
    return Container(
      color: const Color(0xFFD62818),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 16,
      ),
      child: ResponsiveContent(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              context.isDesktopWidth
                  ? const SizedBox(width: 40)
                  : _iconButton(Icons.menu_rounded, onTap: widget.onMenuTap),
              Text(
                'SIPPA',
                style: GoogleFonts.manrope(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              Stack(
                children: [
                  _iconButton(
                    Icons.notifications_outlined,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotifikasiScreen(),
                        ),
                      );
                    },
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '2',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconButton(IconData icon, {required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  Widget _buildStatusStrip() {
    return Container(
      color: primaryContainer,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ResponsiveContent(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFF4ADE80),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4ADE80).withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Perangkat Terhubung',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionStatusKandang() {
    final suhu = 28;
    final kelembaban = 64;
    final suhuStatus = _temperatureStatus(suhu);
    final kelembabanStatus = _humidityStatus(kelembaban);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Status Kandang',
            style: GoogleFonts.manrope(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: onSurface,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 155,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              _statusCard(
                icon: Icons.thermostat_rounded,
                iconColor: primary,
                borderColor: primary,
                label: 'Suhu',
                value: '$suhu°C',
                status: suhuStatus.label,
                statusColor: suhuStatus.color,
              ),
              const SizedBox(width: 16),
              _statusCard(
                icon: Icons.water_drop_rounded,
                leadingIcon: _humidityIcon(),
                iconColor: primary,
                borderColor: primary,
                label: 'Kelembaban',
                value: '$kelembaban%',
                status: kelembabanStatus.label,
                statusColor: kelembabanStatus.color,
              ),
              const SizedBox(width: 16),
              _stockCard(
                icon: Icons.grain_rounded,
                label: 'Stok Pakan',
                percentage: 65,
                amount: '3.2 kg',
              ),
              const SizedBox(width: 16),
              _stockCard(
                icon: Icons.water_drop_rounded,
                label: 'Stok Air Minum',
                percentage: 78,
                amount: '12.4 liter',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statusCard({
    required IconData icon,
    Widget? leadingIcon,
    required Color iconColor,
    required Color borderColor,
    required String label,
    required String value,
    required String status,
    required Color statusColor,
  }) {
    return Container(
      width: 168,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: borderColor, width: 4)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD62818).withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              leadingIcon ?? Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: onSurfaceVariant,
                    letterSpacing: 0.8,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.manrope(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: onSurface,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            status,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _humidityIcon() {
    return SizedBox(
      width: 20,
      height: 20,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            left: 0,
            top: 1,
            child: Icon(Icons.water_drop_rounded, color: primary, size: 17),
          ),
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: surfaceContainerLowest,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.percent_rounded, color: primary, size: 9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stockCard({
    required IconData icon,
    required String label,
    required int percentage,
    required String amount,
  }) {
    return Container(
      width: 168,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: const Border(left: BorderSide(color: primary, width: 4)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD62818).withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: primary, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: onSurfaceVariant,
                    letterSpacing: 0.8,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '$percentage%',
              style: GoogleFonts.manrope(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: onSurface,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            amount,
            style: GoogleFonts.inter(fontSize: 11, color: onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionGrafik() {
    final suhuSpots = [
      const FlSpot(0, 30),
      const FlSpot(2, 28),
      const FlSpot(4, 29),
      const FlSpot(6, 27),
      const FlSpot(8, 26),
      const FlSpot(10, 28),
      const FlSpot(12, 32),
      const FlSpot(14, 33),
      const FlSpot(16, 31),
      const FlSpot(18, 29),
      const FlSpot(20, 28),
      const FlSpot(22, 27),
      const FlSpot(24, 26),
    ];
    final kelembabanSpots = [
      const FlSpot(0, 58),
      const FlSpot(2, 60),
      const FlSpot(4, 62),
      const FlSpot(6, 64),
      const FlSpot(8, 66),
      const FlSpot(10, 68),
      const FlSpot(12, 72),
      const FlSpot(14, 70),
      const FlSpot(16, 67),
      const FlSpot(18, 65),
      const FlSpot(20, 63),
      const FlSpot(22, 61),
      const FlSpot(24, 60),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          _lineChartCard(
            title: 'Suhu Kandang 24 Jam',
            spots: suhuSpots,
            minY: 22,
            maxY: 34,
            interval: 2,
            unit: '°',
            color: const Color(0xFFF59E0B),
          ),
          const SizedBox(height: 20),
          _lineChartCard(
            title: 'Kelembaban Kandang 24 Jam',
            spots: kelembabanSpots,
            minY: 0,
            maxY: 100,
            interval: 20,
            unit: '%',
            color: const Color(0xFF1976D2),
          ),
        ],
      ),
    );
  }

  Widget _lineChartCard({
    required String title,
    required List<FlSpot> spots,
    required double minY,
    required double maxY,
    required double interval,
    required String unit,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      decoration: BoxDecoration(
        color: surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD62818).withOpacity(0.04),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.manrope(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: onSurface,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: 24,
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: outlineVariant.withOpacity(0.5),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border(
                    left: BorderSide(color: outlineVariant.withOpacity(0.5)),
                    bottom: BorderSide(color: outlineVariant.withOpacity(0.5)),
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: interval,
                      getTitlesWidget: (val, _) => Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          '${val.toInt()}$unit',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 6,
                      getTitlesWidget: (val, _) {
                        final labels = {
                          0.0: '00:00',
                          6.0: '06:00',
                          12.0: '12:00',
                          18.0: '18:00',
                          24.0: '24:00',
                        };
                        return Text(
                          labels[val] ?? '',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            color: onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: color,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          color.withOpacity(0.22),
                          color.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------
  // UPDATE PADA BAGIAN INI AGAR TOMBOL BERWARNA PUTIH
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildSectionAksiCepat() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Aksi Cepat',
            style: GoogleFonts.manrope(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: onSurface,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 720;
              return GridView.count(
                crossAxisCount: isWide ? 4 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: isWide ? 2.25 : 1.55,
                children: [
                  _aksiButton(
                    icon: Icons.grain_rounded,
                    label: 'Beri Pakan',
                    onTap: () => widget.onNavigateTab(1),
                  ),
                  _aksiButton(
                    icon: Icons.water_drop_rounded,
                    label: 'Beri Air',
                    onTap: () => widget.onNavigateTab(1),
                  ),
                  _aksiButton(
                    icon: Icons.calendar_today_rounded,
                    label: 'Atur Jadwal',
                    onTap: () => widget.onNavigateTab(2),
                  ),
                  _aksiButton(
                    icon: Icons.history_rounded,
                    label: 'Riwayat',
                    onTap: () => widget.onNavigateTab(3),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _aksiButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: surfaceContainerLowest,
      borderRadius: BorderRadius.circular(14),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: primary.withOpacity(0.1),
        highlightColor: primary.withOpacity(0.05),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: outlineVariant.withOpacity(0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: primary),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: onSurface,
                  letterSpacing: 0.2,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionJadwal() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD62818).withOpacity(0.04),
              blurRadius: 32,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Jadwal Aktif Hari Ini',
              style: GoogleFonts.manrope(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: onSurface,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 20),
            _jadwalItem(time: '06:00', label: 'Porsi Pagi', isDone: true),
            const SizedBox(height: 16),
            _jadwalItem(time: '12:00', label: 'Porsi Siang', isDone: true),
            const SizedBox(height: 16),
            _jadwalItem(time: '18:00', label: 'Porsi Malam', isDone: false),
          ],
        ),
      ),
    );
  }

  Widget _jadwalItem({
    required String time,
    required String label,
    required bool isDone,
  }) {
    return Opacity(
      opacity: isDone ? 1.0 : 0.6,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDone ? const Color(0xFFF0FDF4) : surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isDone ? Icons.check_rounded : Icons.schedule_rounded,
              size: 18,
              color: isDone ? const Color(0xFF16A34A) : onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  time,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: onSurface,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            isDone ? 'Selesai' : 'Mendatang',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isDone ? const Color(0xFF16A34A) : onSurfaceVariant,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
