// lib/services/newspaper_scraper_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:hetaumakeiba_v2/utils/url_generator.dart';
// [追加] 成績タブ拡充: 過去走欄の保存用 (v.2026.9.22+26092202)
import 'package:flutter/foundation.dart';
import 'package:hetaumakeiba_v2/db/repositories/horse_past_race_extra_repository.dart';
import 'package:hetaumakeiba_v2/models/horse_past_race_extra_model.dart';

/// 競馬新聞ページから取得した各馬のマーク情報（ブリンカー/外国産/地方）を保持します。
class HorseNewspaperMarks {
  final bool isBlinker;
  final bool isFirstBlinker;
  final bool isMaruGai;
  final bool isMaruChi;
  const HorseNewspaperMarks({
    this.isBlinker = false,
    this.isFirstBlinker = false,
    this.isMaruGai = false,
    this.isMaruChi = false,
  });
}

class NewspaperScraperService {
  Future<Map<String, HorseNewspaperMarks>> scrapeMarks(String raceId) async {
    final completer = Completer<Map<String, HorseNewspaperMarks>>();
    final url = WebUri(generateNewspaperUrl(raceId: raceId));
    HeadlessInAppWebView? headlessWebView;

    final timer = Timer(const Duration(seconds: 30), () {
      if (!completer.isCompleted) {
        completer.complete(<String, HorseNewspaperMarks>{});
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
          // [一時] dt.Horse02 が描画されるまで待機（JSレンダリング対策） (v.2026.7.28+26072803)
          int dtCount = 0;
          for (int i = 0; i < 16; i++) {
            final c = await controller.evaluateJavascript(
                source: "document.querySelectorAll('dt.Horse02').length");
            dtCount = (c is int) ? c : int.tryParse('$c') ?? 0;
            if (dtCount > 0) break;
            await Future.delayed(const Duration(milliseconds: 500));
            if (completer.isCompleted) return;
          }
          final result =
          await controller.evaluateJavascript(source: _getScrapingJs());
          final marks = _parseMarks(result);
          // [追加] 成績タブ拡充: 同じページの過去5走欄を読み取り、過去走の追加情報として保存する。
          // 失敗してもマーク取得には影響させない（ベストエフォート） (v.2026.9.22+26092202)
          try {
            // [追加] 過去走欄（li.Past）が描画されるまで最大5秒待つ。新馬戦など過去走が無い場合は待機後そのまま進む (v.2026.9.22+26092204)
            for (int i = 0; i < 10; i++) {
              final c = await controller.evaluateJavascript(
                  source: "document.querySelectorAll('dd.Past_Wrapper li.Past').length");
              final pastCount = (c is int) ? c : int.tryParse('$c') ?? 0;
              if (pastCount > 0) break;
              await Future.delayed(const Duration(milliseconds: 500));
              if (completer.isCompleted) return;
            }
            final pastResult =
            await controller.evaluateJavascript(source: _getPastRacesJs());
            final extras = _parsePastRaces(pastResult);
            if (extras.isNotEmpty) {
              await HorsePastRaceExtraRepository().upsertMerge(extras);
            }
            debugPrint('NewspaperScraperService: saved ${extras.length} past race extras for $raceId');
          } catch (e) {
            debugPrint('NewspaperScraperService: past race extras failed for $raceId: $e');
          }
          if (!completer.isCompleted) completer.complete(marks);
        } catch (e) {
          if (!completer.isCompleted) {
            completer.complete(<String, HorseNewspaperMarks>{});
          }
        }
      },
      onReceivedError: (controller, request, error) {
        if (request.isForMainFrame == true) {
          if (!completer.isCompleted) {
            completer.complete(<String, HorseNewspaperMarks>{});
          }
        }
      },
    );

    try {
      await headlessWebView.run();
      return await completer.future;
    } catch (e) {
      return <String, HorseNewspaperMarks>{};
    } finally {
      timer.cancel();
      await headlessWebView.dispose();
    }
  }

  Map<String, HorseNewspaperMarks> _parseMarks(dynamic result) {
    try {
      if (result == null) return <String, HorseNewspaperMarks>{};
      final List<dynamic> rows = jsonDecode(result);
      final Map<String, HorseNewspaperMarks> marks = {};
      for (final row in rows) {
        final Map<String, dynamic> r = Map<String, dynamic>.from(row);
        final String horseId = r['horseId'] ?? '';
        if (horseId.isEmpty) continue;
        marks[horseId] = HorseNewspaperMarks(
          isBlinker: r['isBlinker'] == true,
          isFirstBlinker: r['isFirstBlinker'] == true,
          isMaruGai: r['isMaruGai'] == true,
          isMaruChi: r['isMaruChi'] == true,
        );
      }
      return marks;
    } catch (e) {
      return <String, HorseNewspaperMarks>{};
    }
  }

