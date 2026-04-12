import 'dart:convert';
import 'dart:io';

import 'package:echo_reading/env_config.dart';
import 'package:echo_reading/services/api_auth_service.dart';
import 'package:http/http.dart' as http;

Future<String> uploadAudioFile(Object fileOrPath, {String contentType = 'audio/webm'}) async {
  if (!EnvConfig.isConfigured) {
    throw Exception('API is not configured. Set API_BASE_URL.');
  }
  final token = await ApiAuthService.getToken();
  if (token == null || token.isEmpty) throw Exception('Please sign in first');

  final File file = fileOrPath is File ? fileOrPath : File(fileOrPath as String);
  if (!await file.exists()) throw Exception('Recording file not found');

  final uri = Uri.parse('${EnvConfig.apiBaseUrl}/upload/audio');

  Future<http.Response> sendWithToken(String t) async {
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $t';
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    final streamed = await request.send();
    return http.Response.fromStream(streamed);
  }

  var res = await sendWithToken(token);
  if (res.statusCode == 401) {
    if (ApiAuthService.isUserSessionStale401(res)) {
      throw Exception(
        'Upload failed: your account is not linked in the server database.',
      );
    }
    await ApiAuthService.recoverSessionAfterUnauthorized();
    final t2 = await ApiAuthService.getToken();
    if (t2 == null || t2.isEmpty) throw Exception('Please sign in first');
    res = await sendWithToken(t2);
  }
  if (res.statusCode != 200 && res.statusCode != 201) {
    throw Exception('Upload failed: ${res.body}');
  }
  final json = jsonDecode(res.body) as Map<String, dynamic>;
  final url = json['url'] as String?;
  if (url == null || url.isEmpty) throw Exception('No file URL returned');
  return url;
}
