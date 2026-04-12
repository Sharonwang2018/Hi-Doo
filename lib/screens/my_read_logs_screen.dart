import 'package:echo_reading/models/read_log.dart';
import 'package:echo_reading/models/read_log_with_book.dart';
import 'package:echo_reading/screens/reading_journal_detail_screen.dart';
import 'package:echo_reading/services/api_service.dart';
import 'package:echo_reading/widgets/responsive_layout.dart';
import 'package:flutter/material.dart';

class MyReadLogsScreen extends StatefulWidget {
  const MyReadLogsScreen({super.key});

  @override
  State<MyReadLogsScreen> createState() => _MyReadLogsScreenState();
}

class _MyReadLogsScreenState extends State<MyReadLogsScreen> {
  bool _isLoading = true;
  String? _error;
  List<ReadLogWithBook> _logs = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final logs = await ApiService.fetchReadLogs();
      if (!mounted) return;
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _sessionLabel(ReadLog log) {
    if (log.isLogOnly) return 'Quick log';
    if (log.isQuizChallenge) return 'Detail Detective';
    if (log.isStorytellerChallenge) return 'Master Storyteller';
    if (log.isCombinedChallenge) return 'Detective + Storyteller';
    if (log.isComprehensionQuestions) return 'Earlier entry';
    if (log.isSharedReading || log.sessionType == 'photo_read_page') {
      return 'Earlier entry';
    }
    return 'Master Storyteller';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Reading Journey'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveLayout.constrainToMaxWidth(
          context,
          Padding(
            padding: ResponsiveLayout.padding(context),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      )
                    : _logs.isEmpty
                        ? const Center(child: Text('No entries yet'))
                        : ListView.separated(
                            itemCount: _logs.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final item = _logs[index];
                              final transcript =
                                  (item.readLog.transcript ?? '').trim();
                              final ai = (item.readLog.aiFeedback ?? '').trim();
                              final preview = transcript.isNotEmpty ? transcript : ai;

                              return InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => ReadingJournalDetailScreen(
                                        book: item.book,
                                        readLog: item.readLog,
                                      ),
                                    ),
                                  );
                                },
                                child: Card(
                                  margin: EdgeInsets.zero,
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          width: 64,
                                          height: 86,
                                          child: item.book.coverUrl == null ||
                                                  item.book.coverUrl!.isEmpty
                                              ? Container(
                                                  decoration: BoxDecoration(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .surfaceContainerHighest,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10),
                                                  ),
                                                  alignment: Alignment.center,
                                                  child: const Icon(
                                                    Icons.menu_book_rounded,
                                                    size: 22,
                                                  ),
                                                )
                                              : ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  child: Image.network(
                                                    item.book.coverUrl!,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, __, ___) {
                                                      return Container(
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Theme.of(
                                                                  context)
                                                              .colorScheme
                                                              .surfaceContainerHighest,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                            10,
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.book.title,
                                                maxLines: 2,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium,
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                '${_formatDate(item.readLog.createdAt)} · ${_sessionLabel(item.readLog)}',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall,
                                              ),
                                              const SizedBox(height: 10),
                                              Text(
                                                preview.isEmpty
                                                    ? 'No transcript yet'
                                                    : preview,
                                                maxLines: 3,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ),
      ),
    );
  }
}

