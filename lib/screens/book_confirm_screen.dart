import 'package:echo_reading/env_config.dart';
import 'package:echo_reading/models/book.dart';
import 'package:echo_reading/screens/login_screen.dart';
import 'package:echo_reading/screens/recording_screen.dart';
import 'package:echo_reading/screens/shared_reading_screen.dart';
import 'package:echo_reading/services/api_auth_service.dart';
import 'package:echo_reading/services/books_service.dart';
import 'package:echo_reading/widgets/responsive_layout.dart';
import 'package:flutter/material.dart';

class BookConfirmScreen extends StatefulWidget {
  const BookConfirmScreen({
    super.key,
    required this.book,
    BooksService? booksService,
  }) : _booksService = booksService;

  final BookLookupResult book;
  final BooksService? _booksService;

  @override
  State<BookConfirmScreen> createState() => _BookConfirmScreenState();
}

class _BookConfirmScreenState extends State<BookConfirmScreen> {
  late final BooksService _booksService =
      widget._booksService ?? BooksService();
  bool _isSaving = false;

  Future<void> _saveBook() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final savedBook = await _booksService.upsertBook(widget.book);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('《${savedBook.title}》已保存')),
      );
      _showModeChoice(context, savedBook);
    } catch (error) {
      if (!mounted) return;
      final msg = error.toString();
      final isLoadFailed = msg.contains('Load failed') || msg.contains('ClientException');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isLoadFailed
                ? '无法连接服务器。iPhone Safari 对局域网自签名 HTTPS 常失败，请用 HTTP=1 ./run_all.sh 重建并访问 http://…，或 ngrok 等可信 HTTPS'
                : msg,
          ),
          duration: const Duration(seconds: 8),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showModeChoice(BuildContext context, Book savedBook) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '选择记录方式',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  bool isRealUser = false;
                  if (EnvConfig.isConfigured) {
                    try {
                      isRealUser = await ApiAuthService.isRealUser;
                    } catch (_) {}
                  }
                  if (!isRealUser && context.mounted) {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('请先登录'),
                        content: const Text(
                          '登录后可保存到阅读日记，并获得更好的语音识别体验。',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const Text('暂不登录'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('去登录'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true && context.mounted) {
                      await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    }
                    return;
                  }
                  if (!context.mounted) return;
                  final navigator = Navigator.of(context);
                  await Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => RecordingScreen(
                        bookId: savedBook.id,
                        summary: savedBook.summary ?? Book.defaultSummary,
                        bookTitle: savedBook.title,
                      ),
                    ),
                  );
                  if (!context.mounted) return;
                },
                icon: const Icon(Icons.mic_rounded),
                label: const Text('复述模式：自由复述，AI 点评'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final navigator = Navigator.of(context);
                  await Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => SharedReadingScreen(book: savedBook),
                    ),
                  );
                  if (!context.mounted) return;
                },
                icon: const Icon(Icons.favorite_border),
                label: const Text('共读模式：仅记录亲子共读'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context, true);
                },
                child: const Text('返回'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final coverUrl = widget.book.coverUrl;

    return Scaffold(
      appBar: AppBar(title: const Text('确认书籍信息')),
      body: SafeArea(
        child: ResponsiveLayout.constrainToMaxWidth(
          context,
          SingleChildScrollView(
            padding: ResponsiveLayout.padding(context),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (coverUrl != null && coverUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    coverUrl,
                    height: ResponsiveLayout.isTablet(context) ? 280 : 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const _CoverPlaceholder(),
                  ),
                )
              else
                const _CoverPlaceholder(),
              const SizedBox(height: 16),
              Text(
                widget.book.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text('作者：${widget.book.author}'),
              const SizedBox(height: 8),
              Text('ISBN：${widget.book.isbn}'),
              const SizedBox(height: 12),
              Text(
                widget.book.summary ?? Book.defaultSummary,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _isSaving ? null : _saveBook,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(_isSaving ? '保存中...' : '确认并存入 Books'),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: ResponsiveLayout.isTablet(context) ? 280 : 200,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.menu_book_rounded, size: 56),
    );
  }
}
