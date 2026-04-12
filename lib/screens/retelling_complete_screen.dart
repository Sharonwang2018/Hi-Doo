import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cross_file/cross_file.dart';
import 'package:echo_reading/env_config.dart';
import 'package:echo_reading/utils/donation_url_launch.dart';
import 'package:echo_reading/utils/poster_download.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import 'package:echo_reading/services/api_auth_service.dart';
import 'package:echo_reading/services/reading_streak_service.dart';
import 'package:echo_reading/widgets/tip_donation_sheet.dart';

/// 干净结束页：展示“已记录的书”，引导保存网页（Web）/再读一本
class RetellingCompleteScreen extends StatefulWidget {
  const RetellingCompleteScreen({
    super.key,
    this.comment,
    this.bookTitle,
    this.bookCoverUrl,
    this.showDonationTip = false,
    this.quickLogOnly = false,
    this.starsEarned,
    this.showJourneyRecap = true,
  });

  /// AI 点评正文；复述模式下才会有
  final String? comment;

  /// 本次读取/复述的书名
  final String? bookTitle;

  /// 封面 URL（分享海报用）
  final String? bookCoverUrl;

  /// After enough retelling successes, show optional “Support Our Mission” sheet.
  final bool showDonationTip;

  /// “Just log it” path — celebratory copy, no AI challenge.
  final bool quickLogOnly;

  /// Stars earned this save (1 = first quick-log of local day, 3 = challenge); null = hide row.
  final int? starsEarned;

  /// Short NGO product loop: Scan → Choose → Play → Journey.
  final bool showJourneyRecap;

