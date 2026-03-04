// lib/services/training_data_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hetaumakeiba_v2/models/training_time_model.dart';
import 'package:hetaumakeiba_v2/utils/url_generator.dart';
import 'package:hetaumakeiba_v2/db/repositories/training_repository.dart';

class TrainingDataService {
  final TrainingRepository _repository = TrainingRepository();

  /// pakara-keibaから対象レースに出走する全馬の調教データを取得し、DBに保存します。
  Future<void> fetchAndSaveTrainingData({
    required String raceId,
    required String raceDate,
    required List<String> horseIds,
  }) async {
    if (horseIds.isEmpty) return;

    // UrlGeneratorに追記したメソッドを使用してPOSTパラメータを生成
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
                  // 各ハロンタイムの文字列をdoubleに変換
                  final f6Str = c['f6']?.toString() ?? '';
                  final f5Str = c['f5']?.toString() ?? '';
                  final f4Str = c['f4']?.toString() ?? '';
                  final f3Str = c['f3']?.toString() ?? '';
                  final f2Str = c['f2']?.toString() ?? '';
                  final f1Str = c['f1']?.toString() ?? '';

                  // kyuusyaフィールドには「栗東」「美浦」などの情報が入る
                  final locationStr = c['kyuusya']?.toString() ?? '不明';

                  allRecords.add(TrainingTimeModel(
                    horseId: hId,
                    trainingDate: c['date']?.toString() ?? '',
                    trainingTime: c['time']?.toString() ?? '',
                    trackType: trackType,
                    location: locationStr,
                    f6: double.tryParse(f6Str),
                    f5: double.tryParse(f5Str),
                    f4: double.tryParse(f4Str),
                    f3: double.tryParse(f3Str),
                    f2: double.tryParse(f2Str),
                    f1: double.tryParse(f1Str),
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