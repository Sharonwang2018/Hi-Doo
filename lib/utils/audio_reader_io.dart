import 'dart:io';
import 'dart:typed_data';

/// 移动端/桌面：从本地路径读取音频字节
Future<Uint8List> readAudioBytes(String path) async {
  final file = File(path);
  if (!await file.exists()) {
    throw Exception('Recording file not found');
  }
  return file.readAsBytes();
}
