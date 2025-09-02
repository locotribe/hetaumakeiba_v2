// lib/services/race_schedule_scraper_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:hetaumakeiba_v2/models/race_schedule_model.dart';
import 'package:hetaumakeiba_v2/utils/url_generator.dart';
import 'package:intl/intl.dart';

typedef InitialData = (List<String> dates, RaceSchedule? schedule);

class RaceScheduleScraperService {
  Future<InitialData> fetchInitialData(DateTime representativeDate) async {
    final completer = Completer<InitialData>();
    final url = WebUri(generateRaceListUrl(representativeDate));
    HeadlessInAppWebView? headlessWebView;

    // タイムアウトを25秒に設定
    final timer = Timer(const Duration(seconds: 25), () {
      if (!completer.isCompleted) {
        completer.completeError("Initial data fetching timed out for $url");
        headlessWebView?.dispose();
      }
    });

    headlessWebView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: url),
      initialSettings: InAppWebViewSettings(
        userAgent:
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/5.37.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/5.37.36",
        javaScriptEnabled: true,
        loadsImagesAutomatically: false,
        blockNetworkImage: true,
      ),

      // WebViewのレンダラープロセスクラッシュを検知するコールバック
      onRenderProcessGone: (controller, detail) async {
        if (!completer.isCompleted) {
          completer.completeError(
              "WebView renderer process crashed during initial fetch.");
        }
      },

