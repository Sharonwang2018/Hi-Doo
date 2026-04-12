import 'dart:async';
import 'dart:math' as math;

import 'package:echo_reading/models/book.dart';
import 'package:echo_reading/screens/manual_book_entry_screen.dart';
import 'package:echo_reading/services/book_api_service.dart';
import 'package:echo_reading/services/isbn_barcode_from_image_stub.dart'
    if (dart.library.html) 'package:echo_reading/services/isbn_barcode_from_image_web.dart';
import 'package:echo_reading/widgets/responsive_layout.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// ISBN scanner. [immersive] = edge-to-edge viewfinder for the home scan tool.
class HomeIsbnScanner extends StatefulWidget {
  const HomeIsbnScanner({
    super.key,
    required this.onBookFound,
    this.enabled = true,
    this.immersive = false,
    /// Opens scan options (e.g. camera / upload sheet). When set, shown in a bottom [Row] with gallery.
    this.onOpenScanOptions,
  });

  final void Function(BookLookupResult lookup) onBookFound;
  final bool enabled;

  /// Full-bleed camera with centered pulse frame (home).
  final bool immersive;

  /// Primary “Scan” action; paired with photo pick in [immersive] home layout.
  final VoidCallback? onOpenScanOptions;

  @override
  HomeIsbnScannerState createState() => HomeIsbnScannerState();
}

