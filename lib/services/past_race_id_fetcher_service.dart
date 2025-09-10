// lib/services/past_race_id_fetcher_service.dart
import 'dart:async';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

// 取得結果の状態を示すenum
enum FetchStatus { success, pageNotSupported, temporaryError, empty }

// 取得結果を格納するクラス
class PastRaceIdResult {
  final FetchStatus status;
  final Map<String, String> pastRaces;
  final String? message;

  PastRaceIdResult(this.status, {this.pastRaces = const {}, this.message});
}

class PastRaceIdFetcherService {
  Future<PastRaceIdResult> fetchPastRaceIds(String baseRaceId, {int retries = 2}) async {
    for (int i = 0; i <= retries; i++) {
      try {
        return await _attemptFetch(baseRaceId);
      } catch (e) {
        if (e is TimeoutException || i == retries) {
          // タイムアウトまたは最終リトライでも失敗した場合
          return PastRaceIdResult(FetchStatus.temporaryError, message: e.toString());
        }
        // リトライの間に少し待つ
        await Future.delayed(const Duration(seconds: 1));
      }
    }
    // この行は到達しないはずだが、念のため
    return PastRaceIdResult(FetchStatus.temporaryError, message: 'Max retries reached');
  }

  Future<PastRaceIdResult> _attemptFetch(String baseRaceId) async {
    final completer = Completer<PastRaceIdResult>();
    late HeadlessInAppWebView browser;
    final url = "https://race.netkeiba.com/race/past10.html?race_id=$baseRaceId";

    // タイムアウトを短めに設定し、リトライしやすくする
    final timer = Timer(const Duration(seconds: 20), () {
      if (!completer.isCompleted) {
        browser.dispose();
        completer.completeError(TimeoutException("Scraping timed out for $url"));
      }
    });

    browser = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(url)),
      initialSettings: InAppWebViewSettings(
        userAgent:
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/5.37.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/5.37.36",
      ),
      onLoadStop: (controller, url) async {
        if (completer.isCompleted) return;

        // ページの描画とJS実行のために3秒間待機する
        await Future.delayed(const Duration(seconds: 3));

        // 待機中にタイムアウトした可能性を考慮して再度チェック
        if (completer.isCompleted) return;

        try {
          // 「重賞のみ」のメッセージが存在するかチェック
          final isNotSupported = await controller.evaluateJavascript(source: """
            (function() {
              return document.body.innerText.includes('過去の結果は重賞レースのみの提供となります');
            })();
          """);

          if (isNotSupported == true) {
            completer.complete(PastRaceIdResult(FetchStatus.pageNotSupported));
            return;
          }

          // レースIDとレース名の両方を取得
          final result = await controller.evaluateJavascript(source: """
  (function() {
    const links = document.querySelectorAll('a[href*="race_id="]');
    return Array.from(links)
      .map(a => {
        const idMatch = a.href.match(/race_id=(\\d{12})/);
        const title = a.getAttribute('title'); // <a>タグのtitle属性を取得

        if (idMatch && title) {
          return {
            id: idMatch[1],
            // titleから「 レース映像」という文字列を削除し、前後の空白も除去
            name: title.replace(' レース映像', '').trim()
          };
        }
        return null;
      })
      .filter(item => item !== null);
  })();
""");

          final List<dynamic> raceObjects = result ?? [];
          final Map<String, String> pastRaces = {};

          final currentYear = DateTime.now().year;
          final startYear = currentYear - 1;
          final endYear = currentYear - 10;

          for (var item in raceObjects) {
            if (item is Map) {
              final id = item['id'] as String?;
              final name = item['name'] as String?;

              if (id != null && name != null && name.isNotEmpty) {
                final year = int.tryParse(id.substring(0, 4));
                if (id != baseRaceId && year != null && year <= startYear && year >= endYear) {
                  pastRaces[id] = name;
                }
              }
            }
          }

          if (pastRaces.isEmpty) {
            completer.complete(PastRaceIdResult(FetchStatus.empty));
          } else {
            completer.complete(PastRaceIdResult(FetchStatus.success, pastRaces: pastRaces));
          }

        } catch (e) {
          if (!completer.isCompleted) {
            completer.completeError(e);
          }
        }
      },
      onReceivedError: (controller, request, error) {
        if (!completer.isCompleted) {
          completer.completeError(Exception("Failed to load page: ${error.description}"));
        }
      },
    );

    try {
      await browser.run();
      return await completer.future;
    } finally {
      timer.cancel();
      await browser.dispose();
    }
  }
}