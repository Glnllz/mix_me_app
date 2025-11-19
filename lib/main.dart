import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart'; // <<< 1. ДОБАВЬТЕ ЭТОТ ИМПОРТ
import 'package:mix_me_app/screens/main_screen.dart';
import 'package:mix_me_app/screens/welcome_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';


const kPrimaryPink = Color(0xFFE91E63);
const kBackground = Color(0xFF212121);
const kLightPink = Color(0xFFFCE4EC);
const kGlassyColor = Color.fromRGBO(255, 255, 255, 0.1);


class MyCustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
      };
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru_RU', null);
  await Supabase.initialize(
    url: 'https://qbkhlferjxojfxotyzsq.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFia2hsZmVyanhvamZ4b3R5enNxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc1ODQ3MzgsImV4cCI6MjA3MzE2MDczOH0.Kg-mIuu-d4BpVvKyUA4fuGbnoGQZXC0yqvoJWi9TRl0',
  );
  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MixMe',
      scrollBehavior: MyCustomScrollBehavior(),
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: kBackground,
        primaryColor: kPrimaryPink,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimaryPink,
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            padding: const EdgeInsets.symmetric(vertical: 18),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          hintStyle: TextStyle(color: Colors.grey[600], fontSize: 16),
        ),
      ),
      home: supabase.auth.currentSession == null
          ? const WelcomeScreen()
          : const MainScreen(),
    );
  }
}