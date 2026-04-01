import 'dart:async';
import 'dart:typed_data';

import 'package:echo_reading/services/page_ocr_service.dart';
import 'package:echo_reading/services/page_tts_service.dart';
import 'package:echo_reading/services/tip_donation_trigger.dart';
import 'package:echo_reading/widgets/tip_donation_sheet.dart';
import 'package:echo_reading/widgets/responsive_layout.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// 拍照读页：孩子翻到哪页拍哪页，AI 识别后朗读，不存储全书，无侵权风险
/// 后端 TTS 失败时自动降级为设备朗读，确保一定能读出
/// Web：浏览器禁止无用户手势自动播放音频，故识别后不自动朗读，需点击「收听本页」
class PhotoReadPageScreen extends StatefulWidget {
  const PhotoReadPageScreen({super.key});

  @override
  State<PhotoReadPageScreen> createState() => _PhotoReadPageScreenState();
}

class _PhotoReadPageScreenState extends State<PhotoReadPageScreen> {
  final PageOcrService _ocrService = PageOcrService();
  final PageTtsService _ttsService = PageTtsService();
  final ImagePicker _picker = ImagePicker();

  Uint8List? _photoBytes;
  String? _extractedText;
  bool _isProcessing = false;
  bool _isPlaying = false;
  String _statusText = '';
  String? _lastError;
  /// Web 上曾成功播过一次后，按钮文案改为「再次播放」
  bool _hasPlayedOnce = false;

  @override
  void dispose() {
    _ttsService.dispose();
    super.dispose();
  }

  void _setStatus(String text) {
    if (mounted) setState(() => _statusText = text);
  }

  /// 与 `_playAgain` 一致：无论成功失败，[finally] 结束「朗读中」避免 Web TTS 久不 complete 时一直转圈
  Future<void> _speakExtractedAfterCapture(String t) async {
    try {
      await _ttsService.speak(t);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('朗读失败：$e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _statusText = '';
          _hasPlayedOnce = true;
        });
      }
    }
  }

  Future<void> _takePhoto() async {
    if (_isProcessing) return;

    if (_isPlaying) {
      await _ttsService.stop();
      if (mounted) setState(() => _isPlaying = false);
    }

    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        // 缩小图片，减少 base64 体积，降低 OpenRouter 触发 request entity too large 的概率
        imageQuality: 75,
        maxWidth: 1280,
      );

      if (photo == null || !mounted) return;

      _setStatus('识别中...');
      final bytes = await photo.readAsBytes();
      if (!mounted) return;

      setState(() {
        _photoBytes = Uint8List.fromList(bytes);
        _extractedText = null;
        _lastError = null;
        _isProcessing = true;
        _hasPlayedOnce = false;
      });

      String text;
      try {
        text = await _ocrService.extractTextFromImage(bytes);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _lastError = '识别失败，请重拍或确保光线充足';
          _statusText = '';
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('识别失败，请重拍或检查网络'),
            action: SnackBarAction(
              label: '重试',
              onPressed: _takePhoto,
            ),
          ),
        );
        return;
      }

      final t = text.trim();
      if (t.isEmpty) {
        if (!mounted) return;
        setState(() {
          _lastError = '未识别到文字，请重拍或调整角度';
          _statusText = '';
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('未识别到文字，请重拍或确保页面清晰'),
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      if (!mounted) return;
      setState(() {
        _extractedText = t;
        _isProcessing = false;
        if (kIsWeb) {
          // 浏览器会拦截无用户手势的 audio.play()，自动朗读会失败或长时间走降级；改为点击后再播
          _statusText = '识别完成，请点击「收听本页」';
          _isPlaying = false;
        } else {
          _statusText = '朗读中...';
          _isPlaying = true;
        }
      });

      final showTip = await TipDonationTrigger.recordPhotoSuccess();
      if (!mounted) return;
      if (showTip) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          showTipDonationSheet(context);
        });
      }

      if (!kIsWeb) {
        unawaited(_speakExtractedAfterCapture(t));
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _lastError = '出错了，请重试';
        _statusText = '';
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('处理失败：$error'),
          action: SnackBarAction(label: '重试', onPressed: _takePhoto),
        ),
      );
    }
  }

  Future<void> _playAgain() async {
    if (_extractedText == null || _extractedText!.trim().isEmpty) return;
    if (_isPlaying) return;

    setState(() {
      _isPlaying = true;
      _statusText = '朗读中...';
    });

    try {
      await _ttsService.speak(_extractedText!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('播放失败：$e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _statusText = '';
          _hasPlayedOnce = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('拍照读页'),
      ),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.camera_alt_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '翻到哪页拍哪页，AI 读给你听',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '不存储全书，仅识别当前页并朗读。',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '完整读完一本书后，请返回首页用「扫码录入」选书并完成复述，以保存阅读记录。',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_photoBytes != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    _photoBytes!,
                    fit: BoxFit.contain,
                    height: ResponsiveLayout.isTablet(context) ? 320 : 240,
                  ),
                )
              else
                Container(
                  height: ResponsiveLayout.isTablet(context) ? 280 : 200,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withAlpha(180),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.menu_book_rounded,
                        size: 48,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '点击下方按钮拍摄当前页',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              if (_statusText.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isProcessing || _isPlaying) ...[
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        _statusText,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ],
              if (_lastError != null) ...[
                const SizedBox(height: 12),
                Text(
                  _lastError!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _isProcessing ? null : _takePhoto,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.camera_alt_rounded),
                label: Text(
                  _isProcessing
                      ? (kIsWeb ? '识别中...' : '识别并朗读中...')
                      : '拍摄当前页',
                ),
              ),
              if (_extractedText != null) ...[
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              '识别内容',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            if (!_isProcessing)
                              FilledButton.tonalIcon(
                                onPressed: _isPlaying ? null : _playAgain,
                                icon: Icon(
                                  _isPlaying
                                      ? Icons.volume_up_rounded
                                      : Icons.play_circle_outline_rounded,
                                ),
                                label: Text(
                                  _isPlaying
                                      ? '播放中'
                                      : (kIsWeb && !_hasPlayedOnce
                                          ? '收听本页'
                                          : '再次播放'),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(_extractedText!),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        ),
      ),
    );
  }
}
