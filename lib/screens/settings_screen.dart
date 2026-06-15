import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';
import '../controllers/profile_controller.dart';
import '../models/user_profile.dart';
import 'edit_profile_screen.dart';
import '../widgets/responsive_content.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const Color primary = Color(0xFFD62818);
  static const Color primaryFixed = Color(0xFFFFDAD6);
  static const Color surfaceContainerLowest = Colors.white;
  static const Color surfaceContainer = Color(0xFFF0EDED);
  static const Color surfaceContainerHigh = Color(0xFFEAE7E7);
  static const Color onSurface = Color(0xFF1B1C1C);
  static const Color onSurfaceVariant = Color(0xFF5B403D);

  late final DatabaseReference _settingsRef;
  late final TextEditingController _feedLimitController;
  late final TextEditingController _waterLimitController;
  late final TextEditingController _fillPercentController;
  late final TextEditingController _refillPercentController;

  bool _notifPakanHabis = true;
  bool _notifSuhu = true;
  bool _notifJadwal = true;
  bool _notifOffline = true;
  bool _isSavingCapacity = false;

  @override
  void initState() {
    super.initState();
    _settingsRef = FirebaseDatabase.instance.ref('settings');
    _feedLimitController = TextEditingController(text: '0');
    _waterLimitController = TextEditingController(text: '0');
    _fillPercentController = TextEditingController(text: '0');
    _refillPercentController = TextEditingController(text: '0');
    _listenSettings();
  }

  void _listenSettings() {
    _settingsRef.onValue.listen((event) {
      if (!mounted) return;
      final data = event.snapshot.value as Map?;
      if (data == null) return;
      final notifications = data['notifications'] as Map?;
      setState(() {
        _notifPakanHabis = notifications?['stock_alert'] != false;
        _notifSuhu = notifications?['temperature_alert'] != false;
        _notifJadwal = notifications?['schedule_confirmation'] != false;
        _notifOffline = notifications?['offline_alert'] != false;
      });
      _syncControllerText(_feedLimitController, data['feed_limit']);
      _syncControllerText(_waterLimitController, data['water_limit']);
      _syncControllerText(_fillPercentController, data['fill_percent']);
      _syncControllerText(_refillPercentController, data['refill_percent']);
    });
  }

  void _syncControllerText(TextEditingController controller, Object? value) {
    final text = value?.toString() ?? '0';
    if (controller.text == text) return;
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  Future<void> _updateNotificationSetting(
    String key,
    bool value,
    VoidCallback rollback,
  ) async {
    try {
      await _settingsRef.child('notifications').update({key: value});
    } catch (_) {
      if (!mounted) return;
      rollback();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan pengaturan notifikasi')),
      );
    }
  }

  int? _parseNumberSetting(
    TextEditingController controller, {
    bool isPercent = false,
    bool allowZero = true,
  }) {
    final rawValue = controller.text.trim();
    final parsedValue = int.tryParse(rawValue);
    if (parsedValue == null) return null;
    if (!allowZero && parsedValue <= 0) return null;
    return isPercent ? parsedValue.clamp(0, 100).toInt() : parsedValue;
  }

  Future<void> _saveCapacitySettings() async {
    final feedLimit = _parseNumberSetting(
      _feedLimitController,
      allowZero: false,
    );
    final waterLimit = _parseNumberSetting(
      _waterLimitController,
      allowZero: false,
    );
    final fillPercent = _parseNumberSetting(
      _fillPercentController,
      isPercent: true,
    );
    final refillPercent = _parseNumberSetting(
      _refillPercentController,
      isPercent: true,
    );

    if (feedLimit == null ||
        waterLimit == null ||
        fillPercent == null ||
        refillPercent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan angka pengaturan yang valid')),
      );
      return;
    }

    setState(() => _isSavingCapacity = true);
    try {
      await _settingsRef.update({
        'feed_limit': feedLimit,
        'water_limit': waterLimit,
        'fill_percent': fillPercent,
        'refill_percent': refillPercent,
      });
      _feedLimitController.text = feedLimit.toString();
      _waterLimitController.text = waterLimit.toString();
      _fillPercentController.text = fillPercent.toString();
      _refillPercentController.text = refillPercent.toString();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perubahan pengaturan berhasil disimpan')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal menyimpan perubahan pengaturan')),
      );
    } finally {
      if (mounted) setState(() => _isSavingCapacity = false);
    }
  }

  @override
  void dispose() {
    _feedLimitController.dispose();
    _waterLimitController.dispose();
    _fillPercentController.dispose();
    _refillPercentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCF9F8),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Pengaturan',
          style: GoogleFonts.manrope(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 32,
        ).copyWith(bottom: 120),
        child: ResponsiveContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ValueListenableBuilder<UserProfile>(
                valueListenable: ProfileController.profile,
                builder: (context, profile, _) => _buildProfileSection(profile),
              ),
              const SizedBox(height: 48),
              _buildPerangkatSection(),
              const SizedBox(height: 32),
              _buildNotifikasiSection(),
              const SizedBox(height: 32),
              _buildAkunSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection(UserProfile profile) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: primaryFixed.withOpacity(0.3),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
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
                  fontSize: 32,
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
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            profile.email,
            style: GoogleFonts.inter(fontSize: 14, color: onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: _openEditProfile,
            style: OutlinedButton.styleFrom(
              foregroundColor: primary,
              side: const BorderSide(color: primary, width: 2),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: Text(
              'Edit Profil',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerangkatSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(Icons.inventory_2_rounded, 'Kapasitas Pakan & Air'),
        _buildCardContainer(
          children: [
            _buildNumberSettingTile(
              title: 'Batas Daya Tampung Pakan',
              settingKey: 'feed_limit',
              controller: _feedLimitController,
              suffixText: 'g',
            ),
            _buildNumberSettingTile(
              title: 'Batas Daya Tampung Wadah Air',
              settingKey: 'water_limit',
              controller: _waterLimitController,
              suffixText: 'ml',
            ),
            _buildNumberSettingTile(
              title: 'Isi Sampai',
              settingKey: 'fill_percent',
              controller: _fillPercentController,
              suffixText: '%',
            ),
            _buildNumberSettingTile(
              title: 'Mulai Isi Saat Sisa',
              settingKey: 'refill_percent',
              controller: _refillPercentController,
              suffixText: '%',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSavingCapacity ? null : _saveCapacitySettings,
                  icon: _isSavingCapacity
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(
                    _isSavingCapacity ? 'Menyimpan...' : 'Simpan Perubahan',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNotifikasiSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(Icons.notifications_rounded, 'Notifikasi'),
        _buildCardContainer(
          children: [
            _buildSwitchTile(
              title: 'Notifikasi Pakan dan Air Habis',
              value: _notifPakanHabis,
              onChanged: (val) {
                final previous = _notifPakanHabis;
                setState(() => _notifPakanHabis = val);
                _updateNotificationSetting(
                  'stock_alert',
                  val,
                  () => setState(() => _notifPakanHabis = previous),
                );
              },
            ),
            _buildSwitchTile(
              title: 'Peringatan Suhu dan Kelembaban',
              value: _notifSuhu,
              onChanged: (val) {
                final previous = _notifSuhu;
                setState(() => _notifSuhu = val);
                _updateNotificationSetting(
                  'temperature_alert',
                  val,
                  () => setState(() => _notifSuhu = previous),
                );
              },
            ),
            _buildSwitchTile(
              title: 'Konfirmasi Jadwal',
              value: _notifJadwal,
              onChanged: (val) {
                final previous = _notifJadwal;
                setState(() => _notifJadwal = val);
                _updateNotificationSetting(
                  'schedule_confirmation',
                  val,
                  () => setState(() => _notifJadwal = previous),
                );
              },
            ),
            _buildSwitchTile(
              title: 'Perangkat Offline',
              value: _notifOffline,
              onChanged: (val) {
                final previous = _notifOffline;
                setState(() => _notifOffline = val);
                _updateNotificationSetting(
                  'offline_alert',
                  val,
                  () => setState(() => _notifOffline = previous),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAkunSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(Icons.person_rounded, 'Akun'),
        _buildCardContainer(
          children: [
            _buildListTile(
              title: 'Tentang SIPPA',
              onTap: () => _showInfoDialog(
                'Tentang SIPPA',
                'SIPPA membantu pemantauan dan pemberian pakan berbasis IoT untuk kandang yang lebih terukur.',
              ),
              trailing: Text(
                'Versi 1.0.0',
                style: GoogleFonts.inter(fontSize: 14, color: onSurfaceVariant),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: primary, size: 24),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardContainer({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildListTile({
    required String title,
    required Widget trailing,
    Color titleColor = onSurface,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap ?? () {},
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: titleColor,
                ),
              ),
            ),
            const SizedBox(width: 16),
            trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: onSurface,
                ),
              ),
            ),
            const SizedBox(width: 16),
            CupertinoSwitch(
              value: value,
              onChanged: onChanged,
              activeColor: primary,
              trackColor: surfaceContainerHigh,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberSettingTile({
    required String title,
    required String settingKey,
    required TextEditingController controller,
    required String suffixText,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  settingKey,
                  style: GoogleFonts.robotoMono(
                    fontSize: 12,
                    color: onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 116,
            child: TextField(
              controller: controller,
              textAlign: TextAlign.right,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: onSurface,
              ),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: surfaceContainer,
                suffixText: suffixText,
                suffixStyle: GoogleFonts.inter(color: onSurfaceVariant),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _saveCapacitySettings(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditProfile() async {
    final updated = await Navigator.of(context).push<UserProfile>(
      MaterialPageRoute(
        builder: (_) =>
            EditProfileScreen(profile: ProfileController.profile.value),
      ),
    );

    if (updated == null || !mounted) return;
    ProfileController.profile.value = updated;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profil berhasil diperbarui')));
  }

  void _showInfoDialog(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
