import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cross_file/cross_file.dart';
import 'package:echo_reading/env_config.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import 'photo_read_page_screen.dart';

/// 干净结束页：展示“已记录的书”，引导保存网页（Web）/拍照打卡/再读一本
class RetellingCompleteScreen extends StatelessWidget {
  const RetellingCompleteScreen({
    super.key,
    this.comment,
    this.bookTitle,
  });

  /// AI 点评正文；复述模式下才会有
  final String? comment;

  /// 本次读取/复述的书名
  final String? bookTitle;

  /// 返回到首页（避免回到书籍确认页）
  static void popToHome(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _shareComment(BuildContext context) async {
    // Web 侧：优先走文字分享（无需生成海报图片）
    if (!context.mounted) return;
    final c = comment?.trim();
    if (c == null || c.isEmpty) return;
    final title = (bookTitle != null && bookTitle!.isNotEmpty)
        ? '《$bookTitle》复述点评\n\n'
        : '';
    final text = '$title$c';
    try {
      await Share.share(text);
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('点评已复制到剪贴板')),
        );
      }
    }
  }

  String _computeShareUrl() {
    // 你的需求是“扫二维码打开网页”，当前版本没有深链到具体点评内容；
    // 先保证能打开站点首页（同源页面），后续再接入带参数的深链。
    if (kIsWeb) return Uri.base.origin;
    return Uri.parse(EnvConfig.apiBaseUrl).origin;
  }

  Future<void> _sharePoster(BuildContext context) async {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _PosterShareDialog(
        bookTitle: bookTitle ?? '这本书',
        comment: comment,
        shareUrl: _computeShareUrl(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasComment = comment != null && comment!.trim().isNotEmpty;
    final title = (bookTitle != null && bookTitle!.isNotEmpty) ? bookTitle!.trim() : '这本书';
    final recordHint = hasComment ? '复述点评已保存到阅读记录' : '阅读记录已保存';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 1),
              Icon(
                Icons.celebration_rounded,
                size: 72,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 18),
              Text(
                '完成啦！你的阅读记录已保存',
                style: GoogleFonts.quicksand(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
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
                      const SizedBox(height: 8),
                      Text(
                        recordHint,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      if (hasComment) ...[
                        const SizedBox(height: 12),
                        Text(
                          comment!.trim(),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              if (kIsWeb) _SavePageReminder(),
              if (kIsWeb) const SizedBox(height: 16),

              if (hasComment) ...[
                OutlinedButton.icon(
                  onPressed: () => _sharePoster(context),
                  icon: const Icon(Icons.image_rounded, size: 20),
                  label: const Text('分享海报（图片+二维码）'),
                ),
                const SizedBox(height: 12),
              ],

              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PhotoReadPageScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.camera_alt_rounded, size: 20),
                label: const Text('拍照打卡（AI 读书）'),
              ),

              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => RetellingCompleteScreen.popToHome(context),
                icon: const Icon(Icons.menu_book_rounded, size: 20),
                label: const Text('再读一本'),
              ),

              TextButton(
                onPressed: () => RetellingCompleteScreen.popToHome(context),
                child: const Text('返回首页'),
              ),

              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}

/// 弹出一个“分享海报”弹窗：渲染 -> 截图成 PNG bytes -> 用 share_plus 分享图片
class _PosterShareDialog extends StatefulWidget {
  const _PosterShareDialog({
    required this.bookTitle,
    required this.comment,
    required this.shareUrl,
  });

  final String bookTitle;
  final String? comment;
  final String shareUrl;

  @override
  State<_PosterShareDialog> createState() => _PosterShareDialogState();
}

class _PosterShareDialogState extends State<_PosterShareDialog> {
  final GlobalKey _boundaryKey = GlobalKey();
  Uint8List? _posterBytes;
  bool _isGenerating = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _generateAndShare());
  }

  Future<void> _generateAndShare() async {
    try {
      final boundary = _boundaryKey.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary) {
        throw Exception('海报生成失败：未找到渲染边界');
      }

      final image = await boundary.toImage(pixelRatio: 2.2);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('海报生成失败：byteData 为空');
      final bytes = byteData.buffer.asUint8List();

      if (!mounted) return;
      setState(() {
        _posterBytes = bytes;
        _isGenerating = false;
      });

      // Web 场景：直接“自动分享图片”容易触发 unsupported type；
      // 改成展示海报图片，让用户长按保存到手机后再分享。
      if (kIsWeb) return;

      final xfile = XFile.fromData(
        bytes,
        name: 'handoo_share_poster.png',
        mimeType: 'image/png',
      );

      await Share.shareXFiles(
        [xfile],
        text: 'Hi-Doo 绘读：扫二维码也能打开网页',
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
      // 分享失败兜底：至少把点评复制出来（避免完全不可用）
      final c = widget.comment?.trim();
      if (c != null && c.isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: c));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('海报分享失败，已复制文字兜底')),
        );
      }
    } finally {
      // Web 侧不要立刻关闭，避免用户来不及保存图片
      if (mounted && !kIsWeb) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasComment = widget.comment != null && widget.comment!.trim().isNotEmpty;
    final snippet = hasComment ? widget.comment!.trim() : '你的阅读记录已保存';

    return AlertDialog(
      title: const Text('正在生成分享海报...'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                if (_posterBytes != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      _posterBytes!,
                      width: 320,
                      height: 420,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  RepaintBoundary(
                    key: _boundaryKey,
                    child: Container(
                      width: 320,
                      height: 420,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary.withAlpha(40),
                            Theme.of(context).colorScheme.secondary.withAlpha(30),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.menu_book_rounded,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Hi-Doo 绘读',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            widget.bookTitle,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            snippet,
                            style: Theme.of(context).textTheme.bodyMedium,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Spacer(),
                          Center(
                            child: QrImageView(
                              data: widget.shareUrl,
                              version: QrVersions.auto,
                              size: 140,
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '扫码打开网页',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
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
            const SizedBox(height: 12),
            if (kIsWeb)
              const Text(
                'Web 下请长按图片保存到手机，然后在微信里选择“发送图片”。',
                style: TextStyle(fontSize: 12, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
      actions: [
        if (kIsWeb)
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: widget.shareUrl));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已复制打开地址')),
              );
            },
            child: const Text('复制打开地址'),
          ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

/// 网页端：提醒用户保存页面以便下次使用
class _SavePageReminder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer.withAlpha(180),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bookmark_add_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  '把网页保存下来，下次再用',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '手机：浏览器菜单 →「添加到主屏幕」\n电脑：按 Ctrl+D / Cmd+D 收藏',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
