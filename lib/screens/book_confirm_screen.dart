import 'package:echo_reading/models/book.dart';
import 'package:echo_reading/services/books_service.dart';
import 'package:echo_reading/widgets/reading_challenge_picker.dart';
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
        SnackBar(content: Text('Saved: ${savedBook.title}')),
      );
      _showChallengeChoice(context, savedBook);
    } catch (error) {
      if (!mounted) return;
      final msg = error.toString();
      final isLoadFailed = msg.contains('Load failed') || msg.contains('ClientException');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isLoadFailed
                ? 'Cannot reach the API. Use the same host/port as this page, or run ./run_all.sh from the project root.'
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

  void _showChallengeChoice(BuildContext context, Book savedBook) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) => ReadingChallengePicker(
        parentContext: context,
        sheetContext: sheetCtx,
        lookup: savedBook.asLookupResult(),
        savedBook: savedBook,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final coverUrl = widget.book.coverUrl;

    return Scaffold(
      appBar: AppBar(title: const Text('Confirm book')),
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
              Text('Author: ${widget.book.author}'),
              const SizedBox(height: 8),
              Text('ISBN: ${widget.book.isbn}'),
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
                label: Text(_isSaving ? 'Saving…' : 'Save to my library'),
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
      child: Icon(
        Icons.menu_book_rounded,
        size: 64,
        color: Theme.of(context).colorScheme.outline,
      ),
    );
  }
}
