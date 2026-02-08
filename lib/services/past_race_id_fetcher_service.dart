// lib/services/past_race_id_fetcher_service.dart
import 'dart:async';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:hetaumakeiba_v2/services/scraper_service.dart';

// 取得結果の状態を示すenum
enum FetchStatus { success, pageNotSupported, temporaryError, empty }

/// 過去レースの詳細情報項目
class PastRaceItem {
  final String raceId;
  final String date;
  final String venue; // 開催場 (例: 1中山9)
  final String raceName;
  final String distance; // 距離 (例: 芝2000)

  PastRaceItem({
    required this.raceId,
    required this.date,
    required this.venue,
    required this.raceName,
    required this.distance,
  });
}

// 取得結果を格納するクラス
class PastRaceIdResult {
  final FetchStatus status;
  // 既存互換用: IDとレース名のマップ
  final Map<String, String> pastRaces;
  // 新規追加: 詳細情報のリスト
  final List<PastRaceItem> pastRaceItems;
  // 新規追加: 続きを取得するためのベースURL (ページネーション用)
  final String? baseListUrl;
  final String? message;

  PastRaceIdResult(
      this.status, {
        this.pastRaces = const {},
        this.pastRaceItems = const [],
        this.baseListUrl,
        this.message,
      });
}

class PastRaceIdFetcherService {
  /// 踏み台ロジックを使って過去レース一覧を取得するメインメソッド
  Future<PastRaceIdResult> fetchPastRaceIds(String baseRaceId, String raceName) async {
    print("DEBUG: fetchPastRaceIds called for raceId: $baseRaceId");

    // Step 1: past10.html から「踏み台」となる過去IDを取得
    // ※raceNameは引数として受け取るが、新ロジックではIDのみで判定するため使用しない
    String? stepStoneId;
    try {
      stepStoneId = await _fetchStepStoneIdFromPast10(baseRaceId);
    } catch (e) {
      print("DEBUG: Failed to fetch step stone ID: $e");
      return PastRaceIdResult(FetchStatus.empty, message: "Step stone ID not found");
    }

    if (stepStoneId == null) {
      print("DEBUG: No step stone ID found.");
      return PastRaceIdResult(FetchStatus.empty);
    }

    print("DEBUG: Step stone ID found: $stepStoneId. Proceeding to DB...");

    // Step 2: 踏み台IDを使ってDBページへ行き、一覧リストのURLを取得してデータ取得
    return await _fetchListFromDb(stepStoneId);
  }

  /// 追加読み込み用メソッド (ページネーション)
  Future<List<PastRaceItem>> fetchMorePastRaces(String baseListUrl, int page) async {
    final targetUrl = "$baseListUrl&page=$page";
    print("DEBUG: Fetching more races from: $targetUrl");

    final htmlContent = await _fetchHtmlContent(targetUrl);
    if (htmlContent == null) return [];

    final rawList = ScraperService.scrapeRaceIdListFromDbPage(htmlContent);

    return rawList.map((e) => PastRaceItem(
      raceId: e['raceId']!,
      date: e['date']!,
      venue: e['venue']!,
      raceName: e['raceName']!,
      distance: e['distance']!,
    )).toList();
  }

  // ---------------- private methods ----------------