  /// 返回到首页（避免回到书籍确认页）
  static void popToHome(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  State<RetellingCompleteScreen> createState() => _RetellingCompleteScreenState();
}

class _RetellingCompleteScreenState extends State<RetellingCompleteScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.showDonationTip) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showMissionSupportSheet(context);
      });
    }
  }

  /// Share link: same app entry with query params so the URL is not “just” bare origin.
  /// Main.dart can later read `from` / `book` for a dedicated landing if desired.
  String _computeShareUrl({String? bookTitle}) {
    final origin =
        kIsWeb ? Uri.base.origin : Uri.parse(EnvConfig.apiBaseUrl).origin;
    var base = origin.trim();
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);
    final u = Uri.parse(base);
    final params = <String, String>{
      'from': 'reading_poster',
      'ref': 'hi-doo',
    };
    final t = bookTitle?.trim();
    if (t != null && t.isNotEmpty) {
      params['book'] = t.length > 120 ? '${t.substring(0, 117)}...' : t;
    }
    return u.replace(queryParameters: params).toString();
  }

  Future<void> _sharePoster(BuildContext context) async {
    if (!context.mounted) return;
    await ReadingStreakService.refreshNotifier();
    final streak = ReadingStreakService.streakCountNotifier.value;
    final info = await ApiAuthService.getUserInfo();
    final achiever = _posterAchieverLabel(info?.nickName);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _PosterShareDialog(
        bookTitle: widget.bookTitle ?? 'This book',
        bookCoverUrl: widget.bookCoverUrl,
        comment: widget.comment,
        shareUrl: _computeShareUrl(bookTitle: widget.bookTitle),
        starsEarned: widget.starsEarned,
        streakDays: streak,
        achieverLabel: achiever,
      ),
    );
  }

  static String _posterAchieverLabel(String? nickName) {
    final n = nickName?.trim();
    if (n == null || n.isEmpty) return 'You';
    if (n.contains('@')) {
      return n.split('@').first.trim();
    }
    final parts = n.split(RegExp(r'\s+'));
    return parts.isNotEmpty ? parts.first : 'You';
  }

  @override
  Widget build(BuildContext context) {
    final hasComment = widget.comment != null && widget.comment!.trim().isNotEmpty;
    final title = (widget.bookTitle != null && widget.bookTitle!.isNotEmpty)
        ? widget.bookTitle!.trim()
        : 'This book';
    final recordHint = widget.quickLogOnly
        ? 'Your reading point is saved — open My Reading Journey anytime.'
        : hasComment
            ? 'Listener reply saved to your journey'
            : 'Saved to your reading journey';

    final headline = widget.quickLogOnly
        ? 'Book added to your journey!'
        : 'Nice work! Added to your reading journey';

    final celebratoryIcon = widget.quickLogOnly
        ? TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 720),
            curve: Curves.elasticOut,
            builder: (context, scale, child) {
              return Transform.scale(
                scale: scale.clamp(0.0, 1.0),
                child: child,
              );
            },
            child: Icon(
              Icons.auto_stories_rounded,
              size: 76,
              color: Theme.of(context).colorScheme.primary,
            ),
          )
        : Icon(
            Icons.celebration_rounded,
            size: 72,
            color: Theme.of(context).colorScheme.primary,
          );

    final mq = MediaQuery.of(context);
    final bottomInset = mq.viewPadding.bottom;
    final scrollBottomPad = 20.0 + bottomInset;

    Widget sharePrimaryButton() => _SharePosterPrimaryButton(
          onPressed: () => _sharePoster(context),
        );

    final scrollContent = ListView(
      padding: EdgeInsets.fromLTRB(24, 12, 24, scrollBottomPad),
      physics: const BouncingScrollPhysics(),
      children: [
        Center(child: celebratoryIcon),
        const SizedBox(height: 12),
        Text(
          headline,
          style: GoogleFonts.quicksand(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        if (widget.starsEarned != null && widget.starsEarned! > 0) ...[
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 520),
            curve: Curves.easeOutCubic,
            builder: (context, t, child) {
              return Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, 8 * (1 - t)),
                  child: child,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < widget.starsEarned!.clamp(0, 5); i++)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 2),
                          child: Text('⭐', style: TextStyle(fontSize: 24)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.starsEarned == 1
                        ? 'First book of your day — +1 star for showing up! Next time, try Detail Detective or Storyteller for +3 stars.'
                        : '+3 stars for completing the Story Challenge — amazing habit!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.menu_book_rounded,
                      size: 22,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  recordHint,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (hasComment) ...[
                  const SizedBox(height: 10),
                  Text(
                    widget.comment!.trim(),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (widget.showJourneyRecap) ...[
          const SizedBox(height: 10),
          Text(
            'Your Hi-Doo loop',
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '1 Scan ISBN  →  2 Choose path  →  3 Play & learn  →  4 Reading Journey',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  height: 1.4,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
        // 四条路径结束后均可分享海报：Quiz / Storyteller / Both / Just log it（不依赖是否有听评正文）。
        const SizedBox(height: 14),
        sharePrimaryButton(),
        if (kIsWeb) ...[
          const SizedBox(height: 12),
          const _SavePageReminder(),
        ],
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: () => RetellingCompleteScreen.popToHome(context),
          icon: const Icon(Icons.menu_book_rounded, size: 20),
          label: const Text('Read another book'),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: () => RetellingCompleteScreen.popToHome(context),
          child: const Text('Home'),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: () async {
              if (EnvConfig.hasDonationUrl) {
                await launchExternalDonationUrl(
                  context,
                  Uri.parse(EnvConfig.donationUrl.trim()),
                );
              } else if (context.mounted) {
                await showMissionSupportSheet(context);
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withValues(alpha: 0.7),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              '❤️ Support our mission to help every child read.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.72),
                  ),
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      body: SafeArea(
        child: scrollContent,
      ),
    );
  }
}

/// Primary reward CTA: share poster with soft glow + bold border.
class _SharePosterPrimaryButton extends StatelessWidget {
  const _SharePosterPrimaryButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.28),
            blurRadius: 18,
            spreadRadius: 0,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.12),
            blurRadius: 28,
            spreadRadius: 2,
            offset: Offset.zero,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: FilledButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.image_rounded, size: 22),
          label: const Text('Share poster (image + QR)'),
          style: FilledButton.styleFrom(
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: cs.onPrimary.withValues(alpha: 0.35),
                width: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 分享「阅读成就海报」：渲染 → 截图 PNG → share_plus（非 Web）
class _PosterShareDialog extends StatefulWidget {
  const _PosterShareDialog({
    required this.bookTitle,
    required this.bookCoverUrl,
    required this.comment,
    required this.shareUrl,
    required this.starsEarned,
    required this.streakDays,
    required this.achieverLabel,
  });

  final String bookTitle;
  final String? bookCoverUrl;
  final String? comment;
  final String shareUrl;
  final int? starsEarned;
  final int streakDays;
  final String achieverLabel;

  @override
  State<_PosterShareDialog> createState() => _PosterShareDialogState();
}

class _PosterShareDialogState extends State<_PosterShareDialog> {
  final GlobalKey _boundaryKey = GlobalKey();
  Uint8List? _posterBytes;
  bool _isGenerating = true;
  bool _downloadBusy = false;

  static const double _posterW = 340;
  static const double _posterH = 620;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _generateAndShare());
  }

  Future<void> _downloadPosterToDevice() async {
    final bytes = _posterBytes;
    if (bytes == null || _downloadBusy) return;
    setState(() => _downloadBusy = true);
    try {
      await downloadPosterPng(
        bytes,
        filename: 'hidoo_reading_achievement.png',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Download started — check your downloads folder.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not download: $e')),
      );
    } finally {
      if (mounted) setState(() => _downloadBusy = false);
    }
  }

  Future<void> _generateAndShare() async {
    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary) {
        throw Exception('Could not build poster: missing render boundary');
      }

      final image = await boundary.toImage(pixelRatio: 2.4);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Poster export failed: empty image data');
      final bytes = byteData.buffer.asUint8List();

      if (!mounted) return;
      setState(() {
        _posterBytes = bytes;
        _isGenerating = false;
      });

      if (kIsWeb) return;

      final xfile = XFile.fromData(
        bytes,
        name: 'hidoo_reading_achievement.png',
        mimeType: 'image/png',
      );

      await Share.shareXFiles(
        [xfile],
        text: 'Hi-Doo | Think & Retell — scan the QR code to join',
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
      final c = widget.comment?.trim();
      if (c != null && c.isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: c));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Poster share failed — text copied instead')),
        );
      }
    } finally {
      if (mounted && !kIsWeb) Navigator.of(context).pop();
    }
  }

  int get _starDisplayCount {
    final e = widget.starsEarned;
    if (e == null || e <= 0) return 3;
    return e.clamp(1, 5);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 28, 16, 20),
      title: Text(
        _isGenerating ? 'Creating your poster…' : 'Reading Achievement Poster',
        style: GoogleFonts.montserrat(
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
        textAlign: TextAlign.center,
      ),
      content: SizedBox(
        width: _posterW + 8,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  if (_posterBytes != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.memory(
                        _posterBytes!,
                        width: _posterW,
                        height: _posterH,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    RepaintBoundary(
                      key: _boundaryKey,
                      child: _AchievementPosterFace(
                        width: _posterW,
                        height: _posterH,
                        bookTitle: widget.bookTitle,
                        coverUrl: widget.bookCoverUrl,
                        achieverLabel: widget.achieverLabel,
                        starCount: _starDisplayCount,
                        streakDays: widget.streakDays,
                        shareUrl: widget.shareUrl,
                      ),
                    ),
                  if (_isGenerating)
                    const SizedBox(
                      width: 56,
                      height: 56,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
              if (kIsWeb && _posterBytes != null) ...[
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _downloadBusy ? null : () => _downloadPosterToDevice(),
                  icon: _downloadBusy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_alt_rounded),
                  label: Text(_downloadBusy ? 'Preparing…' : 'Save poster image'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    textStyle: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _downloadBusy
                      ? null
                      : () {
                          openPosterImageInNewTab(_posterBytes!);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Image opened in a new tab — use your browser’s Save or Share there (best on iPhone Safari).',
                              ),
                              duration: Duration(seconds: 5),
                            ),
                          );
                        },
                  icon: const Icon(Icons.open_in_new_rounded, size: 20),
                  label: Text(
                    'Open in new tab',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Tap Save to download the PNG. On some phones (especially iPhone), use Open in new tab, then save the picture from there.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        if (kIsWeb)
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: widget.shareUrl));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Link copied!\nShare this app with your friends.',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                  duration: const Duration(seconds: 4),
                ),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurfaceVariant,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              minimumSize: const Size(48, 48),
              tapTargetSize: MaterialTapTargetSize.padded,
            ),
            child: const Text('Copy link'),
          ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: theme.colorScheme.onSurfaceVariant,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            minimumSize: const Size(48, 48),
            tapTargetSize: MaterialTapTargetSize.padded,
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

