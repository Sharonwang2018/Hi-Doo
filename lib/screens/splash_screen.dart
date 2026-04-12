import 'package:echo_reading/env_config.dart';
import 'package:echo_reading/screens/home_screen.dart';
import 'package:echo_reading/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Landing: brand, tagline, strong CTA — user taps to continue (no auto-skip).
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _busy = false;

  static const Color _orange = Color(0xFFFF8C42);
  static const Color _blue = Color(0xFF6FB1FC);
  static const Color _warmGray = Color(0xFF8A8580);
  /// Warmer, darker slate-blue — strong contrast on peach/sky gradient vs. orange title.
  static const Color _taglinePrimary = Color(0xFF2E4050);

  Future<void> _continue() async {
    if (_busy || !mounted) return;
    setState(() => _busy = true);
    await HapticFeedback.lightImpact();
    if (!mounted) return;
    if (EnvConfig.hasSupabase) {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
        );
        return;
      }
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    );
  }

  static TextStyle _introBase(BuildContext context) => GoogleFonts.montserrat(
        fontSize: 13.5,
        fontWeight: FontWeight.w400,
        height: 1.6,
        letterSpacing: 0.12,
        color: Colors.black.withValues(alpha: 0.58),
      );

  static TextStyle _introBold(BuildContext context) => GoogleFonts.montserrat(
        fontSize: 13.5,
        fontWeight: FontWeight.w800,
        height: 1.6,
        letterSpacing: 0.12,
        color: Colors.black.withValues(alpha: 0.72),
      );

  Widget _introRichText(BuildContext context) {
    final base = _introBase(context);
    final bold = _introBold(context);
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          const TextSpan(
            text:
                "Free for families. Scan any child's book ISBN. Choose a challenge: ",
          ),
          TextSpan(text: 'Detail Detective', style: bold),
          const TextSpan(text: ', '),
          TextSpan(text: 'Master Storyteller', style: bold),
          const TextSpan(text: ', or do both! Or, simply '),
          TextSpan(text: 'log your book', style: bold),
          const TextSpan(text: ' to keep your reading streak '),
          const TextSpan(text: '🔥'),
          const TextSpan(text: ' alive.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final viewBottom = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFF7F0), Color(0xFFF0F8FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Giant wordmark watermark (behind line art)
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Transform.rotate(
                    angle: -0.06,
                    child: Text(
                      'Hi-Doo',
                      style: GoogleFonts.nunito(
                        fontSize: 112,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -2,
                        color: _orange.withValues(alpha: 0.045),
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Subtle open-book outline
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _SplashBookWatermark(color: _orange.withValues(alpha: 0.095)),
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final ctaWidth =
                      (constraints.maxWidth * 0.65).clamp(240.0, 280.0);
                  return SingleChildScrollView(
                    padding: EdgeInsets.only(
                      left: 28,
                      right: 28,
                      top: 20,
                      bottom: bottomInset + viewBottom + 28,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - bottomInset - viewBottom - 48,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Hi-Doo',
                            style: GoogleFonts.nunito(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.8,
                              height: 1.05,
                              color: _orange,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Interactive Literacy Assistant',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.nunito(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.35,
                              height: 1.3,
                              color: _taglinePrimary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              'Beyond reading: Unlock their understanding.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.nunito(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                height: 1.45,
                                letterSpacing: 0.2,
                                color: _warmGray,
                              ),
                            ),
                          ),
                          const SizedBox(height: 26),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.88),
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(
                                color: _blue.withValues(alpha: 0.16),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.07),
                                  blurRadius: 28,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 12),
                                ),
                                BoxShadow(
                                  color: _blue.withValues(alpha: 0.08),
                                  blurRadius: 18,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                              child: _introRichText(context),
                            ),
                          ),
                          const SizedBox(height: 40),
                          _GetStartedCta(
                            width: ctaWidth,
                            busy: _busy,
                            orange: _orange,
                            onPressed: _continue,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GetStartedCta extends StatefulWidget {
  const _GetStartedCta({
    required this.width,
    required this.busy,
    required this.orange,
    required this.onPressed,
  });

  final double width;
  final bool busy;
  final Color orange;
  final Future<void> Function() onPressed;

  @override
  State<_GetStartedCta> createState() => _GetStartedCtaState();
}

class _GetStartedCtaState extends State<_GetStartedCta> {
  bool _hover = false;
  bool _pressed = false;

  double get _scale {
    var s = 1.0;
    if (_hover) s *= 1.025;
    if (_pressed) s *= 0.97;
    return s;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Listener(
          onPointerDown: (_) => setState(() => _pressed = true),
          onPointerUp: (_) => setState(() => _pressed = false),
          onPointerCancel: (_) => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _scale,
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            child: SizedBox(
              width: widget.width,
              child: FilledButton(
                onPressed: widget.busy ? null : () => widget.onPressed(),
                style: FilledButton.styleFrom(
                  backgroundColor: widget.orange,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: widget.orange.withValues(alpha: 0.6),
                  disabledForegroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 15,
                  ),
                  minimumSize: Size(widget.width, 48),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 4,
                  shadowColor: widget.orange.withValues(alpha: 0.4),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Get Started',
                      style: GoogleFonts.nunito(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.25,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Simple open-book line art for watermark (no asset file).
class _SplashBookWatermark extends CustomPainter {
  _SplashBookWatermark({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.012
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cx = size.width * 0.5;
    final cy = size.height * 0.42;
    final w = size.width * 0.42;
    final h = size.height * 0.22;

    // Open book silhouette (two pages + spine)
    final path = Path()
      ..moveTo(cx, cy - h * 0.5)
      ..lineTo(cx - w * 0.08, cy - h * 0.35)
      ..quadraticBezierTo(cx - w * 0.5, cy - h * 0.2, cx - w * 0.52, cy)
      ..quadraticBezierTo(cx - w * 0.5, cy + h * 0.25, cx - w * 0.08, cy + h * 0.45)
      ..lineTo(cx, cy + h * 0.52)
      ..lineTo(cx + w * 0.08, cy + h * 0.45)
      ..quadraticBezierTo(cx + w * 0.5, cy + h * 0.25, cx + w * 0.52, cy)
      ..quadraticBezierTo(cx + w * 0.5, cy - h * 0.2, cx + w * 0.08, cy - h * 0.35)
      ..close();

    canvas.drawPath(path, paint);

    // Reading figure hint: simple arc (head) + line (shoulder)
    final head = Offset(cx, cy - h * 0.95);
    canvas.drawCircle(head, w * 0.08, paint);
    canvas.drawLine(
      Offset(head.dx + w * 0.06, head.dy + w * 0.05),
      Offset(cx + w * 0.15, cy - h * 0.15),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _SplashBookWatermark oldDelegate) =>
      oldDelegate.color != color;
}
