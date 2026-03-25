import 'package:http/http.dart' as http;

import 'package:echo_reading/env_config.dart';
import 'package:echo_reading/services/api_service.dart';
import 'package:echo_reading/utils/audio_reader.dart';
import 'transcription_service_platform.dart';

/// 录音转写：后端 OpenAI Whisper 或 Android 本地 Whisper，需配置 OPENAI_API_KEY
class TranscriptionService {
  /// 转写：audioUrl 用于已上传的音频，audioPath 为 blob URL 或本地路径
  Future<String> transcribe({String? audioUrl, required String audioPath}) async {
    final bytes = await _getAudioBytes(audioUrl: audioUrl, audioPath: audioPath);

    if (EnvConfig.isConfigured && bytes != null && bytes.isNotEmpty) {
      try {
        return await ApiService.transcribeAudio(bytes);
      } catch (_) {}
    }

    if (canUseLocal) {
      final result = await transcribeWithLocal(audioPath);
      if (result != null && result.trim().isNotEmpty) {
        return result;
      }
    }

    throw Exception(
      '识别失败。请配置后端 OPENAI_API_KEY（见 docs）。Web 端建议使用 Opus 录制。',
    );
  }

  Future<List<int>?> _getAudioBytes({
    String? audioUrl,
    required String audioPath,
  }) async {
    final url = audioUrl ??
        ((audioPath.startsWith('http://') ||
                audioPath.startsWith('https://') ||
                audioPath.startsWith('blob:'))
            ? audioPath
            : null);

    if (url != null) {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        return resp.bodyBytes;
      }
    }

    if (!audioPath.startsWith('http') && !audioPath.startsWith('blob:')) {
      return readAudioBytes(audioPath);
    }

    return null;
  }
}
