import 'dart:async';
import 'dart:convert';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_race_data.dart';
import 'package:hetaumakeiba_v2/models/shutuba_horse_detail_model.dart';
import 'package:hetaumakeiba_v2/utils/url_generator.dart';

class ShutubaTableScraperService {
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
        if (!completer.isCompleted) {
          completer.completeError(
              Exception("Failed to load page: ${error.description}"));
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
        if (!completer.isCompleted) {
          completer.completeError(
              Exception("Failed to load page: ${error.description}"));
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

    String raceDate = '';
    String venue = '';
    String raceNumber = '';

    final raceData01Match =
        RegExp(r'(\d{4}年\d{1,2}月\d{1,2}日)\s*(.*?)\s*(\d{1,2}R)')
            .firstMatch(raceData01);
    if (raceData01Match != null) {
      raceDate = raceData01Match.group(1) ?? '';
      venue = raceData01Match.group(2) ?? '';
      raceNumber = raceData01Match.group(3) ?? '';
    }

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
      raceNumber: raceNumber.replaceAll('R', ''),
      shutubaTableUrl: generateShutubaUrl(raceId: raceId, type: 'shutuba'),
      raceGrade: raceGrade,
      raceDetails1: '$raceData01 / $raceData02',
      horses: horses,
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
