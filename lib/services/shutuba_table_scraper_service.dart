import 'dart:async';
import 'dart:convert';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/models/shutuba_horse_detail_model.dart';
import 'package:hetaumakeiba_v2/utils/url_generator.dart';
import 'package:hetaumakeiba_v2/db/repositories/race_repository.dart';
import 'package:hetaumakeiba_v2/models/shutuba_table_cache_model.dart';

class ShutubaTableScraperService {
  final RaceRepository _raceRepo = RaceRepository();

  Future<PredictionRaceData> scrapeAllData(String raceId) async {
    final completer = Completer<PredictionRaceData>();
    final url = WebUri(generateShutubaUrl(raceId: raceId, type: 'shutuba'));
    HeadlessInAppWebView? headlessWebView;

    final timer = Timer(const Duration(seconds: 30), () {
      if (!completer.isCompleted) {
        completer.completeError(Exception("Scraping timed out for $raceId"));
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
      onLoadStop: (controller, url) async {
        if (completer.isCompleted) return;
        try {
          final result =
          await controller.evaluateJavascript(source: _getScrapingJs());
          if (result != null) {
            final data = _parseScrapedData(result, raceId);

            final cache = ShutubaTableCache(
              raceId: data.raceId,
              predictionRaceData: data,
              lastUpdatedAt: DateTime.now(),
            );
            await _raceRepo.insertOrUpdateShutubaTableCache(cache);

            completer.complete(data);
          } else {
            completer.completeError(
                Exception("Failed to get data from JavaScript for $raceId"));
          }
        } catch (e) {
          if (!completer.isCompleted) {
            completer.completeError(e);
          }
        }
      },
      onReceivedError: (controller, request, error) {
        // [修正] メインフレーム（ページ本体）のエラーのみをキャッチし、サブリソース（動画や広告など）のエラーは無視する (v.1.0)
        if (request.isForMainFrame == true) {
          if (!completer.isCompleted) {
            completer.completeError(
                Exception("Failed to load page: ${error.description}"));
          }
        }
      },
    );

    try {
      await headlessWebView.run();
      return await completer.future;
    } finally {
      timer.cancel();
      await headlessWebView.dispose();
    }
  }

  Future<List<ShutubaHorseDetail>> scrapeDynamicData(String raceId) async {
    final completer = Completer<List<ShutubaHorseDetail>>();
    final url = WebUri(generateShutubaUrl(raceId: raceId, type: 'shutuba'));
    HeadlessInAppWebView? headlessWebView;

    final timer = Timer(const Duration(seconds: 30), () {
      if (!completer.isCompleted) {
        completer.completeError(Exception("Scraping timed out for $raceId"));
        headlessWebView?.dispose();
      }
    });

    headlessWebView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(
        url: url,
        cachePolicy: URLRequestCachePolicy.RELOAD_IGNORING_LOCAL_CACHE_DATA, // ▼ 追加
      ),
      initialSettings: InAppWebViewSettings(
        userAgent:
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/5.37.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/5.37.36",
        javaScriptEnabled: true,
        loadsImagesAutomatically: false,
        blockNetworkImage: true,
      ),
      onLoadStop: (controller, url) async {
        if (completer.isCompleted) return;
        try {
          final result =
          await controller.evaluateJavascript(source: _getScrapingJs());
          if (result != null) {
            final data = _parseScrapedData(result, raceId);
            final horses = data.horses.map((h) {
              return ShutubaHorseDetail(
                horseId: h.horseId,
                horseNumber: h.horseNumber,
                gateNumber: h.gateNumber,
                horseName: h.horseName,
                sexAndAge: h.sexAndAge,
                jockey: h.jockey,
                jockeyId: h.jockeyId,
                carriedWeight: h.carriedWeight,
                trainerName: h.trainerName,
                trainerAffiliation: h.trainerAffiliation,
                odds: h.odds,
                popularity: h.popularity,
                horseWeight: h.horseWeight,
                isScratched: h.isScratched,
              );
            }).toList();
            completer.complete(horses);
          } else {
            completer.completeError(
                Exception("Failed to get data from JavaScript for $raceId"));
          }
        } catch (e) {
          if (!completer.isCompleted) {
            completer.completeError(e);
          }
        }
      },
      onReceivedError: (controller, request, error) {
        // [修正] メインフレーム（ページ本体）のエラーのみをキャッチし、サブリソース（動画や広告など）のエラーは無視する (v.1.0)
        if (request.isForMainFrame == true) {
          if (!completer.isCompleted) {
            completer.completeError(
                Exception("Failed to load page: ${error.description}"));
          }
        }
      },
    );

    try {
      await headlessWebView.run();
      return await completer.future;
    } finally {
      timer.cancel();
      await headlessWebView.dispose();
    }
  }

  PredictionRaceData _parseScrapedData(dynamic result, String raceId) {
    final Map<String, dynamic> jsonData = jsonDecode(result);

    final String raceName = jsonData["raceName"] ?? "";
    final String raceGrade =
    _getGradeTypeText(jsonData["raceGradeClass"] ?? "");
    final String raceData01 = jsonData["raceData01"] ?? "";
    final String raceData02 = jsonData["raceData02"] ?? "";
    final List<dynamic> horsesData = jsonData["horses"] ?? [];

    String raceDate = jsonData["raceDate"] ?? "";
    String venue = '';
    String raceNumber = '';

    // ▼▼ 新規追加: 16項目の環境データ用変数 ▼▼
    String? trackType;
    int? distanceValue;
    String? direction;
    String courseInOut = '';
    String? weather;
    String? trackCondition;
    int? holdingTimes;
    int? holdingDays;
    String? raceCategory;
    int? horseCount;
    String? startTime;
    int basePrize1st = 0;
    int basePrize2nd = 0;
    int basePrize3rd = 0;
    int basePrize4th = 0;
    int basePrize5th = 0;
    // ▲▲ 新規追加 ▲▲

    // ▼▼ raceData01 の解析 ("15:45発走 / 芝2000m (右 A) / 天候:晴 / 馬場:良" など) ▼▼
    final timeMatch = RegExp(r'(\d{2}:\d{2})発走').firstMatch(raceData01);
    if (timeMatch != null) startTime = timeMatch.group(1);

    final trackDistMatch = RegExp(r'(芝|ダ|障)(\d+)m').firstMatch(raceData01);
    if (trackDistMatch != null) {
      trackType = trackDistMatch.group(1);
      distanceValue = int.tryParse(trackDistMatch.group(2)!);
    }

    final dirMatch = RegExp(r'\((右|左|直)(?:\s+([^)]+))?\)').firstMatch(raceData01);
    if (dirMatch != null) {
      direction = dirMatch.group(1);
      if (dirMatch.group(2) != null) courseInOut = dirMatch.group(2)!.trim();
    }

    final weatherMatch = RegExp(r'天候:(\S+)').firstMatch(raceData01);
    if (weatherMatch != null) weather = weatherMatch.group(1);

    final condMatch = RegExp(r'馬場:(\S+)').firstMatch(raceData01);
    if (condMatch != null) trackCondition = condMatch.group(1);

    // ▼▼ raceData02 の解析 ("2回 中山 4日目 サラ系３歳 オープン (国際)(指) 馬齢 10頭\n本賞金:5400,2200,1400,810,540万円" など) ▼▼
    final holdingTimesMatch = RegExp(r'(\d+)回').firstMatch(raceData02);
    if (holdingTimesMatch != null) holdingTimes = int.tryParse(holdingTimesMatch.group(1)!);

    // 会場(venue)の抽出: "2回 中山 4日目" から "中山" を取り出す
    final venueMatch = RegExp(r'\d+回\s+(.+?)\s+\d+日目').firstMatch(raceData02);
    if (venueMatch != null) {
      venue = venueMatch.group(1)!.trim();
    }

    final holdingDaysMatch = RegExp(r'(\d+)日目').firstMatch(raceData02);
    if (holdingDaysMatch != null) holdingDays = int.tryParse(holdingDaysMatch.group(1)!);

    final categoryMatch = RegExp(r'日目\s+(.+?)\s+\d+頭').firstMatch(raceData02);
    if (categoryMatch != null) raceCategory = categoryMatch.group(1)!.trim();

    final horseCountMatch = RegExp(r'(\d+)頭').firstMatch(raceData02);
    if (horseCountMatch != null) horseCount = int.tryParse(horseCountMatch.group(1)!);

    final prizeMatch = RegExp(r'本賞金:?([0-9,]+)').firstMatch(raceData02);
    if (prizeMatch != null) {
      final prizes = prizeMatch.group(1)!.split(',');
      if (prizes.isNotEmpty) basePrize1st = int.tryParse(prizes[0]) ?? 0;
      if (prizes.length > 1) basePrize2nd = int.tryParse(prizes[1]) ?? 0;
      if (prizes.length > 2) basePrize3rd = int.tryParse(prizes[2]) ?? 0;
      if (prizes.length > 3) basePrize4th = int.tryParse(prizes[3]) ?? 0;
      if (prizes.length > 4) basePrize5th = int.tryParse(prizes[4]) ?? 0;
    }

    // ▼▼ レース番号の確実な抽出 (文字列になければ raceId の末尾2桁から取得) ▼▼
    final rnMatch = RegExp(r'(\d{1,2})R').firstMatch('$raceData01 $raceData02');
    if (rnMatch != null) {
      raceNumber = rnMatch.group(1)!;
    } else {
      if (raceId.length >= 2) {
        raceNumber = int.tryParse(raceId.substring(raceId.length - 2))?.toString() ?? '';
      }
    }

    // ▼▼ 既存の馬リスト生成ロジック (変更なし) ▼▼
    final List<PredictionHorseDetail> horses = horsesData.map((horseData) {
      final Map<String, dynamic> horseMap =
      Map<String, dynamic>.from(horseData);
      final trainerText = horseMap['厩舎'] ?? '';
      String trainerAffiliation = '';
      String trainerName = trainerText;

      if (trainerText.startsWith('美浦')) {
        trainerAffiliation = '美浦';
        trainerName = trainerText.substring(2);
      } else if (trainerText.startsWith('栗東')) {
        trainerAffiliation = '栗東';
        trainerName = trainerText.substring(2);
      }
      return PredictionHorseDetail(
        horseId: horseMap['馬ID'] ?? '',
        horseNumber: int.tryParse(horseMap['馬番'] ?? '0') ?? 0,
        gateNumber: int.tryParse(horseMap['枠'] ?? '0') ?? 0,
        horseName: horseMap['馬名'] ?? '',
        sexAndAge: horseMap['性齢'] ?? '',
        jockey: horseMap['騎手'] ?? '',
        jockeyId: horseMap['騎手ID'] ?? '',
        carriedWeight: double.tryParse(horseMap['斤量'] ?? '0.0') ?? 0.0,
        trainerName: trainerName,
        trainerAffiliation: trainerAffiliation,
        odds: double.tryParse(horseMap['オッズ'] ?? ''),
        popularity: int.tryParse(horseMap['人気'] ?? ''),
        horseWeight: horseMap['馬体重'] ?? '',
        isScratched: (horseMap['印'] ?? '') == '取消',
      );
    }).toList();

    return PredictionRaceData(
      raceId: raceId,
      raceName: raceName,
      raceDate: raceDate,
      venue: venue,
      raceNumber: raceNumber,
      shutubaTableUrl: generateShutubaUrl(raceId: raceId, type: 'shutuba'),
      raceGrade: raceGrade,
      raceDetails1: '$raceData01 / $raceData02', // 既存の互換性維持
      horses: horses,
      // ▼▼ 新規追加: 抽出した16項目の環境データをセット ▼▼
      trackType: trackType,
      distanceValue: distanceValue,
      direction: direction,
      courseInOut: courseInOut,
      weather: weather,
      trackCondition: trackCondition,
      holdingTimes: holdingTimes,
      holdingDays: holdingDays,
      raceCategory: raceCategory,
      horseCount: horseCount,
      startTime: startTime,
      basePrize1st: basePrize1st,
      basePrize2nd: basePrize2nd,
      basePrize3rd: basePrize3rd,
      basePrize4th: basePrize4th,
      basePrize5th: basePrize5th,
      // ▲▲ 新規追加 ▲▲
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

  String _getScrapingJs() {
    return r'''
      (() => {
        const result = {};
        
        // titleタグから日付情報を正規表現で抽出
        const titleText = document.querySelector('title').innerText;
        const dateMatch = titleText.match(/(\d{4}年\d{1,2}月\d{1,2}日)/);
        result.raceDate = dateMatch ? dateMatch[1] : '';

        // レース名
        const nameElem = document.querySelector("h1.RaceName");
        result.raceName = nameElem ? nameElem.innerText.trim() : "";

        // グレードのクラス名を取得（テキストではなく className）
        const gradeElem = document.querySelector("span.Icon_GradeType");
        result.raceGradeClass = gradeElem ? gradeElem.className : "";

        // レース詳細情報
        const data01Elem = document.querySelector("div.RaceData01");
        result.raceData01 = data01Elem ? data01Elem.innerText.trim().replace(/\s+/g, " ") : "";

        // 発走時刻など追加情報
        const data02Elem = document.querySelector("div.RaceData02");
        result.raceData02 = data02Elem ? data02Elem.innerText.trim().replace(/\s+/g, " ") : "";

        // 出馬表データ
        const rows = document.querySelectorAll("table.Shutuba_Table tbody tr");
        let horses = [];
        rows.forEach(row => {
          const tds = row.querySelectorAll("td");
          if (tds.length < 11) return;

          const nameAnchor = tds[3]?.querySelector("a");
          const horseUrl = nameAnchor ? nameAnchor.href.trim() : "";
          let horseId = "";

          const match = horseUrl.match(/\/horse\/(\d{10})/);
          if (match) {
            horseId = match[1];
          }
          const jockeyAnchor = tds[6]?.querySelector("a");
          const jockeyUrl = jockeyAnchor ? jockeyAnchor.href.trim() : "";
          let jockeyId = "";
          const jockeyMatch = jockeyUrl.match(/\/jockey\/result\/recent\/(\d{5})/);
          if (jockeyMatch) {
            jockeyId = jockeyMatch[1];
            }

          horses.push({
            "枠": tds[0]?.innerText.trim() || "",
            "馬番": tds[1]?.innerText.trim() || "",
            "印": tds[2]?.innerText.includes("取消") ? "取消" : "",
            "馬名": nameAnchor ? nameAnchor.innerText.trim() : "",
            "馬ID": horseId,
            "性齢": tds[4]?.innerText.trim() || "",
            "斤量": tds[5]?.innerText.trim() || "",
            "騎手": tds[6]?.querySelector("a")?.innerText.trim() || "",
            "騎手ID": jockeyId,
            "厩舎": tds[7]?.innerText.trim() || "",
            "馬体重": tds[8]?.innerText.trim() || "",
            "オッズ": tds[9]?.innerText.trim() || "",
            "人気": tds[10]?.innerText.trim() || ""
          });
        });

        result.horses = horses;
        return JSON.stringify(result);
      })();
    ''';
  }
}