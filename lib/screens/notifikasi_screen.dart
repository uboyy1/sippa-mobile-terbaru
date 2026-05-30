import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/responsive_content.dart';

class NotifikasiScreen extends StatefulWidget {
  const NotifikasiScreen({super.key});

  @override
  State<NotifikasiScreen> createState() => _NotifikasiScreenState();
}

class _NotifikasiScreenState extends State<NotifikasiScreen> {
  static const Color primary = Color(0xFFD62818);
  static const Color surfaceContainerLow = Color(0xFFF6F3F2);
  static const Color surfaceContainerHigh = Color(0xFFEAE7E7);
  static const Color onSurface = Color(0xFF1B1C1C);
  static const Color onSurfaceVariant = Color(0xFF5B403D);
  static const Color error = Color(0xFFBA1A1A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCF9F8),
      appBar: AppBar(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Text(
          'Notifikasi',
          style: GoogleFonts.manrope(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              foregroundColor: Colors.white.withOpacity(0.9),
            ),
            child: Text(
              'Tandai Semua Dibaca',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ResponsiveContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildNotificationList(),
              const SizedBox(height: 32),
              _buildFooterActions(),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------
  // NOTIFICATION LIST SECTION
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildNotificationList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Terbaru',
              style: GoogleFonts.manrope(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: onSurface,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '1',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Daftar Item Notifikasi
        _notificationItem(
          title: 'Peringatan Suhu dan Kelembaban',
          desc:
              'Suhu mencapai 34°C dan kelembaban 74%. Kipas pendingin zona B telah diaktifkan otomatis.',
          time: '1 jam lalu',
          icon: Icons.thermostat_rounded,
          iconBgColor: const Color(0xFFFFEDD5),
          iconColor: const Color(0xFFEA580C),
          borderColor: const Color(0xFFF97316),
          isUnread: true,
          timeColor: const Color(0xFFEA580C),
        ),
        const SizedBox(height: 12),
        _notificationItem(
          title: 'Pemberian Pakan Berhasil',
          desc: 'Pakan 200g telah diberikan pada jadwal pagi (07:00).',
          time: '3 jam lalu',
          icon: Icons.check_circle_rounded,
          iconBgColor: const Color(0xFFD1FAE5),
          iconColor: const Color(0xFF059669),
          borderColor: const Color(0xFF10B981),
          isUnread: false,
        ),
        const SizedBox(height: 12),
        _notificationItem(
          title: 'Perangkat Terputus',
          desc:
              'ESP32 tidak merespons selama 5 menit. Koneksi kembali normal setelah reset.',
          time: 'Kemarin, 22:15',
          icon: Icons.wifi_off_rounded,
          iconBgColor: surfaceContainerHigh,
          iconColor: onSurfaceVariant,
          borderColor: Colors.transparent, // tidak pakai border
          isUnread: false,
          bgColor: surfaceContainerLow,
        ),
      ],
    );
  }

  Widget _notificationItem({
    required String title,
    required String desc,
    required String time,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required Color borderColor,
    required bool isUnread,
    Color bgColor = Colors.white,
    Color? timeColor,
  }) {
    return Opacity(
      opacity: isUnread ? 1.0 : 0.7,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: bgColor == Colors.white
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Border Color
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(16),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: iconBgColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: iconColor, size: 24),
                      ),
                      const SizedBox(width: 16),
                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.manrope(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              desc,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: onSurfaceVariant,
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              time,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color:
                                    timeColor ??
                                    onSurfaceVariant.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Unread Dot
                      if (isUnread)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 6),
                          decoration: BoxDecoration(
                            color: error,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: error.withOpacity(0.5),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // FOOTER ACTIONS
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildFooterActions() {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Lihat Lebih Banyak',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.expand_more_rounded, size: 20),
            ],
          ),
        ),
      ],
    );
  }
}
