import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:echo_reading/env_config.dart';
import 'package:echo_reading/services/api_auth_service.dart';
import 'package:echo_reading/services/api_service.dart';
import 'package:echo_reading/utils/recording_path.dart';
import 'package:echo_reading/utils/upload_audio.dart';
import 'package:echo_reading/screens/retelling_complete_screen.dart';
import 'package:echo_reading/services/ai_feedback_service.dart';
import 'package:echo_reading/services/page_tts_audio_impl_stub.dart'
    if (dart.library.html) 'package:echo_reading/services/page_tts_audio_impl_web.dart' as tts_audio;
import 'package:echo_reading/services/page_tts_service.dart';
import 'package:echo_reading/services/retelling_intro_prompts.dart';
import 'package:echo_reading/services/transcription_service.dart';
import 'package:echo_reading/widgets/responsive_layout.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

final _transcriptionService = TranscriptionService();
const _audioBucket = 'read-audios';

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({
    super.key,
    required this.bookId,
    required this.summary,
    this.bookTitle,
    this.language,
    this.childAgeBand,
  });

  final String bookId;
  final String summary;
  final String? bookTitle;
  final String? language;
  /// 年龄档：preschool / primary / 不传即 general，用于引导语多维题库
  final String? childAgeBand;

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  final AudioRecorder _recorder = AudioRecorder();
  final PageTtsService _ttsService = PageTtsService();
  final stt.SpeechToText _speech = stt.SpeechToText();

  StreamSubscription<Amplitude>? _amplitudeSubscription;
  Timer? _recordingTimer;
  String _speechTranscript = '';

  List<double> _waveBars = List<double>.filled(20, 0.1);

  String? _audioPath;
  String? _transcript;
  String _language = 'zh';

  bool _recording = false;
  bool _processing = false;
  bool _usedOpusEncoder = false;
  bool _introPlayed = false;
  bool _isPlayingIntro = false;
  bool _aiReviewing = false;

  int _seconds = 0;
  /// 页面初始化时随机抽中的一条引导语（索引），整次会话固定
  late int _pickedPromptIndex;

  @override
  void initState() {
    super.initState();
    _language = widget.language ?? 'zh';
    _pickedPromptIndex = Random().nextInt(RetellingIntroPrompts.professionalPrompts.length);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // iOS Safari：进页自动播 TTS 无用户手势，豆包 MP3 无法播放；仅原生自动播引导语
      if (mounted && !kIsWeb) _playIntroIfNeeded();
    });
  }

  @override
  void dispose() {
    _amplitudeSubscription?.cancel();
    _recordingTimer?.cancel();
    try {
      _speech.stop();
    } catch (_) {}
    _recorder.dispose();
    _ttsService.dispose();
    super.dispose();
  }

  String _introPhraseFor(String lang) {
    final p = RetellingIntroPrompts.professionalPrompts[_pickedPromptIndex];
    return lang == 'en' ? p.en : p.zh;
  }

  Future<void> _playIntroContent() async {
    await _ttsService.speakWithDoubao(
      _introPhraseFor(_language),
      languageHint: _language,
    );
  }

  Future<void> _playIntroIfNeeded() async {
    if (_introPlayed) return;
    _introPlayed = true;
    try {
      await _playIntroContent();
    } catch (_) {}
  }

  /// Web：须同步进入 [speakDoubaoFromUserGesture]（见 [PageTtsService]），勿用 async 包一层。
  void _playIntroPhrase() {
    if (_isPlayingIntro) return;
    if (kIsWeb) {
      tts_audio.unlockAudioContextSync();
    }
    setState(() => _isPlayingIntro = true);
    _ttsService.speakDoubaoFromUserGesture(
      _introPhraseFor(_language),
      languageHint: _language,
      onComplete: () {
        if (mounted) setState(() => _isPlayingIntro = false);
      },
      onError: (e) {
        if (mounted) {
          setState(() => _isPlayingIntro = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('播放失败：$e')),
          );
        }
      },
    );
  }

  String _speechLocaleFor(String lang) {
    return lang == 'en' ? 'en_US' : 'zh_CN';
  }

  Future<void> _startRecording() async {
    if (_recording || _processing) return;

    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请先授予麦克风权限')));
        return;
      }

      final filePath = getRecordingPath();
      // Web 用 Opus，移动端用 AAC
      final config = kIsWeb
          ? const RecordConfig(
              encoder: AudioEncoder.opus,
              bitRate: 128000,
              sampleRate: 48000,
            )
          : const RecordConfig(
              encoder: AudioEncoder.aacLc,
              bitRate: 128000,
              sampleRate: 44100,
            );

      final encoderSupported =
          await _recorder.isEncoderSupported(config.encoder);
      final effectiveConfig = encoderSupported
          ? config
          : const RecordConfig(
              encoder: AudioEncoder.aacLc,
              bitRate: 128000,
              sampleRate: 44100,
            );

      await _recorder.start(effectiveConfig, path: filePath);
      _usedOpusEncoder = effectiveConfig.encoder == AudioEncoder.opus;

      _speechTranscript = '';
      if (kIsWeb) {
        try {
          final ok = await _speech.initialize();
          if (ok) {
            _speech.listen(
              onResult: (r) {
                if (mounted && _recording) {
                  setState(() => _speechTranscript = r.recognizedWords);
                }
              },
              localeId: _speechLocaleFor(_language),
              listenOptions: stt.SpeechListenOptions(partialResults: true),
            );
          }
        } catch (_) {}
      }

      _amplitudeSubscription?.cancel();
    _amplitudeSubscription = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 120))
        .listen((amp) {
          final normalized = ((amp.current + 45) / 45).clamp(0.05, 1.0);
          setState(() {
            _waveBars = [..._waveBars.skip(1), normalized];
          });
        });

    _recordingTimer?.cancel();
    _seconds = 0;
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _seconds += 1;
      });
    });

    setState(() {
      _audioPath = null;
      _transcript = null;
      _recording = true;
    });
    } catch (e, st) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('录音启动失败：$e')),
      );
      debugPrint('_startRecording error: $e\n$st');
    }
  }

  Future<void> _stopRecordingAndProcess() async {
    if (!_recording || _processing) return;

    setState(() {
      _processing = true;
    });

    _recordingTimer?.cancel();
    _amplitudeSubscription?.cancel();
    if (kIsWeb) {
      try {
        await _speech.stop();
      } catch (_) {}
    }

    final path = await _recorder.stop();
    setState(() {
      _recording = false;
      _audioPath = path;
    });

    if (path == null) {
      if (!mounted) return;
      setState(() {
        _processing = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('录音失败，请重试')));
      return;
    }

    String? comment;
    try {
      final isRealUser = EnvConfig.isConfigured && await _hasCloudBaseUser();
      String transcript = _speechTranscript.trim();
      String? logId;

      if (transcript.isEmpty) {
        try {
          if (isRealUser) {
            final audioUrl = await _uploadToCloudBase(path);
            transcript = await _transcriptionService.transcribe(
              audioUrl: audioUrl,
              audioPath: path,
            );
            logId = await _saveReadLog(audioUrl: audioUrl, transcript: transcript);
          } else {
            transcript = await _transcribeWithoutLogin(path);
          }
        } catch (e) {
          transcript = '';
          if (isRealUser) {
            final audioUrl = await _uploadToCloudBase(path);
            logId = await _saveReadLog(audioUrl: audioUrl, transcript: transcript);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('识别未完成，录音已保存。')),
              );
            }
          }
        }
      } else if (isRealUser) {
        final audioUrl = await _uploadToCloudBase(path);
        logId = await _saveReadLog(audioUrl: audioUrl, transcript: transcript);
      }

      if (!mounted) return;
      setState(() {
        _transcript = transcript;
        _processing = false;
      });

      // 仅当【已登录】且【有复述文字】时：先显示「AI老师正在审阅」→ 再弹「老师批阅」对话框（文字+语音）
      if (isRealUser && logId != null && transcript.trim().isNotEmpty) {
        if (!mounted) return;
        setState(() => _aiReviewing = true);

        try {
          final feedback = await AiFeedbackService.generate(
            transcript: transcript,
            summary: widget.summary,
            questions: const [],
            languageHint: _language,
          );
          comment = feedback['comment'] as String?;
          unawaited(
            ApiService.updateReadLogAiFeedback(logId, jsonEncode(feedback)).catchError((Object e) {
              debugPrint('updateReadLogAiFeedback: $e');
            }),
          );
        } catch (e) {
          if (mounted) {
            final msg = e is Exception
                ? e.toString().replaceFirst('Exception: ', '')
                : '请检查网络与 api/.env 中 ARK_* 或 OPENROUTER_API_KEY';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('AI 点评失败：$msg'), duration: const Duration(seconds: 5)),
            );
          }
        }

        if (!mounted) return;
        setState(() => _aiReviewing = false);

        if (comment != null && comment.isNotEmpty) {
          await _showFeedbackDialog(comment);
        }
      } else if (transcript.trim().isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未识别到复述内容，可重录或登录后获得 AI 老师批阅')),
        );
      } else if (!isRealUser && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('登录后录音可获得 AI 老师批阅')),
        );
      }

      // 已有老师批阅弹窗并听过点评时，不再播两段结束语，减少等待；无批阅时保留原鼓励流程
      if (!mounted) return;
      if (comment == null || comment.isEmpty) {
        try {
          await _ttsService.speak('Hi-Doo！你讲得真棒！');
        } catch (_) {}
        if (!mounted) return;
        try {
          const closing = '今天的故事讲得真好，下次再来一起玩～';
          await _ttsService.speak(closing);
        } catch (_) {}
      }
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => RetellingCompleteScreen(
            comment: comment,
            bookTitle: widget.bookTitle,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('处理失败：$error')),
      );
      if (mounted) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => RetellingCompleteScreen(
              comment: comment,
              bookTitle: widget.bookTitle,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
        });
      }
    }
  }

  Future<String> _transcribeWithoutLogin(String pathOrBlobUrl) async {
    return _transcriptionService.transcribe(
      audioUrl: null,
      audioPath: pathOrBlobUrl,
    );
  }

  Future<void> _showFeedbackDialog(String comment) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _FeedbackDialog(
        comment: comment,
        languageHint: _language,
        ttsService: _ttsService,
      ),
    );
  }

  Future<bool> _hasCloudBaseUser() async {
    try {
      final userInfo = await ApiAuthService.getUserInfo();
      return userInfo != null && userInfo.uuid.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<String> _uploadToCloudBase(String pathOrBlobUrl) async {
    final userInfo = await ApiAuthService.getUserInfo();
    if (userInfo == null) throw Exception('请先登录。');
    final uid = userInfo.uuid;
    if (uid.isEmpty) {
      throw Exception('请先登录。');
    }

    final ext = _usedOpusEncoder ? 'webm' : 'm4a';
    final objectPath =
        '$uid/${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}.$ext';

    return uploadAudioToCloudBase(
      pathOrBlobUrl,
      _audioBucket,
      objectPath,
      contentType: _usedOpusEncoder ? 'audio/webm' : 'audio/mp4',
    );
  }

  Future<String> _saveReadLog({
    required String audioUrl,
    required String transcript,
  }) async {
    final userInfo = await ApiAuthService.getUserInfo();
    if (userInfo == null || userInfo.uuid.isEmpty) {
      throw Exception('请先登录。');
    }

    return ApiService.createReadLog(
      bookId: widget.bookId,
      audioUrl: audioUrl,
      transcript: transcript,
      sessionType: 'retelling',
      language: _language,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('自由复述')),
      body: Stack(
        children: [
          SafeArea(
            child: ResponsiveLayout.constrainToMaxWidth(
          context,
          SingleChildScrollView(
            padding: ResponsiveLayout.padding(context),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Hi-Doo想听你说...', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'zh', label: Text('中文')),
                  ButtonSegment(value: 'en', label: Text('English')),
                ],
                selected: {_language},
                onSelectionChanged: (s) {
                  setState(() {
                    _language = s.single;
                    _introPlayed = false;
                  });
                },
              ),
              const SizedBox(height: 12),
              _IntroCard(
                introText: _introPhraseFor(_language),
                isPlaying: _isPlayingIntro,
                onPlay: _playIntroPhrase,
              ),
              const SizedBox(height: 16),
              _WaveformCard(
                isRecording: _recording,
                bars: _waveBars,
                elapsedSeconds: _seconds,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _processing
                    ? null
                    : _recording
                    ? _stopRecordingAndProcess
                    : _startRecording,
                icon: _processing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(_recording ? Icons.stop_rounded : Icons.mic_rounded),
                label: Text(
                  _processing
                      ? '处理中...'
                      : _recording
                      ? '结束录音'
                      : '开始录音',
                ),
              ),
              const SizedBox(height: 12),
              if (_recording && kIsWeb) ...[
                Card(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '边说边识别',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(_speechTranscript.isEmpty ? '聆听中...' : _speechTranscript),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_audioPath != null)
                Text(
                  '录音文件：$_audioPath',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (_transcript != null) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '识别结果',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(_transcript!),
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
          if (_aiReviewing)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: Card(
                    margin: const EdgeInsets.all(24),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 40,
                            height: 40,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'AI老师正在审阅...',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FeedbackDialog extends StatefulWidget {
  const _FeedbackDialog({
    required this.comment,
    required this.languageHint,
    required this.ttsService,
  });

  final String comment;
  /// 与复述分段一致：`en` / `zh`，用于 TTS 语言与 Web 降级朗读
  final String languageHint;
  final PageTtsService ttsService;

  @override
  State<_FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<_FeedbackDialog> {
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    // Web：无用户手势时 audio.play() 常被拦截，自动朗读会长时间「播放中」；请用户点按钮再播
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoPlay());
    }
  }

  Future<void> _autoPlay() async {
    if (!mounted || _playing) return;
    setState(() => _playing = true);
    try {
      await widget.ttsService.speakWithDoubao(
        widget.comment,
        languageHint: widget.languageHint,
      );
    } catch (_) {}
    finally {
      if (mounted) setState(() => _playing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.school_rounded, color: Colors.amber),
          SizedBox(width: 8),
          Text('老师批阅'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.comment, style: Theme.of(context).textTheme.bodyLarge),
            if (kIsWeb) ...[
              const SizedBox(height: 10),
              Text(
                '在浏览器中请点击下方按钮收听语音。',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _playing
                  ? null
                  : () async {
                      setState(() => _playing = true);
                      try {
                        await widget.ttsService.speakWithDoubao(
                          widget.comment,
                          languageHint: widget.languageHint,
                        );
                      } catch (_) {}
                      finally {
                        if (mounted) setState(() => _playing = false);
                      }
                    },
              icon: _playing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.volume_up_rounded),
              label: Text(_playing ? '播放中...' : '听老师点评'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('知道了'),
        ),
      ],
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({
    required this.introText,
    required this.isPlaying,
    required this.onPlay,
  });

  final String introText;
  final bool isPlaying;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final orange = Colors.orange;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              introText,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 18,
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              onPressed: isPlaying ? null : onPlay,
              style: FilledButton.styleFrom(
                backgroundColor: orange.shade50,
                foregroundColor: orange.shade800,
              ),
              icon: isPlaying
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.volume_up_rounded, size: 20),
              label: Text(isPlaying ? '播放中...' : '播放引导语'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaveformCard extends StatelessWidget {
  const _WaveformCard({
    required this.isRecording,
    required this.bars,
    required this.elapsedSeconds,
  });

  final bool isRecording;
  final List<double> bars;
  final int elapsedSeconds;

  String get _timeLabel {
    final minute = (elapsedSeconds ~/ 60).toString().padLeft(2, '0');
    final second = (elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$minute:$second';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.graphic_eq_rounded,
                  color: isRecording
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(width: 8),
                Text(isRecording ? '正在录音 $_timeLabel' : '等待开始录音'),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 64,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final value in bars)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 100),
                          height: 10 + (value * 52),
                          decoration: BoxDecoration(
                            color: isRecording
                                ? Theme.of(context).colorScheme.secondary
                                : Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