class HomeIsbnScannerState extends State<HomeIsbnScanner>
    with TickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController(
    facing: CameraFacing.back,
    detectionSpeed: DetectionSpeed.normal,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
    ],
  );
  final BookApiService _bookApiService = BookApiService();

  bool _isProcessing = false;
  bool _flowActive = false;
  bool _decodingImage = false;

  static const String _noBarcodeMessage =
      "Couldn't find a clear barcode. Try taking a closer photo of the ISBN bar!";

  AnimationController? _laserController;
  Animation<double>? _laserY;
  AnimationController? _pulseController;
  Animation<double>? _pulseOpacity;

  static const Duration _fetchTimeout = Duration(seconds: 30);

  static const Color _scanOrange = Color(0xFFFF8C42);
  static const double _actionButtonSize = 48;

  @override
  void initState() {
    super.initState();
    if (widget.immersive) {
      _pulseController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1300),
      )..repeat(reverse: true);
      _pulseOpacity = Tween<double>(begin: 0.2, end: 0.72).animate(
        CurvedAnimation(parent: _pulseController!, curve: Curves.easeInOut),
      );
    } else {
      _laserController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2600),
      )..repeat(reverse: true);
      _laserY = Tween<double>(begin: 0.06, end: 0.94).animate(
        CurvedAnimation(parent: _laserController!, curve: Curves.easeInOut),
      );
    }
  }

  @override
  void dispose() {
    _laserController?.dispose();
    _pulseController?.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> resumeScanning() async {
    await HapticFeedback.lightImpact();
    await _safeStart();
    if (mounted) setState(() {});
  }

  Future<void> _safeStop() async {
    try {
      await _controller.stop().timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  Future<void> _safeStart() async {
    final v = _controller.value;
    // MobileScanner already auto-starts; bottom-sheet "Scan with camera" must not call start() again
    // (Web throws controllerAlreadyInitialized if ZXing reader already exists).
    if (v.isRunning || v.isStarting) {
      return;
    }
    try {
      await _controller.start().timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  String? _firstRawFromCapture(BarcodeCapture? capture) {
    if (capture == null) return null;
    for (final b in capture.barcodes) {
      final v = b.rawValue?.trim();
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  void _showNoBarcodeSnack() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(_noBarcodeMessage)),
    );
  }

  Future<void> pickBarcodePhoto() async {
    if (!widget.enabled || _isProcessing || _flowActive) return;

    if (kIsWeb) {
      final file = await pickWebBarcodeImageFile();
      if (!mounted || file == null) return;

      setState(() => _decodingImage = true);
      String? raw;
      try {
        raw = await decodeWebBarcodeFromFile(file);
      } finally {
        if (mounted) setState(() => _decodingImage = false);
      }
      if (!mounted) return;
      raw = raw?.trim();
      if (raw == null || raw.isEmpty) {
        _showNoBarcodeSnack();
        return;
      }
      await _processIsbnLookupFromRaw(raw);
      return;
    }

    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: false,
    );
    if (!mounted || result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not read that image. Try another photo.'),
          ),
        );
      }
      return;
    }

    setState(() => _decodingImage = true);
    BarcodeCapture? capture;
    try {
      capture = await _controller.analyzeImage(path);
    } catch (_) {
      capture = null;
    } finally {
      if (mounted) setState(() => _decodingImage = false);
    }
    if (!mounted) return;

    final raw = _firstRawFromCapture(capture)?.trim();
    if (raw == null || raw.isEmpty) {
      _showNoBarcodeSnack();
      return;
    }
    await _processIsbnLookupFromRaw(raw);
  }

  Future<void> openManualEntry() async {
    await _safeStop();
    if (!mounted) return;
    final book = await Navigator.push<BookLookupResult?>(
      context,
      MaterialPageRoute(
        builder: (_) => const ManualBookEntryScreen(),
      ),
    );
    if (!mounted) return;
    await _safeStart();
    if (book != null) widget.onBookFound(book);
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (!widget.enabled || _isProcessing || _flowActive) return;
    final raw = _firstRawFromCapture(capture);
    if (raw == null || raw.isEmpty) return;
    await _processIsbnLookupFromRaw(raw);
  }

  Future<void> _processIsbnLookupFromRaw(String raw) async {
    if (!widget.enabled || _isProcessing || _flowActive) return;

    final isbn = _bookApiService.normalizeIsbn(raw);
    if (isbn == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not a valid ISBN (10 or 13 digits).')),
        );
      }
      return;
    }

    _flowActive = true;
    setState(() => _isProcessing = true);

    try {
      await _safeStop();
      final book = await _bookApiService.fetchByIsbn(isbn).timeout(
        _fetchTimeout,
        onTimeout: () => throw TimeoutException('Lookup timed out.', _fetchTimeout),
      );
      if (!mounted) return;
      if (book == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Book not found. Try manual entry.'),
            action: SnackBarAction(
              label: 'Manual',
              onPressed: openManualEntry,
            ),
          ),
        );
        await _safeStart();
        return;
      }
      widget.onBookFound(book);
      await _safeStart();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Something went wrong: $e')),
        );
      }
      await _safeStart();
    } finally {
      _flowActive = false;
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  bool get _actionsBusy =>
      !widget.enabled || _isProcessing || _flowActive || _decodingImage;

  /// Photo library / file picker (same path as [pickBarcodePhoto] on mobile & web).
  Widget _galleryPickButton(BuildContext context) {
    return SizedBox(
      width: _actionButtonSize,
      height: _actionButtonSize,
      child: Material(
        color: Colors.black54,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          padding: EdgeInsets.zero,
          iconSize: 24,
          icon: const Icon(Icons.photo_library_rounded),
          color: Colors.white,
          tooltip: 'Choose from photos',
          onPressed: _actionsBusy ? null : () => pickBarcodePhoto(),
        ),
      ),
    );
  }

  /// Bottom [Scan] + gallery [Row] (or fallback hint + gallery) — no overlapping [Positioned] controls.
  Widget _bottomControls(BuildContext context, {required bool immersive}) {
    final hasScanSheet = widget.onOpenScanOptions != null;

    if (hasScanSheet) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: SafeArea(
          minimum: const EdgeInsets.symmetric(horizontal: 12),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: immersive ? 6 : 10,
              top: 4,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!immersive) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Aim at the ISBN barcode',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize:
                            ResponsiveLayout.isTablet(context) ? 15 : 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: _actionButtonSize,
                      height: _actionButtonSize,
                    ),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: 268,
                            minHeight: _actionButtonSize,
                          ),
                          child: FilledButton.icon(
                            onPressed: _actionsBusy
                                ? null
                                : widget.onOpenScanOptions,
                            icon: const Icon(
                              Icons.qr_code_scanner_rounded,
                              size: 22,
                            ),
                            label: Text(
                              'Scan',
                              style: GoogleFonts.montserrat(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: _scanOrange,
                              foregroundColor: Colors.white,
                              shape: const StadiumBorder(),
                              elevation: 4,
                              shadowColor: Colors.black26,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                              ),
                              minimumSize:
                                  const Size(0, _actionButtonSize),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ),
                      ),
                    ),
                    _galleryPickButton(context),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!immersive) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: SafeArea(
          minimum: const EdgeInsets.symmetric(horizontal: 8),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Aim at the ISBN barcode',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize:
                          ResponsiveLayout.isTablet(context) ? 15 : 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: _galleryPickButton(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.bottomRight,
      child: SafeArea(
        minimum: const EdgeInsets.all(12),
        child: _galleryPickButton(context),
      ),
    );
  }

  Widget _laserOverlay() {
    final laserY = _laserY!;
    return AnimatedBuilder(
      animation: laserY,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final h = constraints.maxHeight;
            final top = laserY.value * h - 2;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: top.clamp(0.0, h - 4),
                  left: 0,
                  right: 0,
                  height: 4,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            const Color(0xFF5EEAD4).withValues(alpha: 0),
                            const Color(0xFF5EEAD4).withValues(alpha: 0.95),
                            const Color(0xFF5EEAD4).withValues(alpha: 0),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF5EEAD4).withValues(alpha: 0.45),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _immersiveOverlay() {
    final pulse = _pulseOpacity!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final boxW = math.min(w * 0.78, 300.0);
        final boxH = math.max(100.0, boxW * 0.38);
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ALIGN ISBN BARCODE HERE',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.8,
                  height: 1.2,
                  color: Colors.white.withValues(alpha: 0.95),
                  shadows: const [
                    Shadow(color: Colors.black87, blurRadius: 10),
                    Shadow(color: Colors.black54, blurRadius: 4),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              AnimatedBuilder(
                animation: pulse,
                builder: (context, child) {
                  final o = pulse.value;
                  return Container(
                    width: boxW,
                    height: boxH,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: o),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: o * 0.35),
                          blurRadius: 12,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.immersive) {
      return SizedBox.expand(
        child: ClipRect(
          child: _scannerStack(immersive: true),
        ),
      );
    }

    final radius = BorderRadius.circular(16);
    return ClipRRect(
      borderRadius: radius,
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: _scannerStack(immersive: false),
      ),
    );
  }

  Widget _scannerStack({required bool immersive}) {
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.hardEdge,
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: _onDetect,
          errorBuilder: (context, error) {
            final isWebHttp = kIsWeb && Uri.base.scheme == 'http';
            final needHttps = isWebHttp &&
                (error.errorCode == MobileScannerErrorCode.permissionDenied ||
                    error.errorCode == MobileScannerErrorCode.unsupported);
            return ColoredBox(
              color: Colors.black87,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    needHttps
                        ? 'HTTPS is required to use the camera in the browser.'
                        : (error.errorDetails?.message ?? error.errorCode.message),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            );
          },
        ),
        if (immersive) _immersiveOverlay(),
        if (!immersive) _laserOverlay(),
        _bottomControls(context, immersive: immersive),
        if (_isProcessing || _decodingImage)
          Container(
            color: Colors.black45,
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                if (_decodingImage) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Looking for the barcode...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: ResponsiveLayout.isTablet(context) ? 15 : 14,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
