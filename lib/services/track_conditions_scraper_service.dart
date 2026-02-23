// lib/services/track_conditions_scraper_service.dart

import 'package:flutter/foundation.dart'; // debugPrint用
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart' as dom;
import 'package:charset_converter/charset_converter.dart';
import '../models/track_conditions_model.dart';
import '../db/repositories/track_condition_repository.dart';
import '../db/repositories/race_repository.dart';
import '../models/race_schedule_model.dart';

/// スクレイピング中の一時データ保持用クラス
class _CourseMetadata {
  final String courseName;
  final int kai;
  final int nichi;
  final String blockId; // 例: 'rcA', 'rcB'

  _CourseMetadata(this.courseName, this.kai, this.nichi, this.blockId);
}

class _ParsedDateInfo {
  final DateTime date;
  final String dateStr;
  final String weekDayCode;

  _ParsedDateInfo(this.date, this.dateStr, this.weekDayCode);
}

class _TempScrapedData {
  _ParsedDateInfo? parsedDate;
  double? cushionValue;
  double? mTurfGoal;
  double? mTurf4c;
  double? mDirtGoal;
  double? mDirt4c;
}

/// JRAの馬場状態・含水率をスクレイピングし、SQLiteに自動保存するサービス
class TrackConditionsScraperService {
  static final Map<String, String> _courseCodes = {
    '札幌': '01', '函館': '02', '福島': '03', '新潟': '04', '東京': '05',
    '中山': '06', '中京': '07', '京都': '08', '阪神': '09', '小倉': '10',
  };

  /// JRAサイトから最新の馬場状態をフェッチし、DBに保存・更新します。
  /// UIを持たず、どこからでも `TrackConditionsScraperService.scrapeAndSave();` で呼び出せます。
  static Future<void> scrapeAndSave() async {
    debugPrint('=== [TrackConditionsScraperService] スクレイピング開始 ===');

    final headers = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36',
    };

