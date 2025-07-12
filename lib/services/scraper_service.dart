// lib/services/scraper_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html;

class ScraperService {
  static Future<Map<String, dynamic>> scrapeRaceDetails(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final document = html.parse(response.body);
        final data = <String, dynamic>{};

        // 例: レース名を取得（実際のHTML構造に依存）
        final raceName = document.querySelector('.race_title')?.text ?? '不明';
        data['レース名'] = raceName;

        // 例: 出走馬名を取得（仮のセレクタ）
        final horses = document.querySelectorAll('.horse_name')?.map((e) => e.text).toList() ?? [];
        data['出走馬'] = horses;
        return data;
      } else {
        return {'エラー': 'HTTPリクエスト失敗: ${response.statusCode}'};
      }
    } catch (e) {
      return {'エラー': 'スクレイピングエラー: $e'};
    }
  }
}