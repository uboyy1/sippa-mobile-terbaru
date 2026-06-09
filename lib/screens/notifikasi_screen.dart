import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
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

  late final DatabaseReference _notificationsRef;
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  bool _showAll = false;

  @override
  void initState() {
    super.initState();
    _notificationsRef = FirebaseDatabase.instance.ref('notifications');
    _listenNotifications();
  }

  void _listenNotifications() {
    _notificationsRef.onValue.listen((event) {
      if (!mounted) return;
      final raw = event.snapshot.value;
      if (raw == null) {
        setState(() {
          _notifications = [];
          _isLoading = false;
        });
        return;
      }

      final rawMap = Map<String, dynamic>.from(raw as Map);
      final parsed = <Map<String, dynamic>>[];
      rawMap.forEach((key, value) {
        final notif = Map<String, dynamic>.from(value as Map);
        final timestamp = notif['timestamp'];
        final dt = _parseTimestamp(timestamp);
        if (dt != null && _nowWita.difference(dt).inHours >= 24) {
          _notificationsRef.child(key.toString()).remove();
          return;
        }
        parsed.add({
          'id': key,
          'title': notif['title']?.toString() ?? 'Notifikasi',
          'desc':
              notif['desc']?.toString() ?? notif['message']?.toString() ?? '',
          'type': notif['type']?.toString() ?? 'sistem',
          'target': notif['target']?.toString() ?? '',
          'timestamp': timestamp,
          'read': notif['read'] == true || notif['isRead'] == true,
        });
      });

      parsed.sort((a, b) {
        final aTime = _parseTimestamp(a['timestamp']);
        final bTime = _parseTimestamp(b['timestamp']);
        if (aTime != null && bTime != null) return bTime.compareTo(aTime);
        return b['id'].compareTo(a['id']);
      });

      setState(() {
        _notifications = parsed;
        _isLoading = false;
      });
    });
  }

  int get _unreadCount => _notifications.where((n) => n['read'] != true).length;

  List<Map<String, dynamic>> get _visibleNotifications {
    if (_showAll || _notifications.length <= 10) return _notifications;
    return _notifications.take(10).toList();
  }

  Future<void> _markAllRead() async {
    final updates = <String, Object?>{};
    for (final notif in _notifications) {
      final id = notif['id']?.toString();
      if (id == null || notif['read'] == true) continue;
      updates['$id/read'] = true;
      updates['$id/read_at'] = ServerValue.timestamp;
    }
    if (updates.isNotEmpty) await _notificationsRef.update(updates);
  }

  Future<void> _deleteAllNotifications() async {
    await _notificationsRef.remove();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Semua notifikasi berhasil dihapus',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: primary,
      ),
    );
  }

  Future<void> _openNotification(Map<String, dynamic> notif) async {
    final id = notif['id']?.toString();
    if (id != null && notif['read'] != true) {
      await _notificationsRef.child(id).update({
        'read': true,
        'read_at': ServerValue.timestamp,
      });
    }
    if (!mounted) return;
    Navigator.of(context).pop(_targetTab(notif));
  }

  int _targetTab(Map<String, dynamic> notif) {
    final target = notif['target'].toString().toLowerCase();
    final type = notif['type'].toString().toLowerCase();
    if (target.contains('kontrol') || type.contains('manual')) return 1;
    if (target.contains('jadwal') || target.contains('schedule')) return 2;
    if (target.contains('riwayat') || type.contains('log')) return 3;
    if (target.contains('setting') || target.contains('pengaturan')) return 4;
    return 0;
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

  String _timeLabel(Object? raw) {
    final dt = _parseTimestamp(raw);
    if (dt == null) {
      final text = raw?.toString() ?? '';
      return text.isEmpty ? '-' : text;
    }
    final diff = _nowWita.difference(dt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inHours < 1) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return DateFormat('dd MMM yyyy, HH:mm', 'id').format(dt);
  }

  ({IconData icon, Color iconBg, Color iconColor, Color border}) _visual(
    String type,
  ) {
    if (type.contains('suhu') || type.contains('warning')) {
      return (
        icon: Icons.thermostat_rounded,
        iconBg: const Color(0xFFFFEDD5),
        iconColor: const Color(0xFFEA580C),
        border: const Color(0xFFF97316),
      );
    }
    if (type.contains('offline') || type.contains('perangkat')) {
      return (
        icon: Icons.wifi_off_rounded,
        iconBg: surfaceContainerHigh,
        iconColor: onSurfaceVariant,
        border: Colors.transparent,
      );
    }
    if (type.contains('air')) {
      return (
        icon: Icons.water_drop_rounded,
        iconBg: const Color(0xFFE3F2FD),
        iconColor: const Color(0xFF1976D2),
        border: const Color(0xFF1976D2),
      );
    }
    if (type.contains('pakan')) {
      return (
        icon: Icons.grain_rounded,
        iconBg: const Color(0xFFD1FAE5),
        iconColor: const Color(0xFF059669),
        border: const Color(0xFF10B981),
      );
    }
    return (
      icon: Icons.notifications_rounded,
      iconBg: surfaceContainerLow,
      iconColor: onSurfaceVariant,
      border: primary,
    );
  }

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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ResponsiveContent(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildNotificationList(),
                    if (_notifications.length > 10 && !_showAll) ...[
                      const SizedBox(height: 32),
                      _buildFooterActions(),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

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
            if (_unreadCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$_unreadCount',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
        if (_notifications.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _headerActionButton(
                icon: Icons.mark_email_read_rounded,
                label: 'Tandai Semua Dibaca',
                onPressed: _unreadCount == 0 ? null : _markAllRead,
              ),
              _headerActionButton(
                icon: Icons.delete_sweep_rounded,
                label: 'Hapus Semua',
                onPressed: _deleteAllNotifications,
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        if (_visibleNotifications.isEmpty)
          Text(
            'Belum ada notifikasi',
            style: GoogleFonts.inter(fontSize: 14, color: onSurfaceVariant),
          )
        else
          ..._visibleNotifications.map(
            (notif) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _notificationItem(notif),
            ),
          ),
      ],
    );
  }

  Widget _headerActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        disabledForegroundColor: onSurfaceVariant.withValues(alpha: 0.45),
        side: BorderSide(
          color: primary.withValues(alpha: onPressed == null ? 0.25 : 0.45),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _notificationItem(Map<String, dynamic> notif) {
    final isUnread = notif['read'] != true;
    final visual = _visual(notif['type'].toString());

    return Opacity(
      opacity: isUnread ? 1.0 : 0.72,
      child: Material(
        color: isUnread ? Colors.white : surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _openNotification(notif),
          borderRadius: BorderRadius.circular(16),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: visual.border,
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
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: visual.iconBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            visual.icon,
                            color: visual.iconColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                notif['title'].toString(),
                                style: GoogleFonts.manrope(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                notif['desc'].toString(),
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
                                _timeLabel(notif['timestamp']),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: onSurfaceVariant.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
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
                                  color: error.withValues(alpha: 0.5),
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
      ),
    );
  }

  Widget _buildFooterActions() {
    return ElevatedButton.icon(
      onPressed: () => setState(() => _showAll = true),
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
      icon: const Icon(Icons.expand_more_rounded, size: 20),
      label: Text(
        'Lihat Lebih Banyak',
        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
      ),
    );
  }
}
