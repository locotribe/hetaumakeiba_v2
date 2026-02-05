// lib/services/race_result_first_scraper_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/logic/combination_calculator.dart';
import 'package:hetaumakeiba_v2/repositories/race_data_repository.dart';

/// netkeiba.comの当日のレース結果ページ（JavaScript動的生成）を
/// InAppWebViewを使用してスクレイピングすることに特化したサービスクラスです。
class RaceResultFirstScraperService {
  static const String _scrapeJs = r'''
(function(){
  function textOrEmpty(el){ return el ? el.innerText.trim() : ''; }
  var res = {};
  res.raceName = textOrEmpty(document.querySelector('.RaceName'));
  res.raceData01 = textOrEmpty(document.querySelector('.RaceData01'));
  res.raceData02 = textOrEmpty(document.querySelector('.RaceData02'));

  res.horses = [];
  var rows = document.querySelectorAll('#All_Result_Table tbody tr');
  rows.forEach(function(tr){
    if(!tr) return;
    var tds = tr.querySelectorAll('td');
    if(tds.length < 15) return;
    var horse = {};
    horse.rank = textOrEmpty(tds[0]);
    horse.waku = textOrEmpty(tds[1]);
    horse.number = textOrEmpty(tds[2]);
    horse.name = textOrEmpty(tds[3]?.querySelector('.Horse_Name a')) || textOrEmpty(tds[3]);
    horse.horse_id = tds[3]?.querySelector('.Horse_Name a')?.href.split('/horse/')[1] || '';
    horse.sex_age = textOrEmpty(tds[4]);
    horse.kilo = textOrEmpty(tds[5]);
    
    const jockeyAnchor = tds[6]?.querySelector('a');
    horse.jockey = textOrEmpty(jockeyAnchor);
    const jockeyHref = jockeyAnchor ? jockeyAnchor.href : '';
    const jockeyMatch = jockeyHref.match(/\/jockey\/result\/recent\/(\d{5})\//);
    horse.jockey_id = jockeyMatch ? jockeyMatch[1] : '';

    horse.time = textOrEmpty(tds[7]);
    horse.margin = textOrEmpty(tds[8]);
    horse.popularity = textOrEmpty(tds[9]);
    horse.odds = textOrEmpty(tds[10]);
    horse.last3f = textOrEmpty(tds[11]);
    horse.corner = textOrEmpty(tds[12]);
    horse.trainer = textOrEmpty(tds[13]);
    horse.weight = textOrEmpty(tds[14]);
    res.horses.push(horse);
  });

  res.payouts = [];
  var payoutTables = document.querySelectorAll('.Payout_Detail_Table');
  payoutTables.forEach(function(tbl){
    var tb = {};
    tb.rows = [];
    var trs = tbl.querySelectorAll('tbody tr');
    trs.forEach(function(r){
      var row = {};
      var th = r.querySelector('th');
      var kind = th ? th.innerText.trim() : '';
      row.kind = kind;

      var resultTd = r.querySelector('td.Result');
      var resultItems = [];
      if(resultTd) {
          var divs = resultTd.querySelectorAll('div');
          if (divs.length > 0 && divs[0].innerText.trim()) {
              divs.forEach(function(d) { var v = d.innerText.trim(); if(v) resultItems.push(v); });
          } else {
              var uls = resultTd.querySelectorAll('ul');
              if (uls.length > 0) {
                  uls.forEach(function(ul) {
                      var combo = [];
                      ul.querySelectorAll('li span').forEach(function(span) {
                          var v = span.innerText.trim(); if(v) combo.push(v);
                      });
                      if (combo.length > 0) {
                          var separator = (kind === '馬単' || kind === '3連単') ? '→' : ' - ';
                          resultItems.push(combo.join(separator));
                      }
                  });
              } else {
                  var simpleText = resultTd.innerText.trim();
                  if(simpleText) resultItems.push(simpleText.replace(/\s*→\s*/g, '→'));
              }
          }
      }
      row.result = resultItems;

      var payoutTd = r.querySelector('td.Payout');
      row.payout = payoutTd ? payoutTd.innerHTML.split('<br>').map(s => s.replace(/<[^>]*>/g, '').trim()) : [];

      var ninkiTd = r.querySelector('td.Ninki');
      row.popularities = ninkiTd ? Array.from(ninkiTd.querySelectorAll('span')).map(function(s){ return s.innerText.trim(); }) : [];
      tb.rows.push(row);
    });
    res.payouts.push(tb);
  });
  res.corners = [];
  var cornerRows = document.querySelectorAll('.Corner_Num tbody tr');
  cornerRows.forEach(function(r){
    var th = r.querySelector('th');
    var td = r.querySelector('td');
    if(th && td){
      res.corners.push({corner: th.innerText.trim(), order: td.innerText.trim()});
    }
  });
  return JSON.stringify(res);
})();
''';

  /// URLからレースIDを抽出するヘルパー関数
  static String? getRaceIdFromUrl(String url) {
    return Uri.parse(url).queryParameters['race_id'];
  }

