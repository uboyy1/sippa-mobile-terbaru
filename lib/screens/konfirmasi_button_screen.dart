import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../widgets/responsive_content.dart';

class KonfirmasiButtonScreen extends StatefulWidget {
  const KonfirmasiButtonScreen({super.key});

  @override
  State<KonfirmasiButtonScreen> createState() => _KonfirmasiButtonScreenState();
}

class _KonfirmasiButtonScreenState extends State<KonfirmasiButtonScreen> {
  int _selectedWeight = 200;
  final List<int> _presets = [100, 200, 300, 500];
  late final DatabaseReference _statusRef;
  late final DatabaseReference _settingsRef;
  double _feedWeight = 0;
  double _feedLimit = 500;

  @override
  void initState() {
    super.initState();
    _statusRef = FirebaseDatabase.instance.ref('status');
    _settingsRef = FirebaseDatabase.instance.ref('settings');
    _listenStatus();
    _listenSettings();
  }

  void _listenStatus() {
    _statusRef.onValue.listen((event) {
      if (!mounted) return;
      final data = event.snapshot.value as Map?;
      if (data == null) return;
      setState(() {
        _feedWeight = _toStockUnit(data['feed_weight'], _feedLimit);
      });
    });
  }

  void _listenSettings() {
    _settingsRef.onValue.listen((event) {
      if (!mounted) return;
      final data = event.snapshot.value as Map?;
      if (data == null) return;
      setState(() {
        _feedLimit = _toPositiveLimit(data['feed_limit'], _feedLimit);
        _feedWeight = _feedWeight.clamp(0, _feedLimit).toDouble();
      });
    });
  }

  double _toStockUnit(Object? raw, double limit) {
    final value = raw is num
        ? raw.toDouble()
        : double.tryParse(raw?.toString() ?? '') ?? 0;
    if (limit <= 0) return value;
    return value.clamp(0, limit).toDouble();
  }

  double _toPositiveLimit(Object? raw, double fallback) {
    final value = raw is num
        ? raw.toDouble()
        : double.tryParse(raw?.toString() ?? '') ?? 0;
    return value > 0 ? value : fallback;
  }

  int get _feedPercent {
    if (_feedLimit <= 0) return 0;
    return (_feedWeight / _feedLimit * 100).clamp(0, 100).round();
  }

  void _updateWeight(int change) {
    setState(() {
      _selectedWeight += change;
      if (_selectedWeight < 0) _selectedWeight = 0;
    });
  }

  void _showConfirmationBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.only(
            top: 16,
            bottom: 40,
            left: 32,
            right: 32,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFFFCF9F8), // surface
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 60,
                offset: Offset(0, -20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 64,
                height: 6,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E2E1).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 24),
              // Warning Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFDAD6).withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_rounded,
                  color: Color(0xFFD62818),
                  size: 32,
                ),
              ),
              const SizedBox(height: 24),
              // Title
              const Text(
                'Konfirmasi Aksi',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1B1C1C),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              // Description
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    color: Color(0xFF5B403D),
                    height: 1.5,
                  ),
                  children: [
                    const TextSpan(
                      text: 'Apakah Anda yakin ingin memberi pakan sebanyak ',
                    ),
                    TextSpan(
                      text: '${_selectedWeight}g',
                      style: const TextStyle(
                        color: Color(0xFFD62818),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const TextSpan(text: ' sekarang?'),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Buttons
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD62818),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 64),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 8,
                  shadowColor: const Color(0xFFD62818).withOpacity(0.5),
                ),
                child: const Text(
                  'Ya, Beri Sekarang',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF5B403D),
                  minimumSize: const Size(double.infinity, 64),
                  side: BorderSide(
                    color: const Color(0xFF8F6F6C).withOpacity(0.3),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'Batal',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCF9F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFD62818),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Manual Control',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Colors.white,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ResponsiveContent(
          child: Column(
            children: [
              // Device Status Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F3F2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        // Status Dot
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981), // Emerald 500
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'ESP32 Terhubung',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1B1C1C),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E2E1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '3ms latency',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF5B403D),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Feed Now Section
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD62818).withOpacity(0.04),
                      blurRadius: 40,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF6F3F2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.pets,
                            color: Color(0xFFD62818),
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Beri Pakan Sekarang',
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1B1C1C),
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Text(
                                  'Stok Pakan ',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    color: Color(0xFF5B403D),
                                  ),
                                ),
                                Text(
                                  '$_feedPercent%',
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFD62818),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Progress Bar
                    Container(
                      height: 8,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F3F2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: (_feedPercent / 100).clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFD62818), Color(0xFFE13A2A)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Value Selector
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F3F2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          InkWell(
                            onTap: () => _updateWeight(-10),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE5E2E1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.remove,
                                color: Color(0xFF1B1C1C),
                              ),
                            ),
                          ),
                          RichText(
                            text: TextSpan(
                              text: '$_selectedWeight',
                              style: const TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 40,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFD62818),
                                letterSpacing: -1,
                              ),
                              children: const [
                                TextSpan(
                                  text: 'g',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF5B403D),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: () => _updateWeight(10),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE5E2E1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Color(0xFF1B1C1C),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Presets
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _presets.map((weight) {
                          bool isSelected = _selectedWeight == weight;
                          return Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: InkWell(
                              onTap: () =>
                                  setState(() => _selectedWeight = weight),
                              borderRadius: BorderRadius.circular(30),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFD62818)
                                      : const Color(0xFFF6F3F2),
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: const Color(
                                              0xFFD62818,
                                            ).withOpacity(0.25),
                                            blurRadius: 20,
                                            offset: const Offset(0, 8),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Text(
                                  '${weight}g',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFF5B403D),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // CTA Button
                    InkWell(
                      onTap: _showConfirmationBottomSheet,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFD62818), Color(0xFFB91C12)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFD62818).withOpacity(0.3),
                              blurRadius: 32,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.restaurant,
                              color: Colors.white,
                              size: 24,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Beri Pakan',
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0,
                              ),
                            ),
                          ],
                        ),
                      ),
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
}
