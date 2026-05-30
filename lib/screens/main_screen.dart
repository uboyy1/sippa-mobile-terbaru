import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Import halaman dan drawer
import 'custom_drawer.dart';
import 'home_screen.dart';
import 'kontrol_manual_screen.dart';
import 'schedule_screen.dart';
import 'riwayat_screen.dart';
import 'settings_screen.dart'; // <-- Import halaman Settings
import '../constants/app_assets.dart';
import '../widgets/responsive_content.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  static const Color primary = Color(0xFFD62818);
  static final _navItems = [
    {'icon': Icons.dashboard_rounded, 'label': 'Dashboard'},
    {'icon': Icons.settings_remote_rounded, 'label': 'Kontrol'},
    {'icon': Icons.calendar_today_rounded, 'label': 'Schedule'},
    {'icon': Icons.history_rounded, 'label': 'Riwayat'},
    {'icon': Icons.settings_rounded, 'label': 'Settings'},
  ];

  // Kunci utama agar child screen bisa membuka drawer
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Fungsi untuk mengganti Tab
  void _onNavTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Fungsi untuk membuka drawer
  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = context.isDesktopWidth;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFFCF9F8),
      drawer: isDesktop ? null : CustomDrawer(onNavigateTab: _onNavTap),
      body: Row(
        children: [
          if (isDesktop) _buildNavigationRail(),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                HomeScreen(onMenuTap: _openDrawer, onNavigateTab: _onNavTap),
                const KontrolManualScreen(), // Index 1
                const ScheduleScreen(), // Index 2
                const RiwayatScreen(), // Index 3
                const SettingsScreen(), // Index 4 <-- Masukkan SettingsScreen di sini
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isDesktop ? null : _buildBottomNav(),
    );
  }

  Widget _buildNavigationRail() {
    return NavigationRail(
      selectedIndex: _selectedIndex,
      onDestinationSelected: _onNavTap,
      backgroundColor: Colors.white,
      selectedIconTheme: const IconThemeData(color: primary),
      unselectedIconTheme: IconThemeData(color: primary.withOpacity(0.35)),
      selectedLabelTextStyle: GoogleFonts.inter(
        color: primary,
        fontWeight: FontWeight.w800,
        fontSize: 12,
      ),
      unselectedLabelTextStyle: GoogleFonts.inter(
        color: primary.withOpacity(0.45),
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      labelType: NavigationRailLabelType.all,
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Image.asset(AppAssets.logo, width: 42, height: 42),
      ),
      destinations: _navItems
          .map(
            (item) => NavigationRailDestination(
              icon: Icon(item['icon'] as IconData),
              selectedIcon: Icon(item['icon'] as IconData),
              label: Text(item['label'] as String),
            ),
          )
          .toList(),
    );
  }

  Widget _buildBottomNav() {
    // Sesuaikan items agar sesuai dengan urutan IndexedStack di atas
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD62818).withOpacity(0.07),
            blurRadius: 32,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_navItems.length, (i) {
              final isActive = _selectedIndex == i;
              return Flexible(
                child: GestureDetector(
                  onTap: () => _onNavTap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFFD62818).withOpacity(0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _navItems[i]['icon'] as IconData,
                          color: isActive
                              ? primary
                              : const Color(0xFFD62818).withOpacity(0.3),
                          size: 22,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _navItems[i]['label'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                            color: isActive
                                ? primary
                                : const Color(0xFFD62818).withOpacity(0.3),
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