    try {
      // ---------------------------------------------------------
      // Step 1: 開催場・開催回・日次・【ブロックID】の特定
      // ---------------------------------------------------------
      List<_CourseMetadata> courses = [];
      final pageUrls = [
        'https://www.jra.go.jp/keiba/baba/index.html',
        'https://www.jra.go.jp/keiba/baba/index2.html',
        'https://www.jra.go.jp/keiba/baba/index3.html',
        'https://www.jra.go.jp/keiba/baba/index4.html',
      ];

      for (String url in pageUrls) {
        try {
          final resp = await http.get(Uri.parse(url), headers: headers);
          if (resp.statusCode == 200) {
            String body = await CharsetConverter.decode("Shift_JIS", resp.bodyBytes);
            var doc = parser.parse(body);

            // <div id="baba" data-current-course="X"> からブロック文字を取得
            var babaDiv = doc.querySelector('#baba');
            if (babaDiv != null) {
              String? courseChar = babaDiv.attributes['data-current-course'];
              if (courseChar != null && courseChar.isNotEmpty) {
                String targetBlockId = 'rc$courseChar';

                String fullText = doc.body?.text ?? "";
                final bodyRegex = RegExp(r'第\s*(\d+)\s*回\s*(.+?)\s*競馬\s*第\s*(\d+)\s*日');
                final bodyMatch = bodyRegex.firstMatch(fullText);

                if (bodyMatch != null) {
                  int kai = int.parse(bodyMatch.group(1)!);
                  String courseName = bodyMatch.group(2)!.trim();
                  int nichi = int.parse(bodyMatch.group(3)!);

                  courses.add(_CourseMetadata(courseName, kai, nichi, targetBlockId));
                  debugPrint('特定: $courseName (第$kai回 第$nichi日) -> 抽出対象: [$targetBlockId]');
                }
              }
            }
          }
        } catch (e) {
          debugPrint('Skip $url: $e');
        }
      }

      if (courses.isEmpty) {
        debugPrint('開催情報が取得できませんでした。処理を中断します。');
        return;
      }

      Map<String, Map<String, _TempScrapedData>> mergedMap = {};
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // ---------------------------------------------------------
      // Step 2: クッション値の取得 (ブロックID抽出)
      // ---------------------------------------------------------
      debugPrint('--- クッション値取得開始 ---');
      final cUrl = Uri.parse('https://www.jra.go.jp/keiba/baba/_data_cushion.html?_=$timestamp');
      final cResp = await http.get(cUrl, headers: headers);
      if (cResp.statusCode == 200) {
        String cBody = await CharsetConverter.decode("Shift_JIS", cResp.bodyBytes);
        var doc = parser.parse(cBody);

        for (var course in courses) {
          var targetBlock = doc.getElementById(course.blockId);
          if (targetBlock != null) {
            _extractDataFromBlock(targetBlock, course.courseName, 1, (cName, pDate, vals) {
              mergedMap.putIfAbsent(cName, () => {});
              mergedMap[cName]!.putIfAbsent(pDate.dateStr, () => _TempScrapedData()..parsedDate = pDate);
              mergedMap[cName]![pDate.dateStr]!.cushionValue = vals[0];
            });
          }
        }
      }

      // ---------------------------------------------------------
      // Step 3: 含水率の取得 (ブロックID抽出)
      // ---------------------------------------------------------
      debugPrint('--- 含水率取得開始 ---');
      final mUrl = Uri.parse('https://www.jra.go.jp/keiba/baba/_data_moist.html?_=$timestamp');
      final mResp = await http.get(mUrl, headers: headers);
      if (mResp.statusCode == 200) {
        String mBody = await CharsetConverter.decode("Shift_JIS", mResp.bodyBytes);
        var doc = parser.parse(mBody);

        for (var course in courses) {
          var targetBlock = doc.getElementById(course.blockId);
          if (targetBlock != null) {
            _extractDataFromBlock(targetBlock, course.courseName, 4, (cName, pDate, vals) {
              mergedMap.putIfAbsent(cName, () => {});
              mergedMap[cName]!.putIfAbsent(pDate.dateStr, () => _TempScrapedData()..parsedDate = pDate);
              mergedMap[cName]![pDate.dateStr]!.mTurfGoal = vals[0];
              mergedMap[cName]![pDate.dateStr]!.mTurf4c = vals[1];
              mergedMap[cName]![pDate.dateStr]!.mDirtGoal = vals[2];
              mergedMap[cName]![pDate.dateStr]!.mDirt4c = vals[3];
            });
          }
        }
      }

      // ---------------------------------------------------------
      // Step 4: マージ結果からRecord生成とDB保存
      // ---------------------------------------------------------
      List<TrackConditionRecord> newRecords = [];
      final TrackConditionRepository _trackConditionRepo = TrackConditionRepository();
      final RaceRepository _raceRepo = RaceRepository();

      // 同じプレフィックス（同一競馬場の同一日など）でIDが重複しないよう、セッション内でNNを記憶
      Map<String, int> sessionNextIdMap = {};

      for (var course in courses) {
        var dateMap = mergedMap[course.courseName];
        if (dateMap == null) continue;

        // ★ 修正箇所: ここで日付の古い順（昇順）に並べ替えます
        var sortedDataList = dateMap.values.toList();
        sortedDataList.sort((a, b) {
          if (a.parsedDate == null || b.parsedDate == null) return 0;
          return a.parsedDate!.date.compareTo(b.parsedDate!.date);
        });

        // 並べ替えたリストをループ処理してIDを割り振る
        for (var data in sortedDataList) {
          if (data.parsedDate == null) continue;

          String dateStr = data.parsedDate!.dateStr;
          String courseCodeStr = _courseCodes[course.courseName] ?? '00';

          // 1. 差分チェック: 既にDBに同日・同競馬場のデータがあるか？
          List<TrackConditionRecord> existingRecords = await _trackConditionRepo.getTrackConditionsByDate(dateStr);
          bool alreadyExists = existingRecords.any((record) {
            String idStr = record.trackConditionId.toString();
            return idStr.length == 12 && idStr.substring(4, 6) == courseCodeStr;
          });

          if (alreadyExists) {
            debugPrint('DEBUG: $dateStr の ${course.courseName} は既に保存済みのためスキップします。');
            continue;
          }

          // 2. 新規データの場合、正しい DD（第〇日）を特定
          String yyyy = data.parsedDate!.date.year.toString();
          String cc = courseCodeStr;
          String kk = course.kai.toString().padLeft(2, '0');
          String dd = '00'; // 初期値

          if (data.parsedDate!.weekDayCode == 'fr') {
            dd = '00'; // 金曜は00固定
          } else {
            // 土日はカレンダーから raceId を取得して DD を抽出
            RaceSchedule? schedule = await _raceRepo.getRaceSchedule(dateStr);
            bool ddFound = false;
            if (schedule != null) {
              for (var venue in schedule.venues) {
                if (venue.venueTitle.contains(course.courseName) && venue.races.isNotEmpty) {
                  String raceId = venue.races.first.raceId;
                  if (raceId.length >= 10) {
                    dd = raceId.substring(8, 10);
                    ddFound = true;
                    break;
                  }
                }
              }
            }
            if (!ddFound) {
              // 万が一取得できない場合はページの数値をフォールバックとして使用
              dd = course.nichi.toString().padLeft(2, '0');
            }
          }

          // ★修正: 10桁ではなく、8桁(開催回ごと)のプレフィックスをキーにする
          String prefix8 = '$yyyy$cc$kk';

          // 3. DBの機能を使って高速に最新IDを取得
          int newId;
          if (!sessionNextIdMap.containsKey(prefix8)) {
            // 初回のみDBから最大値を取得して次のIDを生成
            newId = await _trackConditionRepo.generateNextTrackConditionId(prefix8, dd);
          } else {
            // 既にセッション内（同じ開催回）に存在する場合はNNをインクリメント
            int lastId = sessionNextIdMap[prefix8]!;
            int lastNn = lastId % 100;
            int nextNn = lastNn + 1;
            newId = int.parse('$prefix8$dd${nextNn.toString().padLeft(2, '0')}');
          }

          // 払い出した12桁の最新IDをマップに記録（次のループでNNを正しく+1するため）
          sessionNextIdMap[prefix8] = newId;

          TrackConditionRecord record = TrackConditionRecord(
            trackConditionId: newId,
            date: dateStr,
            weekDay: data.parsedDate!.weekDayCode,
            cushionValue: data.cushionValue,
            moistureTurfGoal: data.mTurfGoal,
            moistureTurf4c: data.mTurf4c,
            moistureDirtGoal: data.mDirtGoal,
            moistureDirt4c: data.mDirt4c,
          );

          newRecords.add(record);
        }
      }

      if (newRecords.isNotEmpty) {
        // SQLiteに一括保存（INSERT OR REPLACE なので重複エラーなし）
        await _trackConditionRepo.insertOrUpdateMultipleTrackConditions(newRecords);
        debugPrint('=== [TrackConditionsScraperService] 成功: ${newRecords.length}件のデータをDBに保存・更新しました ===');
      } else {
        debugPrint('=== [TrackConditionsScraperService] 完了: 新規・更新データはありませんでした ===');
      }

    } catch (e, stack) {
      debugPrint('=== [TrackConditionsScraperService] エラー発生: $e ===');
      debugPrint(stack.toString());
    }
  }

  // ---------------------------------------------------------
  // ヘルパー関数: 日付・曜日のパース
  // ---------------------------------------------------------
  static _ParsedDateInfo? _parseDateAndWeekday(String str) {
    try {
      final regex = RegExp(r'(\d+)月(\d+)日[（\(](.+?)曜[）\)]');
      final match = regex.firstMatch(str);
      if (match != null) {
        int month = int.parse(match.group(1)!);
        int day = int.parse(match.group(2)!);
        String jpWeekday = match.group(3)!;

        int year = DateTime.now().year;
        if (DateTime.now().month == 1 && month == 12) {
          year -= 1;
        }

        DateTime date = DateTime(year, month, day);
        String dateStr = "$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}";

        String wd = 'xx';
        if (jpWeekday.contains('月')) wd = 'mo';
        else if (jpWeekday.contains('火')) wd = 'tu';
        else if (jpWeekday.contains('we')) wd = 'we';
        else if (jpWeekday.contains('木')) wd = 'th';
        else if (jpWeekday.contains('金')) wd = 'fr';
        else if (jpWeekday.contains('土')) wd = 'sa';
        else if (jpWeekday.contains('日')) wd = 'su';

        return _ParsedDateInfo(date, dateStr, wd);
      }
    } catch (_) {}
    return null;
  }

  // ---------------------------------------------------------
  // ヘルパー関数: ブロック要素内からデータを抽出
  // ---------------------------------------------------------
  static void _extractDataFromBlock(
      dom.Element blockElement,
      String courseName,
      int expectedValueCount,
      void Function(String courseName, _ParsedDateInfo pDate, List<double> values) onExtracted
      ) {
    List<String> lines = blockElement.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i];

      if (line.contains('月') && line.contains('日')) {
        _ParsedDateInfo? pDate = _parseDateAndWeekday(line);
        if (pDate != null) {
          List<double> values = [];
          int offset = 1;
          while (values.length < expectedValueCount && (i + offset) < lines.length) {
            double? val = double.tryParse(lines[i + offset].trim());
            if (val != null) {
              values.add(val);
            } else {
              break;
            }
            offset++;
          }

          if (values.length == expectedValueCount) {
            onExtracted(courseName, pDate, values);
          }
          i += (offset - 1);
        }
      }
    }
  }

  /// 現在JRA公式サイトで公開されている（開催中の）競馬場名リストを取得します
  static Future<List<String>> getActiveCourseNames() async {
    List<String> activeCourses = [];
    final headers = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36',
    };

    final pageUrls = [
      'https://www.jra.go.jp/keiba/baba/index.html',
      'https://www.jra.go.jp/keiba/baba/index2.html',
      'https://www.jra.go.jp/keiba/baba/index3.html',
      'https://www.jra.go.jp/keiba/baba/index4.html',
    ];

    for (String url in pageUrls) {
      try {
        final resp = await http.get(Uri.parse(url), headers: headers);
        if (resp.statusCode == 200) {
          String body = await CharsetConverter.decode("Shift_JIS", resp.bodyBytes);
          var doc = parser.parse(body);

          String fullText = doc.body?.text ?? "";
          final bodyRegex = RegExp(r'第\s*\d+\s*回\s*(.+?)\s*競馬');
          final bodyMatch = bodyRegex.firstMatch(fullText);

          if (bodyMatch != null) {
            String courseName = bodyMatch.group(1)!.trim();
            if (!activeCourses.contains(courseName)) {
              activeCourses.add(courseName);
            }
          }
        }
      } catch (_) {}
    }
    return activeCourses;
  }
}