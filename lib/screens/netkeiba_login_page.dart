// lib/screens/netkeiba_login_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:hetaumakeiba_v2/services/netkeiba_session_service.dart';

/// netkeiba の会員ログインをアプリ内 WebView で行う画面。
/// 入力はユーザー自身が netkeiba の画面で行い、アプリは ID・パスワードを扱わない。
class NetkeibaLoginPage extends StatelessWidget {
  const NetkeibaLoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('netkeiba ログイン'),
        actions: [
          // [修正] テーマの文字色が緑のアプリバーに埋もれて見えなかったため、白文字＋チェックアイコンにする (v.2026.9.22+26092205)
          TextButton.icon(
            onPressed: () async {
              await NetkeibaSessionService.markLoggedIn();
              if (context.mounted) Navigator.of(context).pop(true);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('ログイン完了'),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.amber.shade50,
            padding: const EdgeInsets.all(8),
            child: const Text(
              'netkeiba の画面でログインしてから、右上の「ログイン完了」を押してください。'
                  'ID・パスワードはアプリには保存されません。',
              style: TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(NetkeibaSessionService.loginUrl)),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                // [追加] netkeiba が http へ転送するため、遷移を監視して https に書き換える (v.2026.9.22+26092205)
                useShouldOverrideUrlLoading: true,
                userAgent:
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/5.37.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/5.37.36",
              ),
              // [追加] netkeiba ドメインへの http 遷移は Android で ERR_CLEARTEXT_NOT_PERMITTED になるため、
              // https に書き換えて読み込み直す（アプリ全体の http 許可は変更しない） (v.2026.9.22+26092205)
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                final url = navigationAction.request.url;
                if (url != null && url.scheme == 'http' && url.host.endsWith('netkeiba.com')) {
                  final httpsUrl = url.toString().replaceFirst('http://', 'https://');
                  await controller.loadUrl(urlRequest: URLRequest(url: WebUri(httpsUrl)));
                  return NavigationActionPolicy.CANCEL;
                }
                return NavigationActionPolicy.ALLOW;
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 設定画面に置く netkeiba ログイン欄。
class NetkeibaLoginSection extends StatefulWidget {
  const NetkeibaLoginSection({super.key});

  @override
  State<NetkeibaLoginSection> createState() => _NetkeibaLoginSectionState();
}

class _NetkeibaLoginSectionState extends State<NetkeibaLoginSection> {
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loggedIn = await NetkeibaSessionService.isLoggedIn();
    if (mounted) setState(() => _isLoggedIn = loggedIn);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('netkeiba 会員ログイン', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          _isLoggedIn
              ? 'ログイン済み（有料会員データを取得します）'
              : '未ログイン（有料会員データは表示されません）',
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ElevatedButton(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NetkeibaLoginPage()),
                );
                await _load();
              },
              child: Text(_isLoggedIn ? '再ログイン' : 'ログイン'),
            ),
            const SizedBox(width: 12),
            if (_isLoggedIn)
              TextButton(
                onPressed: () async {
                  await NetkeibaSessionService.logout();
                  await _load();
                },
                child: const Text('ログアウト', style: TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ],
    );
  }
}
