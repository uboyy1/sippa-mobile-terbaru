import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../controllers/profile_controller.dart';
import '../models/user_profile.dart';
import 'notifikasi_screen.dart';

class CustomDrawer extends StatelessWidget {
  // Tambahkan parameter ini agar Drawer bisa ganti tab di MainScreen
  final Function(int) onNavigateTab;

  const CustomDrawer({super.key, required this.onNavigateTab});

  static const Color primary = Color(0xFFD62818);
  static const Color onSurface = Color(0xFF1B1C1C);
  static const Color onSurfaceVariant = Color(0xFF5B403D);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFFFCF9F8),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─────────────────────────────────────────────
            // HEADER PROFILE
            // ─────────────────────────────────────────────
            ValueListenableBuilder<UserProfile>(
              valueListenable: ProfileController.profile,
              builder: (context, profile, _) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: primary.withOpacity(0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            profile.initials,
                            style: GoogleFonts.manrope(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        profile.name,
                        style: GoogleFonts.manrope(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: onSurface,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        profile.farmName,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // ─────────────────────────────────────────────
            // NAVIGATION MENU
            // ─────────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _drawerItem(
                    icon: Icons.dashboard_rounded,
                    label: 'Dashboard',
                    isActive: true, // Anda bisa buat ini dinamis jika mau
                    onTap: () {
                      onNavigateTab(0); // Pindah ke Tab Dashboard
                      Navigator.pop(context); // Tutup Drawer
                    },
                  ),
                  _drawerItem(
                    icon: Icons.settings_remote_rounded,
                    label: 'Kontrol',
                    onTap: () {
                      onNavigateTab(1); // Pindah ke Tab Kontrol
                      Navigator.pop(context); // Tutup Drawer
                    },
                  ),
                  _drawerItem(
                    icon: Icons.calendar_today_rounded,
                    label: 'Schedule',
                    onTap: () {
                      onNavigateTab(2); // Pindah ke Tab Schedule
                      Navigator.pop(context); // Tutup Drawer
                    },
                  ),
                  _drawerItem(
                    icon: Icons.person_rounded,
                    label: 'Settings',
                    onTap: () {
                      onNavigateTab(4); // Pindah ke Tab Settings
                      Navigator.pop(context); // Tutup Drawer
                    },
                  ),
                  _drawerItem(
                    icon: Icons.notifications_rounded,
                    label: 'Notifikasi',
                    onTap: () {
                      Navigator.pop(context); // Tutup drawer dulu
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const NotifikasiScreen(),
                        ),
                      );
                    },
                  ),

                  // Divider
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 12,
                    ),
                    child: Divider(
                      color: Colors.grey.withOpacity(0.3),
                      thickness: 1,
                    ),
                  ),

                  _drawerItem(
                    icon: Icons.settings_rounded,
                    label: 'Pengaturan',
                    onTap: () {
                      Navigator.pop(context);
                      onNavigateTab(4);
                    },
                  ),
                  _drawerItem(
                    icon: Icons.logout_rounded,
                    label: 'Keluar',
                    isDanger: true,
                    onTap: () {
                      Navigator.pop(context);
                      // TODO: Proses Logout
                    },
                  ),
                ],
              ),
            ),

            // ─────────────────────────────────────────────
            // FOOTER BRAND
            // ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SmartField',
                    style: GoogleFonts.manrope(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: primary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'v2.4.0-release',
                    style: GoogleFonts.robotoMono(
                      fontSize: 10,
                      color: onSurfaceVariant.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Komponen Reusable untuk Item Menu
  Widget _drawerItem({
    required IconData icon,
    required String label,
    bool isActive = false,
    bool isDanger = false,
    required VoidCallback onTap,
  }) {
    final Color itemColor = isActive
        ? Colors.white
        : (isDanger ? primary : onSurfaceVariant);

    final Color bgColor = isActive ? primary : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: itemColor, size: 22),
              const SizedBox(width: 16),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: itemColor,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
