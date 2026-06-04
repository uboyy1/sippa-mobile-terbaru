import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 1. Tambahkan import untuk Firebase
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'screens/main_screen.dart';

// 2. Ubah void main menjadi async agar bisa menunggu inisialisasi Firebase
void main() async {
  // 3. Wajib memanggil ini untuk inisialisasi binding framework
  WidgetsFlutterBinding.ensureInitialized();

  // 4. Inisialisasi Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const SippaApp());
}

class SippaApp extends StatelessWidget {
  const SippaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SIPPA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFFD62818),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/home': (context) => const MainScreen(),
      },
    );
  }
}
