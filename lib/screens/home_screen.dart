import 'package:echo_reading/env_config.dart';
import 'package:echo_reading/models/book.dart';
import 'package:echo_reading/screens/my_read_logs_screen.dart';
import 'package:echo_reading/screens/login_screen.dart';
import 'package:echo_reading/services/api_auth_service.dart';
import 'package:echo_reading/services/reading_streak_service.dart';
import 'package:echo_reading/widgets/home_isbn_scanner.dart';
import 'package:echo_reading/widgets/scan_about_sheet.dart';
import 'package:echo_reading/widgets/reading_challenge_picker.dart';
import 'package:echo_reading/widgets/streak_home_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<HomeIsbnScannerState> _scanKey = GlobalKey<HomeIsbnScannerState>();
  BookLookupResult? _pendingLookup;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    ReadingStreakService.refreshNotifier();
    _checkAuth();
  }

  void _showChallengeSheet(BookLookupResult lookup) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => ReadingChallengePicker(
        parentContext: context,
        sheetContext: sheetCtx,
        lookup: lookup,
        savedBook: null,
      ),
    );
  }

  void _onBookFound(BookLookupResult lookup) {
    setState(() => _pendingLookup = lookup);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showChallengeSheet(lookup);
    });
  }

  Future<void> _checkAuth() async {
    if (!EnvConfig.isConfigured) return;
    try {
      final userInfo = await ApiAuthService.getUserInfo();
      if (mounted) {
        setState(() => _isLoggedIn = userInfo != null && userInfo.uuid.isNotEmpty);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoggedIn = false);
    }
  }

  Future<void> _openJourney() async {
    if (!EnvConfig.isConfigured) return;
    if (!_isLoggedIn) {
      final ok = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      if (ok == true && mounted) {
        await _checkAuth();
        if (_isLoggedIn && mounted) {
          await Navigator.push<void>(
            context,
            MaterialPageRoute<void>(builder: (_) => const MyReadLogsScreen()),
          );
        }
      }
      return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => const MyReadLogsScreen()),
    );
  }

  Future<void> _openScanOptions() async {
    await HapticFeedback.lightImpact();
    if (!mounted) return;
    final titleStyle = GoogleFonts.montserrat(fontWeight: FontWeight.w600);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text('Scan with camera', style: titleStyle),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _scanKey.currentState?.resumeScanning();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text('Upload barcode photo', style: titleStyle),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _scanKey.currentState?.pickBarcodePhoto();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onMenuSelected(String value) async {
    switch (value) {
      case 'manual':
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scanKey.currentState?.openManualEntry();
        });
        break;
      case 'journey':
        await _openJourney();
        break;
      case 'about':
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) showScanAboutSheet(context);
        });
        break;
      case 'signin':
        final ok = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        if (ok == true && mounted) _checkAuth();
        break;
      case 'logout':
        await ApiAuthService.signOut();
        if (mounted) _checkAuth();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Clearance above in-scanner bottom bar (Scan row + safe area).
    final bottomFab =
        12 + 48 + 16 + MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        centerTitle: true,
        toolbarHeight: 56,
        leadingWidth: 118,
        leading: const Padding(
          padding: EdgeInsets.only(left: 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: StreakHomeBadge(),
          ),
        ),
        title: Text(
          'Hi-Doo',
          style: GoogleFonts.montserrat(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1a1a1a),
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              tooltip: 'Menu',
              onSelected: _onMenuSelected,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'manual',
                  child: Row(
                    children: [
                      Icon(Icons.keyboard_alt_outlined, size: 22),
                      SizedBox(width: 10),
                      Text('Enter ISBN manually'),
                    ],
                  ),
                ),
                if (EnvConfig.isConfigured)
                  const PopupMenuItem(
                    value: 'journey',
                    child: Row(
                      children: [
                        Icon(Icons.auto_stories_rounded, size: 22),
                        SizedBox(width: 10),
                        Text('My Reading Journey'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'about',
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 22),
                      SizedBox(width: 10),
                      Text('About & privacy'),
                    ],
                  ),
                ),
                if (EnvConfig.isConfigured)
                  if (_isLoggedIn)
                    const PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout_rounded, size: 22),
                          SizedBox(width: 10),
                          Text('Sign out'),
                        ],
                      ),
                    )
                  else
                    const PopupMenuItem(
                      value: 'signin',
                      child: Row(
                        children: [
                          Icon(Icons.login_rounded, size: 22),
                          SizedBox(width: 10),
                          Text('Log in'),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: HomeIsbnScanner(
              key: _scanKey,
              immersive: true,
              onBookFound: _onBookFound,
              onOpenScanOptions: _openScanOptions,
            ),
          ),
          if (_pendingLookup != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: bottomFab,
              child: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(14),
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _showChallengeSheet(_pendingLookup!),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
                    child: Row(
                      children: [
                        if (_pendingLookup!.coverUrl != null &&
                            _pendingLookup!.coverUrl!.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              _pendingLookup!.coverUrl!,
                              width: 40,
                              height: 54,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.menu_book_rounded, size: 36),
                            ),
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: Icon(Icons.menu_book_rounded, size: 36),
                          ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _pendingLookup!.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                _pendingLookup!.author,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.montserrat(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => setState(() => _pendingLookup = null),
                          tooltip: 'Clear',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
