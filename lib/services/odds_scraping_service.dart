// lib/services/odds_scraping_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../utils/url_generator.dart';

class OddsScrapingService {
  HeadlessInAppWebView? _headlessWebView;

  Future<List<Map<String, String>>> fetchOddsViaWebView({
    required String raceId,
    required String oddsType,
  }) async {
    final completer = Completer<List<Map<String, String>>>();
    final url = generateOddsUrl(raceId: raceId, oddsType: oddsType);

    _headlessWebView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(url)),
      initialSettings: InAppWebViewSettings(
        userAgent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/537.36",
        javaScriptEnabled: true,
      ),
      onLoadStop: (controller, url) async {
        // オッズのJS展開を待機
        await Future.delayed(const Duration(seconds: 2));

        const String extractJs = '''
          (function() {
            var results = [];
            var elements = document.querySelectorAll('span[id^="odds-"]');
            for (var i = 0; i < elements.length; i++) {
              var id = elements[i].id;
              var value = elements[i].textContent.trim();
              if (value !== "" && value !== "---.-") {
                results.push({"combination": id.replace('odds-', ''), "odds": value});
              }
            }
            return JSON.stringify(results);
          })();
        ''';

        try {
          final String? resultJson = await controller.evaluateJavascript(source: extractJs);
          if (resultJson != null) {
            final List<dynamic> parsedList = json.decode(resultJson);
            final results = parsedList.map((e) => {
              "combination": e["combination"].toString(),
              "odds": e["odds"].toString(),
            }).toList();
            completer.complete(results);
          } else {
            completer.complete([]);
          }
        } catch (e) {
          completer.completeError(e);
        }
      },
    );

    await _headlessWebView!.run();
    final result = await completer.future;
    await _headlessWebView!.dispose();
    return result;
  }
}