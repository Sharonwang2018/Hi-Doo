import 'dart:convert';

import 'package:echo_reading/env_config.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _tokenKey = 'echo_reading_jwt';

class ApiAuthService {
  ApiAuthService._();

  static String? _cachedToken;

  static Future<String?> getToken() => _token;

  static Future<String?> get _token async {
    if (_cachedToken != null) return _cachedToken;
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString(_tokenKey);
    return _cachedToken;
  }

  static Future<void> _saveToken(String token) async {
    _cachedToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<void> signOut() async {
    _cachedToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  /// 本地 JWT 仍能解析，但服务端已不认（换 JWT_SECRET、过期等）时调用：清缓存并重新领访客 token。
  static Future<void> recoverSessionAfterUnauthorized() async {
    await signOut();
    await signInAsGuest();
  }

  /// 解析 JWT payload 获取 userId、username
  static Map<String, dynamic>? _decodePayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      return jsonDecode(decoded) as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  static Future<ApiUserInfo?> getUserInfo() async {
    final token = await _token;
    if (token == null || token.isEmpty) return null;
    final payload = _decodePayload(token);
    if (payload == null) return null;
    final userId = payload['userId'] as String? ?? payload['sub'] as String?;
    final username = payload['username'] as String? ?? '';
    if (userId == null || userId.isEmpty) return null;
    return ApiUserInfo(uuid: userId, loginType: username.startsWith('guest_') ? 'ANONYMOUS' : 'CUSTOM', nickName: null, avatarUrl: null);
  }

  static Future<bool> get isRealUser async {
    final info = await getUserInfo();
    if (info == null) return false;
    return info.loginType != 'ANONYMOUS' && info.uuid.isNotEmpty;
  }

  static Future<String> register({required String username, required String password}) async {
    final uri = Uri.parse('${EnvConfig.apiBaseUrl}/auth/register');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>?;
    if (res.statusCode != 200) {
      throw AuthException(body?['message'] as String? ?? '注册失败');
    }
    final ticket = body?['ticket'] as String?;
    if (ticket == null || ticket.isEmpty) throw AuthException('未获取到登录凭证');
    await _saveToken(ticket);
    return ticket;
  }

  static Future<String> login({required String username, required String password}) async {
    final uri = Uri.parse('${EnvConfig.apiBaseUrl}/auth/login');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>?;
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw AuthException(body?['message'] as String? ?? '登录失败');
    }
    final ticket = body?['ticket'] as String?;
    if (ticket == null || ticket.isEmpty) throw AuthException('未获取到登录凭证');
    await _saveToken(ticket);
    return ticket;
  }

  /// 继续浏览（创建访客用户）
  static Future<String> signInAsGuest() async {
    final uri = Uri.parse('${EnvConfig.apiBaseUrl}/auth/guest');
    final res = await http.post(uri, headers: {'Content-Type': 'application/json'});
    final body = jsonDecode(res.body) as Map<String, dynamic>?;
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw AuthException(body?['message'] as String? ?? '创建访客失败');
    }
    final ticket = body?['ticket'] as String?;
    if (ticket == null || ticket.isEmpty) throw AuthException('未获取到凭证');
    await _saveToken(ticket);
    return ticket;
  }
}

class ApiUserInfo {
  ApiUserInfo({required this.uuid, required this.loginType, this.nickName, this.avatarUrl});
  final String uuid;
  final String loginType;
  final String? nickName;
  final String? avatarUrl;
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}
