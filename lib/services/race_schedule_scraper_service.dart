// lib/services/race_schedule_scraper_service.dart
import 'dart:async';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:hetaumakeiba_v2/models/race_schedule_model.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

typedef InitialData = (List<String> dates, RaceSchedule? schedule);

class RaceScheduleScraperService {

  Future<InitialData> fetchInitialData(DateTime representativeDate) async {
    final completer = Completer<InitialData>();
    final date = DateFormat('yyyyMMdd').format(representativeDate);
    final url = WebUri("https://race.netkeiba.com/top/race_list.html?kaisai_date=$date");
    HeadlessInAppWebView? headlessWebView;

    final timer = Timer(const Duration(seconds: 25), () {
      if (!completer.isCompleted) {
        completer.completeError("Initial data fetching timed out for $url");
        headlessWebView?.dispose();
      }
    });

    headlessWebView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: url),
      initialSettings: InAppWebViewSettings(
        userAgent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/5.37.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/5.37.36",
        javaScriptEnabled: true,
        loadsImagesAutomatically: false,
        blockNetworkImage: true,
      ),
      onLoadStop: (controller, url) async {
        if (completer.isCompleted) return;
        try {
          final result = await controller.evaluateJavascript(source: """
            (function() {
              const dateElements = Array.from(document.querySelectorAll('#date_list_sub li'));
              const dates = dateElements.map(li => li.getAttribute('date')).filter(date => date);
              const raceBlocks = Array.from(document.querySelectorAll('dl.RaceList_DataList'));
              let allRacesData = [];
              raceBlocks.forEach(block => {
                const titleElement = block.querySelector('.RaceList_DataTitle');
                const title = titleElement ? titleElement.textContent.trim().replace(/\\s+/g, ' ') : '';
                const raceItems = Array.from(block.querySelectorAll('li.RaceList_DataItem'));
                raceItems.forEach(item => {
                  // ▼▼▼【修正点】'result.html'と'shutuba.html'の両方を検索対象にする ▼▼▼
                  const link = item.querySelector('a[href*="result.html"], a[href*="shutuba.html"]');
                  if (!link) return;
                  
                  const gradeSpan = item.querySelector('span[class*="Icon_GradeType"]');
                  const mainTitleElement = document.querySelector('.RaceList_Date.Active .RaceList_DateText');
                  const mainTitle = mainTitleElement ? mainTitleElement.textContent.trim() : '';
                  const detailsElement = item.querySelector('.RaceList_ItemData');
                  allRacesData.push({
                    mainTitle: mainTitle,
                    title: title,
                    text: link.innerText.trim(),
                    href: link.href,
                    gradeTypeClass: gradeSpan ? gradeSpan.className : '',
                    details: detailsElement ? detailsElement.textContent.trim() : ''
                  });
                });
              });
              return JSON.stringify({ dates: dates, schedule: allRacesData });
            })();
          """);

          if (result == null) {
            completer.complete((<String>[], null));
            return;
          }

          final decodedResult = json.decode(result);
          final List<String> dates = List<String>.from(decodedResult['dates'] ?? []);
          final List<dynamic> scheduleData = decodedResult['schedule'] ?? [];

          RaceSchedule? schedule = _parseScheduleData(scheduleData, representativeDate);

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

  /// <summary>
  /// 指定された単一の日付のレーススケジュールをスクレイピングします。
  /// </summary>
  Future<RaceSchedule?> scrapeRaceSchedule(DateTime date) async {
    final completer = Completer<RaceSchedule?>();
    final url = WebUri("https://race.netkeiba.com/top/race_list.html?kaisai_date=${DateFormat('yyyyMMdd').format(date)}");

    HeadlessInAppWebView? headlessWebView;

    final timer = Timer(const Duration(seconds: 20), () {
      if (!completer.isCompleted) {
        completer.completeError("Scraping timed out after 20 seconds for $url");
        headlessWebView?.dispose();
      }
    });

    headlessWebView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: url),
      initialSettings: InAppWebViewSettings(
        userAgent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/5.37.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/5.37.36",
        javaScriptEnabled: true,
        loadsImagesAutomatically: false,
        blockNetworkImage: true,
      ),
      onLoadStop: (controller, url) async {
        if (completer.isCompleted) return;
        try {
          final result = await controller.evaluateJavascript(source: """
            (function() {
              const raceBlocks = Array.from(document.querySelectorAll('dl.RaceList_DataList'));
              let allRacesData = [];
              raceBlocks.forEach(block => {
                const titleElement = block.querySelector('.RaceList_DataTitle');
                const title = titleElement ? titleElement.textContent.trim().replace(/\\s+/g, ' ') : '';
                const raceItems = Array.from(block.querySelectorAll('li.RaceList_DataItem'));
                raceItems.forEach(item => {
                  // ▼▼▼【修正点】'result.html'と'shutuba.html'の両方を検索対象にする ▼▼▼
                  const link = item.querySelector('a[href*="result.html"], a[href*="shutuba.html"]');
                  if (!link) return;

                  const gradeSpan = item.querySelector('span[class*="Icon_GradeType"]');
                  const mainTitleElement = document.querySelector('.RaceList_Date.Active .RaceList_DateText');
                  const mainTitle = mainTitleElement ? mainTitleElement.textContent.trim() : '';
                  const detailsElement = item.querySelector('.RaceList_ItemData');
                  allRacesData.push({
                    mainTitle: mainTitle,
                    title: title,
                    text: link.innerText.trim(),
                    href: link.href,
                    gradeTypeClass: gradeSpan ? gradeSpan.className : '',
                    details: detailsElement ? detailsElement.textContent.trim() : ''
                  });
                });
              });
              return JSON.stringify(allRacesData);
            })();
          """);

          if (result == null) {
            completer.complete(null);
            return;
          }
          final List<dynamic> scheduleData = json.decode(result);
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

  RaceSchedule? _parseScheduleData(List<dynamic> scheduleData, DateTime date) {
    if (scheduleData.isEmpty) {
      return null;
    }

    final firstItem = scheduleData.first;
    final dateString = firstItem['mainTitle'] as String;

    // mainTitleが空文字の場合があるため、曜日を自前で生成するフォールバックを追加
    final dayOfWeek = dateString.contains('(')
        ? dateString.substring(dateString.indexOf('(') + 1, dateString.indexOf(')'))
        : DateFormat.E('ja').format(date);

    final Map<String, List<SimpleRaceInfo>> venuesMap = {};
    final RegExp raceIdRegex = RegExp(r'race_id=([^&]+)');

    for (var item in scheduleData) {
      final venueTitle = item['title'] as String;
      final href = item['href'] as String;
      final text = item['text'] as String;

      final match = raceIdRegex.firstMatch(href);
      if (match == null) continue;
      final raceId = match.group(1)!;

      final textParts = text.split(RegExp(r'\\s+'));
      final raceNumber = textParts.isNotEmpty ? textParts.first : '';
      final raceName = textParts.length > 1 ? textParts.sublist(1).join(' ') : '';

      final raceInfo = SimpleRaceInfo(
          raceId: raceId,
          raceNumber: raceNumber,
          raceName: raceName,
          grade: _getGradeTypeText(item['gradeTypeClass']),
          details: item['details']
      );

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