// lib/services/cloud_sync_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hetaumakeiba_v2/db/repositories/track_condition_repository.dart';

class CloudSyncService {
  static const String CLOUD_VERSION_URL = 'https://raw.githubusercontent.com/locotribe/keiba-track-conditions/main/version.json';
  static const String CLOUD_CSV_URL = 'https://raw.githubusercontent.com/locotribe/keiba-track-conditions/main/track_conditions.csv';

  final TrackConditionRepository _repository = TrackConditionRepository();

  /// クラウドのバージョン情報を取得し、同期が必要か判定する
  /// 戻り値: 同期（CSVインポート）が必要ならtrue、不要ならfalse
  Future<bool> checkSyncRequired() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localVersion = prefs.getInt('track_condition_csv_version') ?? 0;

      final response = await http.get(Uri.parse(CLOUD_VERSION_URL));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final cloudVersion = data['version'] as int;
        final lastUpdatedDate = data['last_updated'] as String;

        if (cloudVersion > localVersion) {
          // 【分岐A/B判定】
          final hasData = await _repository.hasDataForDate(lastUpdatedDate);
          if (hasData) {
            // 【分岐A: 欠落なし】 自力でスクレイピング済み。バージョンだけ更新
            await prefs.setInt('track_condition_csv_version', cloudVersion);
            return false;
          } else {
            // 【分岐B: 欠落あり】 クラウドからのインポートが必要
            return true;
          }
        }
      }
      return false;
    } catch (e) {
      print('CloudSyncService checkSyncRequired Error: $e');
      return false;
    }
  }

  /// クラウドからCSVをダウンロードしてインポートする
  Future<bool> importFromCloud() async {
    try {
      final response = await http.get(Uri.parse(CLOUD_CSV_URL));
      if (response.statusCode == 200) {
        // UTF-8 デコード
        final csvString = utf8.decode(response.bodyBytes);

        // インポート実行
        await _repository.importTrackConditionsFromCsv(csvString);

        // 成功後にバージョンを更新するために、再度version.jsonを取得
        final versionResponse = await http.get(Uri.parse(CLOUD_VERSION_URL));
        if (versionResponse.statusCode == 200) {
          final data = jsonDecode(versionResponse.body);
          final cloudVersion = data['version'] as int;

          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('track_condition_csv_version', cloudVersion);
        }
        return true;
      }
      return false;
    } catch (e) {
      print('CloudSyncService importFromCloud Error: $e');
      return false;
    }
  }
}