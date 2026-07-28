// lib/services/newspaper_scraper_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:hetaumakeiba_v2/utils/url_generator.dart';

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
          // [一時] 原因確認用ログ（後で削除可） (v.2026.7.28+26072803)
          debugPrint('[一時] NewspaperScrape raceId=$raceId dtCount=$dtCount marks=${marks.length}');
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