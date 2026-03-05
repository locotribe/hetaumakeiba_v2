// lib/services/training_data_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hetaumakeiba_v2/models/training_time_model.dart';
import 'package:hetaumakeiba_v2/utils/url_generator.dart';
import 'package:hetaumakeiba_v2/db/repositories/training_repository.dart';

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
        print('DEBUG: TrainingDataService Error fetching $trackType: $e');
      }
    }

    // 取得した全データが存在すれば一括保存
    if (allRecords.isNotEmpty) {
      await _repository.insertTrainingTimes(allRecords);
      print('DEBUG: TrainingDataService Saved ${allRecords.length} records to DB.');
    }
  }
}