  /// past10.html にアクセスし、最新の過去ID（踏み台）を取得する
  /// ロジック: baseRaceIdの1年前の年号を含む db.netkeiba.com のリンクを探す
  Future<String?> _fetchStepStoneIdFromPast10(String baseRaceId) async {
    final completer = Completer<String?>();
    late HeadlessInAppWebView browser;
    final url = "https://race.netkeiba.com/race/past10.html?race_id=$baseRaceId";

    final timer = Timer(const Duration(seconds: 15), () {
      if (!completer.isCompleted) {
        browser.dispose();
        completer.completeError(TimeoutException("Timeout fetching step stone ID"));
      }
    });

    browser = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(url)),
      initialSettings: InAppWebViewSettings(
        userAgent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36",
      ),
      onConsoleMessage: (controller, consoleMessage) {
        if (consoleMessage.message.startsWith("DEBUG_JS:")) {
          print(consoleMessage.message);
        }
      },
      onLoadStop: (controller, url) async {
        if (completer.isCompleted) return;
        await Future.delayed(const Duration(seconds: 3)); // 描画待ち
        if (completer.isCompleted) return;

        try {
          // JS実行: 1年前のIDを含むDBリンクをピンポイントで探す
          final result = await controller.evaluateJavascript(source: """
            (function() {
              const baseId = '$baseRaceId';
              const baseYear = parseInt(baseId.substring(0, 4)); // 例: 2026
              
              console.log('DEBUG_JS: Searching for step stone ID. Base Year: ' + baseYear);

              // 過去10年分遡って検索 (通常は1年前で見つかるはず)
              for (let offset = 1; offset <= 10; offset++) {
                const targetYear = baseYear - offset; // 例: 2025
                console.log('DEBUG_JS: Checking for year: ' + targetYear);
                
                // 条件: 
                // 1. hrefに "db.netkeiba.com" を含む (レース結果DBへのリンク)
                // 2. hrefに "/race/" + targetYear を含む (その年のレースID)
                // ※ netkeibaは "//race/" とスラッシュが重なる場合があるため、"/race/" だけでマッチさせる
                
                const selector = 'a[href*="db.netkeiba.com"][href*="/race/' + targetYear + '"]';
                const links = document.querySelectorAll(selector);
                
                if (links.length > 0) {
                   console.log('DEBUG_JS: Found candidates for ' + targetYear + ': ' + links.length);
                   
                   // 最初に見つかったリンクを採用
                   const href = links[0].href;
                   
                   // 12桁のIDを正規表現で抽出 (targetYearから始まる数字)
                   const match = href.match(new RegExp(targetYear + '\\\\d{8}'));
                   if (match) {
                      const foundId = match[0];
                      console.log('DEBUG_JS: Match Found! ID: ' + foundId + ' from URL: ' + href);
                      return foundId;
                   }
                }
              }
              
              console.log('DEBUG_JS: No suitable step stone ID found in DB links.');
              return null;
            })();
          """);

          completer.complete(result as String?);
        } catch (e) {
          if (!completer.isCompleted) completer.completeError(e);
        }
      },
      onReceivedError: (controller, request, error) {
        if (request.isForMainFrame == true && !completer.isCompleted) {
          completer.completeError(Exception("WebView Error: ${error.description}"));
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

  /// 踏み台IDのDBページから一覧リンクを取得し、リストを取得する
  Future<PastRaceIdResult> _fetchListFromDb(String stepStoneId) async {
    final completer = Completer<PastRaceIdResult>();
    late HeadlessInAppWebView browser;
    final url = "https://db.netkeiba.com/race/$stepStoneId/";

    final timer = Timer(const Duration(seconds: 20), () {
      if (!completer.isCompleted) {
        browser.dispose();
        completer.completeError(TimeoutException("Timeout fetching DB list"));
      }
    });

    browser = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(url)),
      initialSettings: InAppWebViewSettings(
        userAgent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36",
      ),
      onLoadStop: (controller, url) async {
        if (completer.isCompleted) return;
        await Future.delayed(const Duration(seconds: 2));
        if (completer.isCompleted) return;

        try {
          final listUrl = await controller.evaluateJavascript(source: """
            (function() {
              const links = document.querySelectorAll('a[href*="pid=race_list"]');
              if (links.length > 0) {
                return links[0].href;
              }
              return null;
            })();
          """) as String?;

          if (listUrl == null) {
            completer.complete(PastRaceIdResult(FetchStatus.empty));
            return;
          }

          print("DEBUG: List URL found: $listUrl");

          completer.complete(PastRaceIdResult(FetchStatus.success, baseListUrl: listUrl));

        } catch (e) {
          if (!completer.isCompleted) completer.completeError(e);
        }
      },
    );

    try {
      await browser.run();
      final result = await completer.future;

      if (result.status == FetchStatus.success && result.baseListUrl != null) {
        final htmlContent = await _fetchHtmlContent(result.baseListUrl!);
        if (htmlContent != null) {
          final rawList = ScraperService.scrapeRaceIdListFromDbPage(htmlContent);

          final items = rawList.map((e) => PastRaceItem(
            raceId: e['raceId']!,
            date: e['date']!,
            venue: e['venue']!,
            raceName: e['raceName']!,
            distance: e['distance']!,
          )).toList();

          final Map<String, String> map = {};
          for (var item in items) {
            map[item.raceId] = item.raceName;
          }

          return PastRaceIdResult(
            FetchStatus.success,
            pastRaces: map,
            pastRaceItems: items,
            baseListUrl: result.baseListUrl,
          );
        }
        return PastRaceIdResult(FetchStatus.empty);
      }

      return result;
    } finally {
      timer.cancel();
      await browser.dispose();
    }
  }

  /// 指定URLのHTMLを取得するための汎用メソッド
  Future<String?> _fetchHtmlContent(String url) async {
    final completer = Completer<String?>();
    late HeadlessInAppWebView browser;

    browser = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(url)),
      initialSettings: InAppWebViewSettings(
        userAgent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36",
      ),
      onLoadStop: (controller, url) async {
        if (completer.isCompleted) return;
        await Future.delayed(const Duration(milliseconds: 1500));

        try {
          final html = await controller.getHtml();
          completer.complete(html);
        } catch (e) {
          if (!completer.isCompleted) completer.completeError(e);
        }
      },
    );

    try {
      await browser.run();
      return await completer.future;
    } catch (e) {
      print("DEBUG: Failed to fetch HTML content: $e");
      return null;
    } finally {
      await browser.dispose();
    }
  }
}