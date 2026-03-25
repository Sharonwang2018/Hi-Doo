import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:echo_reading/models/book.dart';
import 'package:echo_reading/models/read_log.dart';
import 'package:echo_reading/env_config.dart';
import 'package:echo_reading/services/api_service.dart';
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

  bool _isGenerating = false;
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

  Future<void> _generateAiFeedback() async {
    if (_isGenerating) return;
    if ((widget.readLog.transcript ?? '').trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前没有可分析的复述内容。')));
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      final result = await _askDoubaoForFeedback(
        transcript: widget.readLog.transcript!,
        summary: widget.book.summary ?? '',
      );

      await ApiService.updateReadLogAiFeedback(
        widget.readLog.id,
        jsonEncode(result),
      );

      if (!mounted) return;
      setState(() {
        _encouragement = result['comment'] as String?;
        _logicScore = (result['logic_score'] as num?)?.toInt();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('AI 点评已生成并保存')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('生成失败：$error')));
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>> _askDoubaoForFeedback({
    required String transcript,
    required String summary,
  }) async {
    const prompt = '''
请分析孩子的复述内容，生成一份约 100 字的点评，必须包含以下三个维度：
1) 复述完整度：孩子是否抓住了故事要点
2) 词汇闪光点：孩子用了哪些精彩的表达
3) 情绪表达：孩子的情感投入与语气

语气要积极、温柔、具体，适合 3-8 岁儿童。

严格返回 JSON：
{
  "comment": "约100字的完整点评，自然融合上述三个维度",
  "logic_score": 1-5
}
''';

    final messages = [
      {'role': 'system', 'content': '你是儿童阅读鼓励教练。'},
      {
        'role': 'user',
        'content': '书籍概要：\n$summary\n\n孩子复述：\n$transcript\n\n$prompt',
      },
    ];
    if (!EnvConfig.isConfigured) {
      throw Exception('请配置后端 API_BASE_URL 与 ARK_* 或 OPENROUTER_API_KEY（见 docs）');
    }
    final content = await ApiService.chatCompletion(messages: messages, temperature: 0.7);

    String raw = content.trim();
    if (raw.startsWith('```')) {
      final end = raw.indexOf('```', 3);
      if (end != -1) raw = raw.substring(3, end).trim();
      if (raw.startsWith('json')) raw = raw.substring(4).trim();
    }
    final result = jsonDecode(raw) as Map<String, dynamic>;
    final comment = (result['comment'] as String?)?.trim();
    final score = (result['logic_score'] as num?)?.toInt();

    if (comment == null || comment.isEmpty) {
      throw Exception('点评内容为空');
    }
    if (score == null || score < 1 || score > 5) {
      throw Exception('评分无效');
    }

    return {'comment': comment, 'encouragement': comment, 'logic_score': score};
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
        encouragement: _encouragement ?? '今天也认真完成了故事复述，继续加油！',
        score: _logicScore ?? 3,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final transcript = widget.readLog.transcript ?? '暂无识别内容';
    final coverUrl = widget.book.coverUrl;

    return Scaffold(
      appBar: AppBar(title: const Text('阅读日记详情')),
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
                            Text('日期：${_dateLabel(widget.readLog.createdAt)}'),
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
                        '复述文字',
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
                        'AI 点评',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(_encouragement ?? '还没有点评，点击下方按钮生成。'),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Text('逻辑表达评分：'),
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
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _isGenerating ? null : _generateAiFeedback,
                        icon: _isGenerating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.auto_awesome_rounded),
                        label: Text(_isGenerating ? '生成中...' : '生成 AI 点评'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _onGeneratePoster,
                icon: const Icon(Icons.ios_share_rounded),
                label: const Text('生成分享海报'),
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
        throw Exception('海报未渲染完成，请稍后重试');
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 3);
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) {
        throw Exception('海报导出失败');
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
          text: '我在 Hi-Doo 绘读 完成了一次阅读复述打卡！',
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('分享失败：$error')));
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
                      'Hi-Doo 绘读 阅读小成就',
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
                                '打卡日期：${_dateLabel(widget.readLog.createdAt)}',
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
                        const Text('逻辑表达：'),
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
                    child: const Text('关闭'),
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
                    label: Text(_sharing ? '生成中...' : '分享'),
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
