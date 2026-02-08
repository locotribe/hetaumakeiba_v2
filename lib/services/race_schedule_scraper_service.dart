// lib/services/race_schedule_scraper_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:hetaumakeiba_v2/models/race_schedule_model.dart';
import 'package:hetaumakeiba_v2/utils/url_generator.dart';
import 'package:intl/intl.dart';

typedef InitialData = (List<String> dates, RaceSchedule? schedule);

class RaceScheduleScraperService {
  /// 週の初期データを取得する
  /// [onProgress] : 進捗状況をUIに通知するコールバック
  Future<InitialData> fetchInitialData(
      DateTime representativeDate, {
        Function(String)? onProgress,
      }) async {
    // 1. まずは代表日（通常は日曜日）をチェック
    if (onProgress != null) {
      onProgress('${DateFormat('M/d').format(representativeDate)}の開催情報を確認中...');
    }

    var (dates, schedule) = await _scrapeDataForDate(representativeDate);

    // データが見つかれば、通常通り即終了（高速化のため）
    if (dates.isNotEmpty) {
      return (dates, schedule);
    }

    // 2. 日曜日にデータがない場合（変則日程や延期の可能性）
    // 土曜日から月曜日まで遡って全てチェックし、見つかった日付を全て統合する
    final Set<String> allFoundDates = {};
    RaceSchedule? bestSchedule;

    // 日曜日はチェック済みなので、1日前（土曜）から6日前（月曜）までループ
    for (int i = 1; i <= 6; i++) {
      final targetDate = representativeDate.subtract(Duration(days: i));

      if (onProgress != null) {
        onProgress('${DateFormat('M/d').format(targetDate)}の開催情報を確認中...');
      }

      final result = await _scrapeDataForDate(targetDate);
      final foundDates = result.$1;
      final foundSchedule = result.$2;

      if (foundDates.isNotEmpty) {
        allFoundDates.addAll(foundDates);
        // スケジュールは「最初に見つかったもの（＝日付が新しいもの）」または「任意のもの」を保持
        // ここでは、データがある日のスケジュールを一つ確保しておく
        bestSchedule ??= foundSchedule;
      }
    }

    // 見つかった全ての日付リストを昇順にソートして返す
    final sortedDates = allFoundDates.toList()..sort();
    return (sortedDates, bestSchedule);
  }

  /// 指定した日付のスクレイピングを実行する内部メソッド
  Future<InitialData> _scrapeDataForDate(DateTime date) async {
    final completer = Completer<InitialData>();
    final url = WebUri(generateRaceListUrl(date));
    HeadlessInAppWebView? headlessWebView;

    // タイムアウト用タイマー
    final timer = Timer(const Duration(seconds: 25), () {
      if (!completer.isCompleted) {
        print("Scraping timed out for $url");
        // タイムアウト時は空データを返して次の日付へ進ませる
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

          // コンテンツがなくても、NoData_Commentがあれば正常な空ページとみなして続行
          // （タブ情報だけ取得できる可能性があるため）
          if (!isContentLoaded) {
            final noRaceMessageExists = await controller.evaluateJavascript(source: """
              (function() { return document.querySelector('.NoData_Comment') != null; })();
            """);

            // 本当に何もない（読み込み失敗）場合は空を返す
            if (noRaceMessageExists != true) {
              completer.complete((<String>[], null));
              return;
            }
          }

          final result = await controller.evaluateJavascript(source: _getScrapingScript());

          if (result == null) {
            completer.complete((<String>[], null));
            return;
          }

          final decodedResult = json.decode(result);
          final List<String> dates = List<String>.from(decodedResult['dates'] ?? []);
          final List<dynamic> scheduleData = decodedResult['schedule'] ?? [];

          RaceSchedule? schedule = _parseScheduleData(scheduleData, date);
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
      print("Error in _scrapeDataForDate for $url: $e");
      return (<String>[], null);
    } finally {
      timer.cancel();
      if (headlessWebView != null) await headlessWebView.dispose();
    }
  }

  Future<RaceSchedule?> scrapeRaceSchedule(DateTime date) async {
    // 既存のメソッドはそのまま維持（_scrapeDataForDateとロジックは似ているが戻り値が違うため）
    // ※必要であればここもリファクタリング可能ですが、今回は「取得方法を変えない」方針に従い維持します。
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
            completer.completeError("Scraping timed out: Page content '$checkElementSelector' did not appear.");
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