import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/track_conditions_model.dart';
import 'package:hetaumakeiba_v2/models/historical_match_model.dart';

class TrackConditionFactorResult {
  final Map<String, double> scenarioScores; // 'high', 'standard', 'low'

  TrackConditionFactorResult({required this.scenarioScores});
}

class TrackConditionFactor {
  TrackConditionFactorResult analyze({
    required List<HorseRaceRecord> history,
    required Map<String, TrackConditionRecord> horsePastTrackConditions,
    required bool isDirt,
    required TrackConditionTrendResult trendResult,
  }) {
    List<double> goodPerformances = [];

    // 1. 馬の過去の「1〜3着」の好走レースの数値を抽出
    for (var rec in history) {
      int rank = int.tryParse(rec.rank) ?? 0;
      if (rank >= 1 && rank <= 3) {
        final tc = horsePastTrackConditions[rec.raceId];
        if (tc != null) {
          if (!isDirt) {
            double cushion = tc.cushionValue ?? 0.0;
            if (cushion > 0) goodPerformances.add(cushion);
          } else {
            // ★修正: ダートの場合は4コーナーの含水率を採用（無ければゴール前）
            double moisture = (tc.moistureDirt4c ?? 0.0) > 0 ? tc.moistureDirt4c! : (tc.moistureDirtGoal ?? 0.0);
            if (moisture > 0) goodPerformances.add(moisture);
          }
        }
      }
    }

    double highScore = 50.0;
    double standardScore = 50.0;
    double lowScore = 50.0;

    if (goodPerformances.isNotEmpty) {
      // 2. その馬の「ストライクゾーン（得意な馬場の平均値）」を計算
      double horseAvg = goodPerformances.reduce((a, b) => a + b) / goodPerformances.length;

      if (!isDirt) {
        // --- 芝（クッション値）の計算 ---
        double avg = trendResult.avgCushion > 0 ? trendResult.avgCushion : 9.5;
        double highTarget = avg + 0.3;
        double stdTarget = avg;
        double lowTarget = avg - 0.3;

        // シナリオ想定値と馬のストライクゾーンの「差分」で減点 (差が0なら100点)
        highScore = 100.0 - ((horseAvg - highTarget).abs() * 100.0);
        standardScore = 100.0 - ((horseAvg - stdTarget).abs() * 100.0);
        lowScore = 100.0 - ((horseAvg - lowTarget).abs() * 100.0);
      } else {
        // --- ダート（含水率）の計算 ---
        double avg = trendResult.avgDirtMoisture > 0 ? trendResult.avgDirtMoisture : 8.0;
        double lowTarget = avg >= 2.0 ? avg - 2.0 : 0.0; // 含水率低(乾)
        double stdTarget = avg;                          // 含水率標
        double highTarget = avg + 2.0;                   // 含水率高(湿)

        // 含水率は値のブレが大きいので減点係数を緩める
        highScore = 100.0 - ((horseAvg - highTarget).abs() * 15.0);
        standardScore = 100.0 - ((horseAvg - stdTarget).abs() * 15.0);
        lowScore = 100.0 - ((horseAvg - lowTarget).abs() * 15.0);
      }
    } else {
      // 3. データが取れなかった場合のフォールバック（文字情報から擬似判定）
      int firmCount = 0;
      int softCount = 0;
      int totalGood = 0;
      for (var rec in history) {
        int rank = int.tryParse(rec.rank) ?? 0;
        if (rank >= 1 && rank <= 3) {
          totalGood++;
          // ★修正: condition ではなく trackCondition を使用
          if (rec.trackCondition.contains('良')) firmCount++;
          if (rec.trackCondition.contains('重') || rec.trackCondition.contains('不良') || rec.trackCondition.contains('稍')) softCount++;
        }
      }
      if (totalGood > 0) {
        if (firmCount > softCount) {
          highScore = 75.0; standardScore = 60.0; lowScore = 40.0;
        } else if (softCount > firmCount) {
          highScore = 40.0; standardScore = 60.0; lowScore = 75.0;
        } else {
          highScore = 60.0; standardScore = 60.0; lowScore = 60.0;
        }
      }
    }

    return TrackConditionFactorResult(
        scenarioScores: {
          'high': highScore.clamp(40.0, 100.0), // 最低40点を保証
          'standard': standardScore.clamp(40.0, 100.0),
          'low': lowScore.clamp(40.0, 100.0),
        }
    );
  }
}