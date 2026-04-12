import 'dart:convert';

import 'package:echo_reading/env_config.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// [register] 在开启「Confirm email」时多为 [EmailRegisterResult.confirmEmailPending]（无 session）。
enum EmailRegisterResult {
  /// 已拿到 session，可直接进首页
  signedIn,

  /// 账号已创建，需邮箱内确认链接后再登录（Supabase Dashboard 可关闭 Confirm email 方便开发）
  confirmEmailPending,
}

/// 单按钮「Continue」：先登录，失败再尝试注册时的结果。
enum EmailContinueResult {
  signedIn,
  confirmEmailPending,
}

/// Supabase Auth：注册/登录；云存储需邮箱或 Google（不使用匿名会话）。
class ApiAuthService {
  ApiAuthService._();

  static SupabaseClient get _client => Supabase.instance.client;

  /// Supabase access token（Bearer），无会话时 null。
  /// 若 access token 已过期（或距过期不足约 10s），先 [refreshSession]，避免首包带过期 JWT 导致 API 401 后被误 signOut。
  static Future<String?> getToken() async {
    if (!EnvConfig.hasSupabase) return null;
    var session = _client.auth.currentSession;
    if (session == null) return null;
    if (session.isExpired) {
      try {
        await _client.auth.refreshSession();
        session = _client.auth.currentSession;
      } catch (_) {}
    }
    return session?.accessToken;
  }

  static Future<void> signOut() async {
    if (!EnvConfig.hasSupabase) return;
    await _client.auth.signOut();
  }

  /// POST /read-logs 在 user_id 外键不满足时返回此错误；JWT 仍有效，不应 signOut。
  static bool isUserSessionStale401(http.Response res) {
    if (res.statusCode != 401) return false;
    try {
      final j = jsonDecode(res.body);
      if (j is Map && j['error'] == 'user_session_stale') return true;
    } catch (_) {}
    return false;
  }

  /// 401 后先刷新 access token；仅当刷新失败时再清除会话（避免误杀仍有效的登录）。
  static Future<void> recoverSessionAfterUnauthorized() async {
    if (!EnvConfig.hasSupabase) return;
    try {
      final refreshed = await _client.auth.refreshSession();
      if (refreshed.session != null) return;
    } catch (_) {}
    await _client.auth.signOut();
  }

  static Future<ApiUserInfo?> getUserInfo() async {
    if (!EnvConfig.hasSupabase) return null;
    final u = _client.auth.currentUser;
    if (u == null) return null;
    final anon = u.isAnonymous;
    return ApiUserInfo(
      uuid: u.id,
      loginType: anon ? 'ANONYMOUS' : 'CUSTOM',
      nickName: u.userMetadata?['name'] as String? ?? u.email,
      avatarUrl: null,
    );
  }

  /// 已登录且非匿名（邮箱 / Google 等）
  static Future<bool> get isRealUser async {
    final info = await getUserInfo();
    if (info == null) return false;
    return info.loginType != 'ANONYMOUS' && info.uuid.isNotEmpty;
  }

  /// 任意有效会话（含历史匿名 token；产品上不主动创建匿名）
  static bool get hasSession =>
      EnvConfig.hasSupabase && _client.auth.currentSession != null;

  static Future<EmailRegisterResult> register({
    required String email,
    required String password,
  }) async {
    if (!EnvConfig.hasSupabase) {
      throw AppAuthException('Supabase is not configured (SUPABASE_URL / SUPABASE_ANON_KEY).');
    }
    final res = await _client.auth.signUp(email: email, password: password);
    if (res.session != null) {
      return EmailRegisterResult.signedIn;
    }
    if (res.user != null) {
      return EmailRegisterResult.confirmEmailPending;
    }
    throw AppAuthException(
      'Could not create account. If you already use this email, try Sign in.',
    );
  }

  /// 浏览器内 OAuth（Web 为主）：完成后回到站点，由 Supabase 从 URL 恢复 session。
  /// Web 必须传 [redirectTo] 为当前站点 origin，否则会使用 Supabase Dashboard 的 Site URL（常为 localhost）。
  /// 原生 App 需另配 deep link 与 Dashboard Redirect URLs，参见 Supabase Flutter 文档。
  static Future<bool> signInWithGoogle() async {
    if (!EnvConfig.hasSupabase) {
      throw AppAuthException('Supabase is not configured (SUPABASE_URL / SUPABASE_ANON_KEY).');
    }
    final redirectTo = kIsWeb ? Uri.base.origin : null;
    return _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectTo,
    );
  }

  static Future<String> login({
    required String email,
    required String password,
  }) async {
    if (!EnvConfig.hasSupabase) {
      throw AppAuthException('Supabase is not configured (SUPABASE_URL / SUPABASE_ANON_KEY).');
    }
    final res = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (res.session == null) {
      throw AppAuthException('Sign in failed');
    }
    return res.session!.accessToken;
  }

  /// 先 [signInWithPassword]；失败时（常见为无此账号或错密）再 [signUp]。
  /// 若注册报「已存在」则视为账号存在、密码错误 → [AppAuthException] `Wrong email or password.`
  static Future<EmailContinueResult> continueWithEmail({
    required String email,
    required String password,
  }) async {
    if (!EnvConfig.hasSupabase) {
      throw AppAuthException('Supabase is not configured (SUPABASE_URL / SUPABASE_ANON_KEY).');
    }

    AuthResponse? signInRes;
    try {
      signInRes = await _client.auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      final m = e.message.toLowerCase();
      if (m.contains('email not confirmed') || m.contains('not confirmed')) {
        throw AppAuthException(
          'Check your inbox and confirm your email, then tap Continue again.',
        );
      }
      return _registerAfterSignInFailed(email: email, password: password);
    }

    if (signInRes.session != null) {
      return EmailContinueResult.signedIn;
    }

    return _registerAfterSignInFailed(email: email, password: password);
  }

  static Future<EmailContinueResult> _registerAfterSignInFailed({
    required String email,
    required String password,
  }) async {
    try {
      final reg = await _client.auth.signUp(email: email, password: password);
      if (reg.session != null) return EmailContinueResult.signedIn;
      if (reg.user != null) return EmailContinueResult.confirmEmailPending;
      throw AppAuthException(
        'Could not create an account. If you already use this email, check your password.',
      );
    } on AuthException catch (e) {
      final m = e.message.toLowerCase();
      if (m.contains('already registered') ||
          m.contains('already been registered') ||
          m.contains('user already registered')) {
        throw AppAuthException('Wrong email or password.');
      }
      throw AppAuthException(e.message);
    }
  }
}

class ApiUserInfo {
  ApiUserInfo({
    required this.uuid,
    required this.loginType,
    this.nickName,
    this.avatarUrl,
  });
  final String uuid;
  final String loginType;
  final String? nickName;
  final String? avatarUrl;
}

class AppAuthException implements Exception {
  AppAuthException(this.message);
  final String message;
  @override
  String toString() => message;
}
