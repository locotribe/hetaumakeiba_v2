// lib/services/netkeiba_session_service.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// netkeiba 会員ログイン状態（アプリ内 WebView の Cookie）を扱うサービス。
/// ID・パスワードはアプリ側で一切保持しない。ログインはユーザー自身が NetkeibaLoginPage で行う。
/// Headless WebView（新聞ページ等）は同じ Cookie ストアを自動で使うため、ここでは
/// http パッケージで取得するページ用の Cookie ヘッダーだけを提供する。
class NetkeibaSessionService {
  static const String _prefKeyLoggedIn = 'netkeiba_logged_in';

  /// netkeiba のログインページ
  static const String loginUrl = 'https://regist.netkeiba.com/account/?pid=login';

  static const List<String> _cookieUrls = [
    'https://db.netkeiba.com/',
    'https://race.netkeiba.com/',
    'https://www.netkeiba.com/',
    'https://regist.netkeiba.com/',
  ];

  /// ユーザーが「ログイン完了」を押した状態かどうか。
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKeyLoggedIn) ?? false;
  }

  static Future<void> markLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyLoggedIn, true);
  }

  /// netkeiba の Cookie を削除し、ログイン状態を解除する。
  static Future<void> logout() async {
    for (final url in _cookieUrls) {
      try {
        await CookieManager.instance().deleteCookies(url: WebUri(url));
      } catch (e) {
        debugPrint('NetkeibaSessionService: deleteCookies failed for $url: $e');
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyLoggedIn, false);
  }

  /// http パッケージで [url] を取得する際に付与する Cookie ヘッダー値。
  /// 未ログイン・Cookie 無し・取得失敗時は null を返す。
  static Future<String?> getCookieHeader(String url) async {
    try {
      if (!await isLoggedIn()) return null;
      final cookies = await CookieManager.instance().getCookies(url: WebUri(url));
      if (cookies.isEmpty) return null;
      return cookies.map((c) => '${c.name}=${c.value}').join('; ');
    } catch (e) {
      debugPrint('NetkeibaSessionService: getCookieHeader failed: $e');
      return null;
    }
  }
}
