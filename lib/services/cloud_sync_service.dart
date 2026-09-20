// lib/services/cloud_sync_service.dart

import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hetaumakeiba_v2/db/repositories/track_condition_repository.dart';

class CloudSyncService {
  static const String CLOUD_VERSION_URL = 'https://raw.githubusercontent.com/locotribe/keiba-track-conditions/main/version.json';
  static const String CLOUD_CSV_URL = 'https://raw.githubusercontent.com/locotribe/keiba-track-conditions/main/track_conditions.csv';

  final TrackConditionRepository _repository = TrackConditionRepository();

  // [追加] 同期要否の判定本体。テストから直接呼べるよう純粋な関数として切り出す。
  // version.json に rows（サーバーの全件数）があれば件数差で判定し、無い場合は従来のバージョン比較に
  // フォールバックする (v.2026.9.21+26092101)
  static bool isSyncRequired(
      Map<String, dynamic> data, int localRows, int localVersion) {
    final cloudRows = data['rows'];
    if (cloudRows is int) {
      return cloudRows > localRows;
    }
    final cloudVersion = data['version'];
    if (cloudVersion is int) {
      return cloudVersion > localVersion;
    }
    return false;
  }

  /// クラウドのバージョン情報を取得し、同期が必要か判定する
  /// 戻り値: 同期（CSVインポート）が必要ならtrue、不要ならfalse
  Future<bool> checkSyncRequired() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localVersion = prefs.getInt('track_condition_csv_version') ?? 0;

      final response = await http.get(Uri.parse(CLOUD_VERSION_URL));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        // [修正] サーバーの件数がローカルより多いときだけ同期対象とする。
        // アプリが当日分を先に取得している場合（ローカルのほうが多い）は対象外 (v.2026.9.21+26092101)
        final localRows = await _repository.countAll();
        return isSyncRequired(data, localRows, localVersion);
      }
      return false;
    } catch (e) {
      debugPrint('CloudSyncService checkSyncRequired Error: $e');
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
        // [修正] 同一日付・同一競馬場はサーバーの行で置き換える方式に変更 (v.2026.9.19+26091902)
        await _repository.replaceTrackConditionsFromCsv(csvString);

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
      debugPrint('CloudSyncService importFromCloud Error: $e');
      return false;
    }
  }
}