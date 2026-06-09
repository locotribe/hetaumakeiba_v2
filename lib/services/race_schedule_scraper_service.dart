// lib/services/race_schedule_scraper_service.dart
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:hetaumakeiba_v2/models/race_schedule_model.dart';
import 'package:hetaumakeiba_v2/utils/url_generator.dart';
import 'package:intl/intl.dart';

typedef InitialData = (List<String> dates, RaceSchedule? schedule);

class RaceScheduleScraperService {
  Future<InitialData> fetchInitialData(
      DateTime? representativeDate, {
        Function(String)? onProgress,
      }) async {
    if (onProgress != null) {
      String dateLabel = representativeDate != null
          ? DateFormat('M/d').format(representativeDate)
          : "最新";
      onProgress('$dateLabelの開催情報を確認中...');
    }

    return await _scrapeDataForDate(representativeDate);
  }

  Future<InitialData> _scrapeDataForDate(DateTime? date) async {
    final completer = Completer<InitialData>();

    final String urlString = date != null
        ? generateRaceListUrl(date)
        : "https://race.netkeiba.com/top/race_list.html";

    final url = WebUri(urlString);
    HeadlessInAppWebView? headlessWebView;

    final timer = Timer(const Duration(seconds: 25), () {
      if (!completer.isCompleted) {
        debugPrint("Scraping timed out for $url");
        if (headlessWebView != null) headlessWebView!.dispose();
        completer.complete((<String>[], null));
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
      onRenderProcessGone: (controller, detail) async {
        if (!completer.isCompleted) {
          completer.complete((<String>[], null));
        }
      },
      onLoadStop: (controller, url) async {
        if (completer.isCompleted) return;
        try {
          const String checkSelector = "#date_list_sub, .RaceList_Body, .NoData_Comment";
          const int maxRetries = 20;
          const Duration retryDelay = Duration(milliseconds: 300);

          bool isContentLoaded = false;
          for (int i = 0; i < maxRetries; i++) {
            final elementExists = await controller.evaluateJavascript(source: """
              (function() { return document.querySelector('$checkSelector') != null; })();
            """);
            if (elementExists == true) {
              isContentLoaded = true;
              break;
            }
            await Future.delayed(retryDelay);
          }

          if (!isContentLoaded) {
            completer.complete((<String>[], null));
            return;
          }

          final hasNoData = await controller.evaluateJavascript(source: """
            (function() { return document.querySelector('.NoData_Comment') != null; })();
          """);

          if (hasNoData == true) {
            completer.complete((<String>[], null));
            return;
          }

          final result =
          await controller.evaluateJavascript(source: _getScrapingScript());

          if (result == null) {
            completer.complete((<String>[], null));
            return;
          }

          final decodedResult = json.decode(result);
          final List<String> dates =
          List<String>.from(decodedResult['dates'] ?? []);
          // ★修正: activeDate をスクリプトから取得する
          final String? activeDate = decodedResult['activeDate'] as String?;
          final List<dynamic> scheduleData = decodedResult['schedule'] ?? [];

          // 日付の決定ロジック（修正）
          DateTime targetDate;
          if (date != null) {
            // 明示的に日付が指定された場合はそれを使う
            targetDate = date;
          } else if (activeDate != null && activeDate.length == 8) {
            // ★修正: スクリプトが返したアクティブタブの日付を最優先で使う
            targetDate = DateTime(
              int.parse(activeDate.substring(0, 4)),
              int.parse(activeDate.substring(4, 6)),
              int.parse(activeDate.substring(6, 8)),
            );
          } else if (dates.isNotEmpty) {
            // フォールバック: 現在日付に最も近い開催日を選ぶ
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            String bestDate = dates.first;
            Duration bestDiff = Duration(days: 9999);
            for (final ds in dates) {
              if (ds.length != 8) continue;
              final d = DateTime(
                int.parse(ds.substring(0, 4)),
                int.parse(ds.substring(4, 6)),
                int.parse(ds.substring(6, 8)),
              );
              final diff = (d.difference(today)).abs();
              if (diff < bestDiff) {
                bestDiff = diff;
                bestDate = ds;
              }
            }
            targetDate = DateTime(
              int.parse(bestDate.substring(0, 4)),
              int.parse(bestDate.substring(4, 6)),
              int.parse(bestDate.substring(6, 8)),
            );
          } else {
            targetDate = DateTime.now();
          }

          RaceSchedule? schedule = _parseScheduleData(scheduleData, targetDate);
          completer.complete((dates, schedule));
        } catch (e) {
          if (!completer.isCompleted) completer.complete((<String>[], null));
        }
      },
      onReceivedError: (controller, request, error) {
        if (!completer.isCompleted) completer.complete((<String>[], null));
      },
    );

    try {
      await headlessWebView.run();
      return await completer.future;
    } catch (e) {
      debugPrint("Error in _scrapeDataForDate for $url: $e");
      return (<String>[], null);
    } finally {
      timer.cancel();
      if (headlessWebView != null) await headlessWebView.dispose();
    }
  }

  Future<RaceSchedule?> scrapeRaceSchedule(DateTime date) async {
    final completer = Completer<RaceSchedule?>();
    final url = WebUri(generateRaceListUrl(date));
    HeadlessInAppWebView? headlessWebView;

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
      onRenderProcessGone: (controller, detail) async {
        if (!completer.isCompleted) {
          completer.completeError("WebView renderer process crashed.");
        }
      },
      onLoadStop: (controller, url) async {
        if (completer.isCompleted) return;
        try {
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
            completer.completeError(
                "Scraping timed out: Page content '$checkElementSelector' did not appear.");
            return;
          }

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
      debugPrint("Error in scrapeRaceSchedule for $url: $e");
      return null;
    } finally {
      timer.cancel();
      await headlessWebView.dispose();
    }
  }

  String _getScrapingScript({bool isInitial = true}) {
    return """
      (function() {
        const dateElements = Array.from(document.querySelectorAll('#date_list_sub li:not(.rev):not(.fwd)'));
        
        if (dateElements.length === 0) {
          return JSON.stringify({ dates: [], activeDate: null, schedule: [] });
        }

        const dates = dateElements.map(li => {
           const a = li.querySelector('a');
           if (a && a.href) {
              const match = a.href.match(/kaisai_date=(\\d{8})/);
              return match ? match[1] : '';
           }
           return li.getAttribute('date') || '';
        }).filter(d => d);

        // ★修正: アクティブなタブの日付を取得する
        const activeElement = document.querySelector('#date_list_sub li.ui-tabs-active a');
        let activeDate = null;
        if (activeElement && activeElement.href) {
          const activeMatch = activeElement.href.match(/kaisai_date=(\\d{8})/);
          activeDate = activeMatch ? activeMatch[1] : null;
        }
        // ui-tabs-active で取れない場合、最初の li の日付をフォールバックとして使う
        if (!activeDate && dates.length > 0) {
          activeDate = dates[0];
        }
        
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
        
        return JSON.stringify(${isInitial ? '{ "dates": dates, "activeDate": activeDate, "schedule": allRacesData }' : '{ "schedule": allRacesData }'});
      })();
    """;
  }

  RaceSchedule? _parseScheduleData(List<dynamic> scheduleData, DateTime date) {
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
    if (className.contains('Icon_GradeType12')) return 'J.G3';
    if (className.contains('Icon_GradeType11')) return 'J.G2';
    if (className.contains('Icon_GradeType10')) return 'J.G1';
    if (className.contains('Icon_GradeType5')) return 'OP';
    if (className.contains('Icon_GradeType3')) return 'G3';
    if (className.contains('Icon_GradeType2')) return 'G2';
    if (className.contains('Icon_GradeType1')) return 'G1';
    return '';
  }
}