      onLoadStop: (controller, url) async {
        if (completer.isCompleted) return;
        try {
          // レース一覧コンテナが表示されるまで最大10秒待機
          const String checkElementSelector = "div.RaceList_Body";
          const int maxRetries = 20;
          const Duration retryDelay = Duration(milliseconds: 500);

          bool isContentLoaded = false;
          for (int i = 0; i < maxRetries; i++) {
            final elementExists = await controller.evaluateJavascript(source: """
              (function() { return document.querySelector('$checkElementSelector') != null; })();
            """);
            if (elementExists == true) {
              isContentLoaded = true;
              break;
            }
            await Future.delayed(retryDelay);
          }

          // タイムアウトした場合
          if (!isContentLoaded) {
            // 開催情報がない週（正常な空ページ）かどうかを確認
            final noRaceMessageExists = await controller.evaluateJavascript(source: """
              (function() { return document.querySelector('.NoData_Comment') != null; })();
            """);
            if (noRaceMessageExists == true) {
              completer.complete((<String>[], null)); // 開催なしとして正常完了
              return;
            }
            completer.completeError("Scraping timed out: Page content '$checkElementSelector' did not appear.");
            return;
          }

          // ページ描画を確認後、スクレイピング実行
          final result =
          await controller.evaluateJavascript(source: _getScrapingScript());

          if (result == null) {
            completer.complete((<String>[], null));
            return;
          }

          final decodedResult = json.decode(result);
          final List<String> dates =
          List<String>.from(decodedResult['dates'] ?? []);
          final List<dynamic> scheduleData = decodedResult['schedule'] ?? [];

          RaceSchedule? schedule =
          _parseScheduleData(scheduleData, representativeDate);

          completer.complete((dates, schedule));
        } catch (e) {
          if (!completer.isCompleted) completer.completeError(e);
        }
      },
      onReceivedError: (controller, request, error) {
        if (!completer.isCompleted) completer.completeError(error.description);
      },
    );
    try {
      await headlessWebView.run();
      return await completer.future;
    } catch (e) {
      print("Error in fetchInitialData for $url: $e");
      return (<String>[], null);
    } finally {
      timer.cancel();
      await headlessWebView.dispose();
    }
  }

  Future<RaceSchedule?> scrapeRaceSchedule(DateTime date) async {
    final completer = Completer<RaceSchedule?>();
    final url = WebUri(generateRaceListUrl(date));

    HeadlessInAppWebView? headlessWebView;

    // タイムアウトを25秒に設定
    final timer = Timer(const Duration(seconds: 25), () {
      if (!completer.isCompleted) {
        completer.completeError("Scraping timed out after 25 seconds for $url");
        headlessWebView?.dispose();
      }
    });

    headlessWebView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: url),
      initialSettings: InAppWebViewSettings(
        userAgent:
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/5.37.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/5.37.36",
        javaScriptEnabled: true,
        loadsImagesAutomatically: false,
        blockNetworkImage: true,
      ),

      // WebViewのレンダラープロセスクラッシュを検知するコールバック
      onRenderProcessGone: (controller, detail) async {
        if (!completer.isCompleted) {
          completer.completeError(
              "WebView renderer process crashed. The page is too complex or unstable.");
        }
      },

      onLoadStop: (controller, url) async {
        if (completer.isCompleted) return;
        try {
          // レース一覧コンテナが表示されるまで最大10秒待機
          const String checkElementSelector = "div.RaceList_Body";
          const int maxRetries = 20;
          const Duration retryDelay = Duration(milliseconds: 500);

          bool isContentLoaded = false;
          for (int i = 0; i < maxRetries; i++) {
            final elementExists = await controller.evaluateJavascript(source: """
              (function() { return document.querySelector('$checkElementSelector') != null; })();
            """);
            if (elementExists == true) {
              isContentLoaded = true;
              break;
            }
            await Future.delayed(retryDelay);
          }

          if (!isContentLoaded) {
            final noRaceMessageExists = await controller.evaluateJavascript(source: """
              (function() { return document.querySelector('.NoData_Comment') != null; })();
            """);
            if (noRaceMessageExists == true) {
              completer.complete(null);
              return;
            }
            completer.completeError("Scraping timed out: Page content '$checkElementSelector' did not appear.");
            return;
          }

          // ページ描画を確認後、スクレイピング実行
          final result = await controller.evaluateJavascript(
              source: _getScrapingScript(isInitial: false));

          if (result == null) {
            completer.complete(null);
            return;
          }
          final decodedResult = json.decode(result);
          final List<dynamic> scheduleData = decodedResult['schedule'] ?? [];
          completer.complete(_parseScheduleData(scheduleData, date));
        } catch (e) {
          if (!completer.isCompleted) completer.completeError(e);
        }
      },
      onReceivedError: (controller, request, error) {
        if (!completer.isCompleted) {
          completer.completeError("Failed to load page: ${error.description}");
        }
      },
    );

    try {
      await headlessWebView.run();
      return await completer.future;
    } catch (e) {
      print("Error in scrapeRaceSchedule for $url: $e");
      return null;
    } finally {
      timer.cancel();
      await headlessWebView.dispose();
    }
  }

  String _getScrapingScript({bool isInitial = true}) {
    return """
      (function() {
        const dateElements = Array.from(document.querySelectorAll('#date_list_sub li'));
        const dates = dateElements.map(li => li.getAttribute('date')).filter(date => date);
        
        const mainTitleElement = document.querySelector('#date_list_sub li.ui-tabs-active a');
        const mainTitle = mainTitleElement ? mainTitleElement.innerText.trim().replace(/\\s+/g, ' ') : '';
  
        const raceBlocks = Array.from(document.querySelectorAll('dl.RaceList_DataList'));
        let allRacesData = [];
        raceBlocks.forEach(block => {
          const venueTitleElement = block.querySelector('.RaceList_DataTitle');
          const venueTitle = venueTitleElement ? venueTitleElement.textContent.trim().replace(/\\s+/g, ' ') : '';
          
          const raceItems = Array.from(block.querySelectorAll('li.RaceList_DataItem'));
          raceItems.forEach(item => {
            const link = item.querySelector('a[href*="result.html"], a[href*="shutuba.html"]');
            if (!link) return;
  
            const raceNumberElement = item.querySelector('.Race_Num');
            const raceNameElement = item.querySelector('.RaceList_ItemTitle .ItemTitle');
            const detailsElement = item.querySelector('.RaceData');
            const gradeSpan = item.querySelector('span[class*="Icon_GradeType"]');
  
            allRacesData.push({
              mainTitle: mainTitle,
              venueTitle: venueTitle,
              raceNumber: raceNumberElement ? raceNumberElement.innerText.trim() : '',
              raceName: raceNameElement ? raceNameElement.innerText.trim() : '',
              href: link.href,
              gradeTypeClass: gradeSpan ? gradeSpan.className : '',
              details: detailsElement ? detailsElement.innerText.trim().replace(/\\s+/g, ' ') : ''
            });
          });
        });
        
        return JSON.stringify(${isInitial ? '{ "dates": dates, "schedule": allRacesData }' : '{ "schedule": allRacesData }'});
      })();
    """;
  }

  RaceSchedule? _parseScheduleData(
      List<dynamic> scheduleData, DateTime date) {
    if (scheduleData.isEmpty) {
      return null;
    }

    final firstItem = scheduleData.first;
    final dateString = firstItem['mainTitle'] as String;

    final dayOfWeek = dateString.contains('(')
        ? dateString.substring(
        dateString.indexOf('(') + 1, dateString.indexOf(')'))
        : DateFormat.E('ja').format(date);

    final Map<String, List<SimpleRaceInfo>> venuesMap = {};
    final RegExp raceIdRegex = RegExp(r'race_id=([^&]+)');

    for (var item in scheduleData) {
      final venueTitle = item['venueTitle'] as String;
      if (venueTitle.isEmpty) continue;

      final href = item['href'] as String;

      final match = raceIdRegex.firstMatch(href);
      if (match == null) continue;
      final raceId = match.group(1)!;

      final raceInfo = SimpleRaceInfo(
          raceId: raceId,
          raceNumber: item['raceNumber'] ?? '',
          raceName: item['raceName'] ?? '',
          grade: _getGradeTypeText(item['gradeTypeClass']),
          details: item['details'] ?? '');

      venuesMap.putIfAbsent(venueTitle, () => []).add(raceInfo);
    }

    if (venuesMap.isEmpty) {
      return null;
    }

    final List<VenueSchedule> venues = venuesMap.entries.map((entry) {
      return VenueSchedule(venueTitle: entry.key, races: entry.value);
    }).toList();

    return RaceSchedule(
      date: DateFormat('yyyy-MM-dd').format(date),
      dayOfWeek: dayOfWeek,
      venues: venues,
    );
  }

  String _getGradeTypeText(String className) {
    if (className.contains('Icon_GradeType18')) return '1勝';
    if (className.contains('Icon_GradeType17')) return '2勝';
    if (className.contains('Icon_GradeType16')) return '3勝';
    if (className.contains('Icon_GradeType15')) return 'L';
    if (className.contains('Icon_GradeType5')) return 'OP';
    if (className.contains('Icon_GradeType3')) return 'G3';
    if (className.contains('Icon_GradeType2')) return 'G2';
    if (className.contains('Icon_GradeType1')) return 'G1';
    return '';
  }
}