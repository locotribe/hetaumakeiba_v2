// lib/services/past_race_id_fetcher_service.dart
import 'dart:async';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class PastRaceIdFetcherService {
  Future<List<String>> fetchPastRaceIds(String baseRaceId) async {
    final completer = Completer<List<String>>();
    late HeadlessInAppWebView browser;

    final url = "https://race.netkeiba.com/race/past10.html?race_id=$baseRaceId";

    final timer = Timer(const Duration(seconds: 30), () {
      if (!completer.isCompleted) {
        completer.completeError(Exception("Scraping timed out for $url"));
        browser.dispose();
      }
    });

    browser = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(url)),
      initialSettings: InAppWebViewSettings(
        userAgent:
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36",
      ),
      onLoadStop: (controller, url) async {
        if (completer.isCompleted) return;
        try {
          final result = await controller.evaluateJavascript(source: """
            (function() {
              const links = document.querySelectorAll('a[href*="race_id="]');
              return Array.from(links)
                .map(a => a.href)
                .map(href => href.match(/race_id=(\\d{12})/)?.[1])
                .filter(id => id);
            })();
          """);

          final List<dynamic> ids = result ?? [];
          final allUniqueIds = ids.whereType<String>().toSet();

          // 過去10年間のレースIDだけを抽出
          final currentYear = DateTime.now().year;
          final startYear = currentYear - 1; // 昨年
          final endYear = currentYear - 10;  // 10年前

          final filteredIds = allUniqueIds.where((id) {
            final year = int.tryParse(id.substring(0, 4));
            // 基準ID自体は含めず、過去10年分(昨年まで)のIDを対象とする
            return id != baseRaceId && year != null && year <= startYear && year >= endYear;
          }).toList();

          completer.complete(filteredIds);

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