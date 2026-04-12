import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:echo_reading/models/book.dart';
import 'package:echo_reading/models/read_log.dart';
import 'package:echo_reading/widgets/responsive_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ReadingJournalDetailScreen extends StatefulWidget {
  const ReadingJournalDetailScreen({
    super.key,
    required this.book,
    required this.readLog,
  });

  final Book book;
  final ReadLog readLog;

  @override
  State<ReadingJournalDetailScreen> createState() =>
      _ReadingJournalDetailScreenState();
}

class _ReadingJournalDetailScreenState
    extends State<ReadingJournalDetailScreen> {
  String? _encouragement;
  int? _logicScore;

  @override
  void initState() {
    super.initState();
    _loadFeedbackFromReadLog();
  }

  void _loadFeedbackFromReadLog() {
    final raw = widget.readLog.aiFeedback;
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      setState(() {
        _encouragement = decoded['comment'] as String? ?? decoded['encouragement'] as String?;
        _logicScore = (decoded['logic_score'] as num?)?.toInt();
      });
    } catch (_) {
      setState(() {
        _encouragement = raw;
      });
    }
  }

  String _dateLabel(DateTime dateTime) {
    final y = dateTime.year.toString().padLeft(4, '0');
    final m = dateTime.month.toString().padLeft(2, '0');
    final d = dateTime.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _onGeneratePoster() async {
    await showDialog<void>(
      context: context,
      builder: (context) => _PosterShareDialog(
        book: widget.book,
        readLog: widget.readLog,
        encouragement: _encouragement ?? 'You shared a great retelling today—keep going!',
        score: _logicScore ?? 3,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final transcript = widget.readLog.transcript ?? 'No transcript yet';
    final coverUrl = widget.book.coverUrl;

    return Scaffold(
      appBar: AppBar(title: const Text('Journey entry')),
      body: SafeArea(
        child: ResponsiveLayout.constrainToMaxWidth(
          context,
          SingleChildScrollView(
            padding: ResponsiveLayout.padding(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 78,
                          height: 108,
                          child: coverUrl == null || coverUrl.isEmpty
                              ? Container(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.menu_book_rounded),
                                )
                              : Image.network(
                                  coverUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerHighest,
                                        alignment: Alignment.center,
                                        child: const Icon(
                                          Icons.broken_image_rounded,
                                        ),
                                      ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.book.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text('Date: ${_dateLabel(widget.readLog.createdAt)}'),
                            if (widget.readLog.libraryPartnerName != null &&
                                widget.readLog.libraryPartnerName!.trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Library partner: ${widget.readLog.libraryPartnerName!.trim()}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'What they shared',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(transcript),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Listener reply',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(_encouragement ?? 'No reply yet'),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Text('Expression score: '),
                          ...List.generate(5, (index) {
                            final active = (_logicScore ?? 0) > index;
                            return Icon(
                              active
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: active
                                  ? const Color(0xFFFFA95E)
                                  : Theme.of(context).colorScheme.outline,
                            );
                          }),
                          const SizedBox(width: 6),
                          Text(_logicScore?.toString() ?? '-'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _onGeneratePoster,
                icon: const Icon(Icons.ios_share_rounded),
                label: const Text('Create share image'),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _PosterShareDialog extends StatefulWidget {
  const _PosterShareDialog({
    required this.book,
    required this.readLog,
    required this.encouragement,
    required this.score,
  });

  final Book book;
  final ReadLog readLog;
  final String encouragement;
  final int score;

  @override
  State<_PosterShareDialog> createState() => _PosterShareDialogState();
}

class _PosterShareDialogState extends State<_PosterShareDialog> {
  final GlobalKey _posterKey = GlobalKey();
  bool _sharing = false;

  String _dateLabel(DateTime dateTime) {
    final y = dateTime.year.toString().padLeft(4, '0');
    final m = dateTime.month.toString().padLeft(2, '0');
    final d = dateTime.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _sharePoster() async {
    if (_sharing) return;
    setState(() {
      _sharing = true;
    });

    try {
      await Future<void>.delayed(const Duration(milliseconds: 60));
      final boundary =
          _posterKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Poster is not ready yet. Try again.');
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 3);
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) {
        throw Exception('Could not export poster');
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/echo_reading_poster_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(pngBytes, flush: true);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'I finished a Hi-Doo | Think & Retell check-in!',
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Share failed: $error')));
    } finally {
      if (mounted) {
        setState(() {
          _sharing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final coverUrl = widget.book.coverUrl;

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RepaintBoundary(
              key: _posterKey,
              child: Container(
                width: 320,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFF2E5), Color(0xFFEAF3FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Hi-Doo | Think & Retell milestone',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: SizedBox(
                            width: 72,
                            height: 98,
                            child: coverUrl == null || coverUrl.isEmpty
                                ? Container(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
                                    alignment: Alignment.center,
                                    child: const Icon(Icons.menu_book_rounded),
                                  )
                                : Image.network(coverUrl, fit: BoxFit.cover),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.book.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Logged: ${_dateLabel(widget.readLog.createdAt)}',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(220),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.encouragement,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Expression: '),
                        ...List.generate(5, (index) {
                          final active = widget.score > index;
                          return Icon(
                            active
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: active
                                ? const Color(0xFFFFA95E)
                                : Colors.grey.shade500,
                            size: 20,
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _sharing ? null : _sharePoster,
                    icon: _sharing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.ios_share_rounded),
                    label: Text(_sharing ? 'Working…' : 'Share'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