  /// netkeiba.comの当日のレース結果ページをスクレイピングし、RaceResultオブジェクトを返す
  static Future<RaceResult> scrapeRaceDetails(String url) async {
    final completer = Completer<RaceResult>();
    final raceId = getRaceIdFromUrl(url);
    if (raceId == null) {
      throw Exception('無効なURLです: レースIDが取得できませんでした。');
    }

    HeadlessInAppWebView? headlessWebView;

    final timer = Timer(const Duration(seconds: 30), () {
      if (!completer.isCompleted) {
        completer.completeError(Exception("Scraping timed out for $raceId"));
        headlessWebView?.dispose();
      }
    });

    headlessWebView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(url)),
      initialSettings: InAppWebViewSettings(
        userAgent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/5.37.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/5.37.36",
        javaScriptEnabled: true,
      ),
      onLoadStop: (controller, uri) async {
        if (completer.isCompleted) return;
        try {
          final result = await controller.evaluateJavascript(source: _scrapeJs);
          if (result != null) {
            final data = _parseScrapedData(result, raceId);

            // ★修正: データを完了させる前にRepository経由で保存する
            // これにより、速報データ取得時も自動的にDBへ保存・更新が試みられる
            await RaceDataRepository().saveRaceResult(data);

            completer.complete(data);
          } else {
            completer.completeError(Exception("Failed to get data from JavaScript for $raceId"));
          }
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
      await headlessWebView.run();
      return await completer.future;
    } finally {
      timer.cancel();
      await headlessWebView.dispose();
    }
  }

  /// スクレイピングで取得したJSONデータをRaceResultモデルに変換する
  static RaceResult _parseScrapedData(dynamic result, String raceId) {
    final Map<String, dynamic> data = jsonDecode(result);

    final raceData01 = data['raceData01'] as String? ?? '';
    final raceData02 = data['raceData02'] as String? ?? '';
    final dateMatch = RegExp(r'(\d{4}年\d{1,2}月\d{1,2}日)').firstMatch(raceData01);

    return RaceResult(
      raceId: raceId,
      raceTitle: data['raceName'] ?? '',
      raceInfo: raceData01.replaceAll(RegExp(r'\s+'), ' '),
      raceDate: dateMatch?.group(1) ?? '',
      raceGrade: raceData02.replaceAll(RegExp(r'\s+'), ' '),
      horseResults: _parseHorseResults(data['horses'] as List<dynamic>? ?? []),
      refunds: _parseRefunds(data['payouts'] as List<dynamic>? ?? []),
      cornerPassages: _parseCornerPassages(data['corners'] as List<dynamic>? ?? []),
      lapTimes: [], // 当日ページからはラップタイムは取得しない
    );
  }

  /// 競走馬の結果リストを解析する
  static List<HorseResult> _parseHorseResults(List<dynamic> horsesData) {
    return horsesData.map((horse) {
      final trainerText = horse['trainer'] ?? '';
      String trainerAffiliation = '';
      String trainerName = trainerText;

      if (trainerText.startsWith('美浦')) {
        trainerAffiliation = '美浦';
        trainerName = trainerText.substring(2);
      } else if (trainerText.startsWith('栗東')) {
        trainerAffiliation = '栗東';
        trainerName = trainerText.substring(2);
      }

      return HorseResult(
        rank: horse['rank'] ?? '',
        frameNumber: horse['waku'] ?? '',
        horseNumber: horse['number'] ?? '',
        horseName: horse['name'] ?? '',
        horseId: horse['horse_id'] ?? '',
        sexAndAge: horse['sex_age'] ?? '',
        weightCarried: horse['kilo'] ?? '',
        jockeyName: horse['jockey'] ?? '',
        jockeyId: horse['jockey_id'] ?? '',
        time: horse['time'] ?? '',
        margin: horse['margin'] ?? '',
        cornerRanking: horse['corner'] ?? '',
        agari: horse['last3f'] ?? '',
        odds: horse['odds'] ?? '',
        popularity: horse['popularity'] ?? '',
        horseWeight: horse['weight'] ?? '',
        trainerName: trainerName,
        trainerAffiliation: trainerAffiliation,
        ownerName: '', // 当日ページからは取得不可
        prizeMoney: '', // 当日ページからは取得不可
      );
    }).toList();
  }

  /// 払戻金情報を解析する
  static List<Refund> _parseRefunds(List<dynamic> payoutsData) {
    final List<Refund> refundList = [];
    for (final table in payoutsData) {
      final rows = table['rows'] as List<dynamic>? ?? [];
      for (final rowData in rows) {
        final row = rowData as Map<String, dynamic>;
        String ticketTypeName = row['kind'] ?? '';
        if (ticketTypeName == '三連複') ticketTypeName = '3連複';
        if (ticketTypeName == '三連単') ticketTypeName = '3連単';

        final ticketTypeId = bettingDict.entries
            .firstWhere((e) => e.value == ticketTypeName, orElse: () => const MapEntry('', ''))
            .key;

        if (ticketTypeId.isEmpty) continue;

        final combinations = row['result'] as List<dynamic>? ?? [];

        final amounts = (row['payout'] as List<dynamic>? ?? [])
            .map((s) => s.toString().replaceAll(RegExp(r'[円,]'), '').trim())
            .toList();

        final popularities = (row['popularities'] as List<dynamic>? ?? [])
            .map((p) => p.toString().replaceAll('人気', '').trim())
            .toList();

        final payouts = <Payout>[];

        for (int i = 0; i < combinations.length; i++) {
          final combinationStr = combinations[i] as String;
          final combinationNumbers = RegExp(r'\d+')
              .allMatches(combinationStr)
              .map((m) => int.parse(m.group(0)!))
              .toList();

          if (['馬連', 'ワイド', '3連複', '枠連'].contains(ticketTypeName)) {
            combinationNumbers.sort();
          }

          payouts.add(Payout(
            combination: combinationStr,
            amount: i < amounts.length ? amounts[i] : '',
            popularity: i < popularities.length ? popularities[i] : '',
            combinationNumbers: combinationNumbers,
          ));
        }
        refundList.add(Refund(ticketTypeId: ticketTypeId, payouts: payouts));
      }
    }
    return refundList;
  }

  /// コーナー通過順位を解析する
  static List<String> _parseCornerPassages(List<dynamic> cornersData) {
    return cornersData.map((corner) {
      return '${corner['corner']}: ${corner['order']}';
    }).toList();
  }
}