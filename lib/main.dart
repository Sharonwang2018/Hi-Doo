import 'dart:async';

import 'package:echo_reading/env_config.dart';
import 'package:echo_reading/screens/splash_screen.dart';
import 'package:echo_reading/services/reading_streak_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (EnvConfig.hasSupabase) {
    await Supabase.initialize(
      url: EnvConfig.supabaseUrl,
      anonKey: EnvConfig.supabaseAnonKey,
    );
    final u = Supabase.instance.client.auth.currentUser;
    if (u != null && u.isAnonymous) {
      await Supabase.instance.client.auth.signOut();
    }
  }
  unawaited(ReadingStreakService.refreshNotifier());
  runApp(const HiDooApp());
}

class HiDooApp extends StatelessWidget {
  const HiDooApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFFFF8C42);
    const secondary = Color(0xFF6FB1FC);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: secondary,
      surface: const Color(0xFFFFF7F0),
    );

    return MaterialApp(
      title: 'Hi-Doo | Think & Retell — Interactive Literacy Assistant',
      debugShowCheckedModeBanner: false,
      locale: const Locale('en', 'US'),
      supportedLocales: const [Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFFF7F0),
        textTheme: GoogleFonts.montserratTextTheme(),
        appBarTheme: const AppBarTheme(centerTitle: true),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const SplashScreen(),
    );
  }
}
