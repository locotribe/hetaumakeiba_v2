// lib/logic/analysis/race_analyzer.dart
// [修正] 展開シミュゲーム式移植Step5: 旧方式(順位スコア)の展開計算 simulateRaceDevelopment と、それにしか使わない定数・処理・
// バックテスト用の引数を消した。ペース予想(predictRacePace)だけ残す (v.2026.10.27+26102709)

import 'package:hetaumakeiba_v2/models/analysis_model.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/logic/race_data_parser.dart';
import 'package:hetaumakeiba_v2/logic/analysis/leg_style_analyzer.dart';

class RaceAnalyzer {
  // JRA競馬場コードと名称のマッピング
  static final Map<String, String> venueCodeMap = {
    '札幌': '01', '函館': '02', '福島': '03', '新潟': '04', '東京': '05',
    '中山': '06', '中京': '07', '京都': '08', '阪神': '09', '小倉': '10',
  };

  // トラック種別をID用の文字列に変換するマッピング
  static final Map<String, String> trackIdMap = {
    '芝': 'shiba', 'ダ': 'dirt', '障': 'obstacle',
  };

  // [追加] 上がり局面での能力反映係数（実装後の挙動を見て微調整する初期値） (v.2026.7.25)

  static RacePacePrediction predictRacePace(
      List<PredictionHorseDetail> horses,
      Map<String, List<HorseRaceRecord>> allPastRecords,
      List<RaceResult> pastRaceResults,
      ) {
    // 1. 過去レースのペース傾向を分析
    final Map<String, int> pastPaceCounts = {'ハイ': 0, 'ミドル': 0, 'スロー': 0};
    if (pastRaceResults.isNotEmpty) {
      for (final result in pastRaceResults) {
        final pace = RaceDataParser.calculatePaceFromRaceResult(result);
        pastPaceCounts[pace] = (pastPaceCounts[pace] ?? 0) + 1;
      }
    }

    // 2. 今回のメンバー構成を分析
    int nigeCount = 0;
    int senkoCount = 0;
    for (var horse in horses) {
      final records = allPastRecords[horse.horseId] ?? [];
      final style = LegStyleAnalyzer.getRunningStyle(records).primaryStyle;
      if (style == "逃げ") nigeCount++;
      if (style == "先行") senkoCount++;
    }
    final frontRunnersRatio = (nigeCount + senkoCount) / horses.length;

    // 3. ベースとなる確率を計算
    Map<String, double> paceProbabilities = {'ハイペース': 0.33, 'ミドルペース': 0.34, 'スローペース': 0.33};

    // 4. メンバー構成に応じて確率を調整
    if (nigeCount >= 2 || frontRunnersRatio > 0.5) {
      paceProbabilities['ハイペース'] = (paceProbabilities['ハイペース'] ?? 0) + 0.3;
      paceProbabilities['スローペース'] = (paceProbabilities['スローペース'] ?? 0) - 0.3;
    } else if (nigeCount == 0 && frontRunnersRatio < 0.2) {
      paceProbabilities['ハイペース'] = (paceProbabilities['ハイペース'] ?? 0) - 0.3;
      paceProbabilities['スローペース'] = (paceProbabilities['スローペース'] ?? 0) + 0.3;
    }

    // 5. 過去レースの傾向に応じてさらに確率を調整
    final totalPastRaces = pastRaceResults.length;
    if (totalPastRaces > 5) { // 十分なデータ数がある場合のみ
      final pastHighPaceRatio = (pastPaceCounts['ハイ'] ?? 0) / totalPastRaces;
      final pastSlowPaceRatio = (pastPaceCounts['スロー'] ?? 0) / totalPastRaces;
      paceProbabilities['ハイペース'] = (paceProbabilities['ハイペース'] ?? 0) + (pastHighPaceRatio - 0.33) * 0.5;
      paceProbabilities['スローペース'] = (paceProbabilities['スローペース'] ?? 0) + (pastSlowPaceRatio - 0.33) * 0.5;
    }

    // 6. 確率の合計が1になるように正規化
    final totalProbability = paceProbabilities.values.reduce((a, b) => a + b);
    if (totalProbability > 0) {
      paceProbabilities.updateAll((key, value) => (value / totalProbability).clamp(0.0, 1.0));
    } else {
      // 予期せぬエラーで合計が0になった場合は均等割りにフォールバック
      paceProbabilities = {'ハイペース': 0.33, 'ミドルペース': 0.34, 'スローペース': 0.33};
    }

    // 最終的なキー名を調整
    final finalProbabilities = {
      'ハイペース': paceProbabilities['ハイペース']!,
      'ミドルペース': paceProbabilities['ミドルペース']!,
      'スローペース': paceProbabilities['スローペース']!,
    };

    return RacePacePrediction(paceProbabilities: finalProbabilities);
  }
}
