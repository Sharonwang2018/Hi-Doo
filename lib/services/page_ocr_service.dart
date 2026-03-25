import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:paddle_ocr/paddle_ocr.dart';

import 'package:echo_reading/env_config.dart';
import 'package:echo_reading/services/api_service.dart';

import 'azure_vision_service.dart';
import 'image_preprocess_service.dart';

/// 绘本拍照 OCR 服务
/// 流程：预处理 → PaddleOCR 本地识别 → 置信度 < 80% 时调用 Azure 或后端 OpenRouter 视觉
class PageOcrService {
  final AzureVisionService _azure = AzureVisionService();

  /// 从图片字节识别文字，保持段落结构
  Future<String> extractTextFromImage(List<int> imageBytes) async {
    final bytes = Uint8List.fromList(imageBytes);

    // 1. 预处理：透视矫正 + 二值化
    final preprocessed = await preprocessForOcr(bytes);

    // 2. 移动端优先使用 PaddleOCR 本地识别
    if (!kIsWeb) {
      try {
        final (text, avgConfidence) =
            await _runPaddleOcr(Uint8List.fromList(preprocessed));
        if (text.trim().isNotEmpty) {
          if (avgConfidence >= 0.8) {
            return text;
          }
          // 置信度不足，尝试 Azure 补偿
          if (_azure.isConfigured) {
            try {
              final azureText =
                  await _azure.extractTextFromImage(preprocessed);
              if (azureText.trim().isNotEmpty) {
                return azureText;
              }
            } catch (_) {
              // Azure 失败则用本地结果
            }
          }
          return text;
        }
      } catch (_) {
        // PaddleOCR 失败，尝试 Azure
      }
    }

    // 3. Web 或 PaddleOCR 不可用：Azure 或后端 OpenRouter 视觉
    // 视觉模型用原图（仅缩尺寸），二值化会破坏绘本气泡、对话框中的文字
    final forVision = await prepareForVisionApi(bytes);
    if (_azure.isConfigured) {
      return _azure.extractTextFromImage(forVision);
    }
    if (EnvConfig.isConfigured) {
      final base64 = base64Encode(forVision);
      return ApiService.visionFromImage(base64);
    }
    throw Exception(
      'OCR 不可用：移动端请确保 PaddleOCR 正常；'
      '或配置后端 ARK_* / OPENROUTER_API_KEY 或 AZURE_VISION（见 docs）',
    );
  }

  /// 运行 PaddleOCR，返回 (文本, 平均置信度)，保持段落结构
  Future<(String, double)> _runPaddleOcr(Uint8List imageBytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/ocr_input_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await file.writeAsBytes(imageBytes);

    try {
      final result = await PaddleOcr.ocrFromImage(file.path);
      final success = result['success'] as bool? ?? false;
      final ocrResult = result['ocrResult'];

      if (!success || ocrResult == null) {
        throw Exception(result['message'] ?? 'PaddleOCR 识别失败');
      }

      final results = (ocrResult is Map
              ? ocrResult['ocrResults']
              : ocrResult.ocrResults) as List? ??
          [];
      if (results.isEmpty) {
        return ('', 0.0);
      }

      // 按 Y 坐标排序，保持阅读顺序
      final sorted = List<dynamic>.from(results);
      sorted.sort((a, b) {
        final aY = _getCenterY(a);
        final bY = _getCenterY(b);
        return aY.compareTo(bY);
      });

      final sb = StringBuffer();
      var sumConf = 0.0;
      var count = 0;
      double? lastY;

      for (final r in sorted) {
        final name = (r is Map ? r['name'] : r.name) as String? ?? '';
        if (name.isEmpty) continue;

        final conf = ((r is Map ? r['confidence'] : r.confidence) as num?)
                ?.toDouble() ??
            0.0;
        sumConf += conf;
        count++;

        final y = _getCenterY(r);
        // 若与上一行 Y 差距较大，视为新段落，加空行
        if (lastY != null && (y - lastY) > 20) {
          sb.writeln();
        }
        lastY = y;
        sb.write(name);
        sb.writeln();
      }

      final avgConf = count > 0 ? sumConf / count : 0.0;
      return (sb.toString().trim(), avgConf);
    } finally {
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  double _getCenterY(dynamic r) {
    final bounds = (r is Map ? r['bounds'] : r.bounds) as List?;
    if (bounds == null || bounds.isEmpty) return 0.0;
    try {
      var sum = 0.0;
      for (final p in bounds) {
        final y = p is Map ? p['y'] : p.y;
        sum += (y as num?)?.toDouble() ?? 0.0;
      }
      return sum / bounds.length;
    } catch (_) {
      return 0.0;
    }
  }
}
