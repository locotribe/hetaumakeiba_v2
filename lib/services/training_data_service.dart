// lib/services/training_data_service.dart

import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hetaumakeiba_v2/models/training_time_model.dart';
import 'package:hetaumakeiba_v2/utils/url_generator.dart';
import 'package:hetaumakeiba_v2/db/repositories/training_repository.dart';
// [追加] 出走の意味 調教の行 Step3: pakara を前走の日まで遡る (v.2026.10.24+26102403)
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hetaumakeiba_v2/logic/pakara_backfill.dart';
import 'package:hetaumakeiba_v2/logic/training_fetch_policy.dart';

class TrainingDataService {
  final TrainingRepository _repository = TrainingRepository();

  /// 文字列のタイムをdoubleに変換し、999.9などの異常値を除外します
  double? _parseTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return null;
    final time = double.tryParse(timeStr);
    if (time == null) return null;

    // 0秒以下、または150秒以上（6Fでも通常は90秒前後）のあり得ないタイムは計測エラーとしてnullにする
    if (time <= 0.0 || time > 500.0) {
      return null;
    }
    return time;
  }

  /// pakara-keibaから対象レースに出走する全馬の調教データを取得し、DBに保存します。
  Future<void> fetchAndSaveTrainingData({
    required String raceId,
    required String raceDate,
    required List<String> horseIds,
  }) async {
    if (horseIds.isEmpty) return;

    final params = generatePakaraApiParams(
      raceId: raceId,
      raceDate: raceDate,
      horseIds: horseIds,
    );

    final urls = [
      getPakaraHanroApiUrl(),
      getPakaraWoodApiUrl(),
    ];

    List<TrainingTimeModel> allRecords = [];

    for (var url in urls) {
      final isWC = url.contains('wc');
      final trackType = isWC ? "ウッド" : "坂路";

      try {
        final response = await http.post(
          Uri.parse(url),
          headers: {
            "Content-Type": "application/x-www-form-urlencoded",
            "X-Requested-With": "XMLHttpRequest",
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
          },
          body: params,
        );

        if (response.statusCode == 200) {
          final dynamic decoded = json.decode(response.body);
          if (decoded is List) {
            for (var horse in decoded) {
              final hId = horse['name']?.toString() ?? '';
              if (hId.isEmpty) continue;

              final cyoukyou = horse['cyoukyou'] as List?;
              if (cyoukyou != null) {
                for (var c in cyoukyou) {
                  final locationStr = c['kyuusya']?.toString() ?? '不明';

                  // ★修正: ヘッパーメソッドを経由して異常値をフィルタリング
                  allRecords.add(TrainingTimeModel(
                    horseId: hId,
                    trainingDate: c['date']?.toString() ?? '',
                    trainingTime: c['time']?.toString() ?? '',
                    trackType: trackType,
                    location: locationStr,
                    f6: _parseTime(c['f6']?.toString()),
                    f5: _parseTime(c['f5']?.toString()),
                    f4: _parseTime(c['f4']?.toString()),
                    f3: _parseTime(c['f3']?.toString()),
                    f2: _parseTime(c['f2']?.toString()),
                    f1: _parseTime(c['f1']?.toString()),
                    stableName: locationStr,
                  ));
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('DEBUG: TrainingDataService Error fetching $trackType: $e');
      }
    }

    // 取得した全データが存在すれば一括保存
    if (allRecords.isNotEmpty) {
      await _repository.insertTrainingTimes(allRecords);
    }
  }

  // [追加] 出走の意味 調教の行 Step3: pakara の調教を前走の日まで遡って取り、保存する。
  // [raceYmd] レース日（YYYYMMDD）、[lastStartByHorse] 馬ID → 前走の日（YYYYMMDD）。戻り値は保存した行数。
  // 通信に失敗した馬には「取り終えた」印を付けず（次の機会に取り直す）、例外にもしない。印は SharedPreferences（pakara_backfill_馬ID_前走の日） (v.2026.10.24+26102403)
  Future<int> backfillToLastStart({
    required String raceId,
    required String raceYmd,
    required Map<String, String> lastStartByHorse,
  }) async {
    if (lastStartByHorse.isEmpty) return 0;
    final prefs = await SharedPreferences.getInstance();
    final runner = PakaraBackfillRunner(
      fetchPage: (trackType, date, horseIds) => _fetchPakaraPage(
        raceId: raceId,
        trackType: trackType,
        date: date,
        horseIds: horseIds,
      ),
      saveRows: _repository.insertTrainingTimes,
      isMarked: (horseId, lastStartYmd) async =>
          prefs.getBool(pakaraBackfillPrefKey(horseId, lastStartYmd)) ?? false,
      mark: (horseId, lastStartYmd) async {
        await prefs.setBool(pakaraBackfillPrefKey(horseId, lastStartYmd), true);
      },
      waitInterval: () => Future.delayed(
          const Duration(milliseconds: kPakaraRequestIntervalMs)),
    );
    final result = await runner.run(
      raceYmd: raceYmd,
      lastStartByHorse: lastStartByHorse,
    );
    debugPrint(
        'TrainingDataService: pakara遡り 対象${result.targetCount}頭・要求${result.requestCount}回・保存${result.savedRows}行・取り切り${result.completedHorses}頭 (race=$raceId)');
    return result.savedRows;
  }

  // [追加] 出走の意味 調教の行 Step3: pakara の1ページ（1種別・指定した日より前の最大10本）を取る。失敗は null (v.2026.10.24+26102403)
  Future<List<TrainingTimeModel>?> _fetchPakaraPage({
    required String raceId,
    required String trackType,
    required String date,
    required List<String> horseIds,
  }) async {
    final params = generatePakaraApiParams(
      raceId: raceId,
      raceDate: date,
      horseIds: horseIds,
    );
    final url =
        trackType == 'ウッド' ? getPakaraWoodApiUrl() : getPakaraHanroApiUrl();
    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              "Content-Type": "application/x-www-form-urlencoded",
              "X-Requested-With": "XMLHttpRequest",
              "User-Agent":
                  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            },
            body: params,
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        debugPrint(
            'TrainingDataService: pakara HTTP ${response.statusCode} ($trackType $date)');
        return null;
      }
      return parsePakaraResponse(response.body, trackType);
    } catch (e) {
      debugPrint('TrainingDataService: pakara遡りの取得に失敗 ($trackType $date): $e');
      return null;
    }
  }
}