  // [追加] 成績タブ拡充: 過去5走欄の解析 (v.2026.9.22+26092202)
  List<HorsePastRaceExtra> _parsePastRaces(dynamic result) {
    if (result == null) return <HorsePastRaceExtra>[];
    final List<dynamic> rows = jsonDecode(result);
    final fetchedAt = DateTime.now().toIso8601String();
    final List<HorsePastRaceExtra> extras = [];
    for (final row in rows) {
      final Map<String, dynamic> r = Map<String, dynamic>.from(row);
      final String horseId = (r['horseId'] ?? '').toString();
      final String raceId = (r['raceId'] ?? '').toString();
      if (horseId.isEmpty || raceId.isEmpty) continue;

      final corners = (r['corners'] as List<dynamic>? ?? [])
          .map((c) => PastRaceCorner(
                position: (c['pos'] ?? '').toString().trim(),
                note: (c['note'] ?? '').toString().trim(),
              ))
          .where((c) => c.position.isNotEmpty)
          .toList();

      final first3fText = HorsePastRaceExtra.normalizeScrapedText(r['first3f']);

      extras.add(HorsePastRaceExtra(
        horseId: horseId,
        raceId: raceId,
        raceCondition: HorsePastRaceExtra.normalizeScrapedText(r['raceCondition']),
        courseSection: HorsePastRaceExtra.normalizeScrapedText(r['courseSection']),
        paceMark: HorsePastRaceExtra.normalizeScrapedText(r['paceMark']),
        corners: corners.isEmpty ? null : corners,
        agariRank: int.tryParse('${r['agariRank']}'),
        isRecord: r['isRecord'] == true,
        isBlinker: r['isBlinker'] == true,
        winnerHorseId: HorsePastRaceExtra.normalizeScrapedText(r['winnerHorseId']),
        individualFirst3f: first3fText == null ? null : double.tryParse(first3fText),
        shortComment: HorsePastRaceExtra.normalizeScrapedText(r['shortComment']),
        newspaperFetchedAt: fetchedAt,
      ));
    }
    return extras;
  }

  // [追加] 成績タブ拡充: 競馬新聞ページの過去5走欄（dd.Past_Wrapper li.Past）を読み取るJS。
  // DOM構造は設計書 §1-2 のとおり（2026-09-22 実測） (v.2026.9.22+26092202)
  String _getPastRacesJs() {
    return r'''
      (() => {
        const out = [];
        document.querySelectorAll('dl.HorseList').forEach(dl => {
          const ha = dl.querySelector('dt.Horse02 a[href*="/horse/"]');
          const hm = ha && ha.href.match(/\/horse\/(\d{10})/);
          if (!hm) return;
          const horseId = hm[1];
          dl.querySelectorAll('dd.Past_Wrapper li.Past').forEach(li => {
            const box = li.querySelector('.PastBox');
            if (!box) return;
            const ra = box.querySelector('.RaceName a');
            const rm = ra && ra.href.match(/\/race\/(\d{12})/);
            if (!rm) return;
            const txt = sel => {
              const e = box.querySelector(sel);
              return e ? e.innerText.replace(/\s+/g, ' ').trim() : '';
            };
            const f = box.querySelector('.Data19');
            const first3f = (!f || f.querySelector('.Pass_Txt01'))
              ? '' : f.innerText.replace('前', '').trim();
            const corners = [...box.querySelectorAll('.Data20 .Corner')].map(c => {
              const n = c.querySelector('span');
              return {
                pos: c.firstChild ? c.firstChild.textContent.trim() : '',
                note: n ? n.textContent.trim() : ''
              };
            });
            const r21 = box.querySelector('.Data21');
            const rk = r21 && r21.className.match(/RankData_(\d+)/);
            const w = box.querySelector('.Data22 a');
            const wm = w && w.href.match(/\/horse\/(\d{10})/);
            out.push({
              horseId: horseId,
              raceId: rm[1],
              raceCondition: txt('.Data03'),
              courseSection: txt('.Data10'),
              paceMark: txt('.Data13'),
              corners: corners,
              agariRank: rk ? parseInt(rk[1], 10) : null,
              isRecord: !!box.querySelector('.Data12.Record'),
              isBlinker: !!box.querySelector('.PastDataLine .Mark'),
              winnerHorseId: wm ? wm[1] : '',
              first3f: first3f,
              shortComment: txt('.Data24')
            });
          });
        });
        return JSON.stringify(out);
      })()
    ''';
  }

  String _getScrapingJs() {
    return r'''
      (() => {
        const dts = [...document.querySelectorAll('dt.Horse02')];
        const rows = dts.map(dt => {
          const a = dt.querySelector('a[href*="/horse/"]');
          const m = a && a.href.match(/\/horse\/(\d{10})/);
          const mark = dt.querySelector('span.Mark');
          return {
            horseId: m ? m[1] : '',
            isBlinker: !!mark,
            isFirstBlinker: !!(mark && /First/.test(mark.className)),
            isMaruGai: !!dt.querySelector('.Icon_MaruGai'),
            isMaruChi: !!dt.querySelector('.Icon_MaruChi')
          };
        }).filter(r => r.horseId);
        return JSON.stringify(rows);
      })()
    ''';
  }
}