import 'package:echo_reading/models/book.dart';
import 'package:echo_reading/screens/retelling_complete_screen.dart';
import 'package:echo_reading/services/read_logs_service.dart';
import 'package:echo_reading/widgets/responsive_layout.dart';
import 'package:flutter/material.dart';

class SharedReadingScreen extends StatefulWidget {
  const SharedReadingScreen({
    super.key,
    required this.book,
    ReadLogsService? readLogsService,
  }) : _readLogsService = readLogsService;

  final Book book;
  final ReadLogsService? _readLogsService;

  @override
  State<SharedReadingScreen> createState() => _SharedReadingScreenState();
}

class _SharedReadingScreenState extends State<SharedReadingScreen> {
  late final ReadLogsService _readLogsService =
      widget._readLogsService ?? ReadLogsService();

  String _language = 'zh';
  bool _isSaving = false;

  Future<void> _saveLog() async {
    setState(() {
      _isSaving = true;
    });

    try {
      await _readLogsService.createSharedReadingLog(
        bookId: widget.book.id,
        language: _language,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('亲子共读已记录')),
      );
      // 与复述模式一致：进入定制结束页（保存网页 / 再读一本）
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => RetellingCompleteScreen(
            comment: null,
            bookTitle: widget.book.title,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：$error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final coverUrl = widget.book.coverUrl;

    return Scaffold(
      appBar: AppBar(title: const Text('亲子共读记录')),
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
                          width: ResponsiveLayout.isTablet(context) ? 96 : 72,
                          height: ResponsiveLayout.isTablet(context) ? 132 : 98,
                          child: coverUrl == null || coverUrl.isEmpty
                              ? Container(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.menu_book_rounded),
                                )
                              : Image.network(
                                  coverUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    alignment: Alignment.center,
                                    child: const Icon(Icons.broken_image_rounded),
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
                              style: Theme.of(context).textTheme.titleMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.book.author,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '本次共读使用的语言',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'zh', label: Text('中文')),
                  ButtonSegment(value: 'en', label: Text('English')),
                ],
                selected: {_language},
                onSelectionChanged: (Set<String> selected) {
                  setState(() {
                    _language = selected.single;
                  });
                },
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _isSaving ? null : _saveLog,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.favorite_border),
                label: Text(_isSaving ? '保存中...' : '确认记录共读'),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