/// Polaroid-style canvas captured for sharing (no Theme dependency on primitive colors).
class _AchievementPosterFace extends StatelessWidget {
  const _AchievementPosterFace({
    required this.width,
    required this.height,
    required this.bookTitle,
    required this.coverUrl,
    required this.achieverLabel,
    required this.starCount,
    required this.streakDays,
    required this.shareUrl,
  });

  final double width;
  final double height;
  final String bookTitle;
  final String? coverUrl;
  final String achieverLabel;
  final int starCount;
  final int streakDays;
  final String shareUrl;

  @override
  Widget build(BuildContext context) {
    const cream = Color(0xFFFFFBF7);
    const frame = Color(0xFFF5F0EB);
    const ink = Color(0xFF3E2723);
    const inkSoft = Color(0xFF6D4C41);
    final shortTitle =
        bookTitle.length > 42 ? '${bookTitle.substring(0, 40)}…' : bookTitle;
    final line =
        '$achieverLabel just completed the Reading Challenge for ‘$shortTitle’! 🌱';

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: frame,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Container(
        decoration: BoxDecoration(
          color: cream,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white, width: 2),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Hi-Doo  ·  Think & Retell',
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: inkSoft.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: coverUrl != null && coverUrl!.isNotEmpty
                    ? Image.network(
                        coverUrl!,
                        width: 112,
                        height: 152,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _coverPlaceholder(),
                      )
                    : _coverPlaceholder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.celebration_rounded,
                  color: Colors.orange.shade700,
                  size: 30,
                ),
                const SizedBox(width: 8),
                Text(
                  List.filled(starCount, '⭐').join(),
                  style: const TextStyle(fontSize: 22, height: 1),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Align(
                alignment: Alignment.center,
                child: Text(
                  line,
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.montserrat(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                    color: ink,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.orange.shade100.withValues(alpha: 0.9),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Daily Streak',
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: inkSoft,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '🔥',
                              style: const TextStyle(fontSize: 22, height: 1),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$streakDays',
                              style: GoogleFonts.montserrat(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: ink,
                                height: 1,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              streakDays == 1 ? 'Day' : 'Days',
                              style: GoogleFonts.montserrat(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: inkSoft,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: QrImageView(
                          data: shareUrl,
                          version: QrVersions.auto,
                          size: 72,
                          backgroundColor: Colors.white,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: Color(0xFF1a1a1a),
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Color(0xFF1a1a1a),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Scan to join Hi-Doo',
                        style: GoogleFonts.montserrat(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          color: inkSoft,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }

  Widget _coverPlaceholder() {
    return Container(
      width: 112,
      height: 152,
      color: const Color(0xFFEEE8E4),
      child: const Icon(Icons.menu_book_rounded, size: 48, color: Color(0xFFBCAAA4)),
    );
  }
}

/// 网页端：提醒用户保存页面以便下次使用
class _SavePageReminder extends StatelessWidget {
  const _SavePageReminder();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cs.outline.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bookmark_add_outlined,
                  color: cs.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Bookmark this page for next time',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Phone: browser menu → Add to Home Screen\nDesktop: Ctrl+D / Cmd+D to bookmark',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.35,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
