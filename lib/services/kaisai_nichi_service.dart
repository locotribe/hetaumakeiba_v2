// lib/services/kaisai_nichi_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// [追加] 馬場状態IDの日次(第N日)を決めるため、netkeiba の開催一覧から「競馬場コード→日次」を取得する (v.2026.10.6+26100603)
class KaisaiNichiService {
  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36',
  };

  /// 指定日（'YYYY-MM-DD'）の開催一覧を取得し、「競馬場コード(2桁) → 日次(2桁)」を返す。
  /// レースが無い日は空のMap。取得できなかった・開催一覧のページでなかったときは null。
  static Future<Map<String, String>?> fetchNichiByVenue(String dateStr) async {
    try {
      final kaisaiDate = dateStr.replaceAll('-', '');
      final resp = await http.get(
        Uri.parse('https://race.netkeiba.com/top/race_list_sub.html?kaisai_date=$kaisaiDate'),
        headers: _headers,
      );
      if (resp.statusCode != 200) return null;
      return parseNichiByVenue(utf8.decode(resp.bodyBytes, allowMalformed: true));
    } catch (e) {
      debugPrint('KaisaiNichiService fetchNichiByVenue Error ($dateStr): $e');
      return null;
    }
  }

  /// 開催一覧のHTMLからレースID(12桁)を拾い、「競馬場コード(5〜6桁目) → 日次(9〜10桁目)」を作る。
  /// 開催一覧のページであることを示す目印（race_list_sub）が無ければ null。
  static Map<String, String>? parseNichiByVenue(String html) {
    if (!html.contains('race_list_sub')) return null;
    final Map<String, String> result = {};
    for (final m in RegExp(r'race_id=(\d{12})').allMatches(html)) {
      final raceId = m.group(1)!;
      result.putIfAbsent(raceId.substring(4, 6), () => raceId.substring(8, 10));
    }
    return result;
  }
}
