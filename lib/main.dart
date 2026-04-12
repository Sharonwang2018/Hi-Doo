import 'dart:async';

import 'package:echo_reading/app_scaffold.dart';
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

class HiDooApp extends StatefulWidget {
  const HiDooApp({super.key});

  @override
  State<HiDooApp> createState() => _HiDooAppState();
}

class _HiDooAppState extends State<HiDooApp> {
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    if (EnvConfig.hasSupabase) {
      _authSub = Supabase.instance.client.auth.onAuthStateChange.listen(
        (AuthState data) {
          if (data.event == AuthChangeEvent.signedIn &&
              data.session != null &&
              !LoginSnackCoordinator.shouldSuppressGlobalSignedInSnack) {
            hiDooScaffoldMessengerKey.currentState?.showSnackBar(
              const SnackBar(
                content: Text('Successfully signed in!'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          if (mounted) setState(() {});
        },
      );
    }
  }

  @override
  void dispose() {
    final sub = _authSub;
    _authSub = null;
    if (sub != null) unawaited(sub.cancel());
    super.dispose();
  }

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
      scaffoldMessengerKey: hiDooScaffoldMessengerKey,
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
