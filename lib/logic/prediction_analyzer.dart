// lib/logic/prediction_analyzer.dart

import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/prediction_analysis_model.dart';
import 'package:hetaumakeiba_v2/models/prediction_race_data.dart';

class PredictionAnalyzer {
  // 競走馬一頭の全過去成績を受け取り、各適性スコアを計算して返すメソッド
  static HorsePredictionScore calculateScores(List<HorseRaceRecord> records) {
    // スコア計算用のロジックをここに実装します。
    // 以下はスコア算出の一例です。

    // 例：距離適性スコア（直近5走の平均着順をスコア化）
    final recentRaces = records.take(5).toList();
    double totalRank = 0;
    int raceCount = 0;
    for (var record in recentRaces) {
      final rank = int.tryParse(record.rank);
      if (rank != null) {
        totalRank += rank;
        raceCount++;
      }
    }
    // 平均着順が良いほどスコアが高くなるように変換 (1着=100点, 10着=10点)
    final double averageRank = raceCount > 0 ? totalRank / raceCount : 18.0;
    final double distanceScore = (11 - averageRank).clamp(0, 10) * 10;

    // 例：コース適性スコア（全レースでの勝利経験をスコア化）
    bool hasWin = records.any((record) => record.rank == '1');
    final double courseScore = hasWin ? 100.0 : 50.0;

    // 例：騎手相性スコア（直近の騎乗経験をスコア化）
    bool hasRecentRide = recentRaces.isNotEmpty && recentRaces.first.jockey.isNotEmpty;
    final double jockeyCompatibilityScore = hasRecentRide ? 90.0 : 60.0;

    return HorsePredictionScore(
      distanceScore: distanceScore,
      courseScore: courseScore,
      jockeyCompatibilityScore: jockeyCompatibilityScore,
    );
  }

  // 内部ヘルパー：脚質を判定する
  static String _getRunningStyle(List<HorseRaceRecord> records) {
    if (records.isEmpty) return "不明";

    int frontRunnerCount = 0;
    final recentRaces = records.take(3); // 直近3走で判断

    for(var record in recentRaces) {
      final positions = record.cornerPassage.split('-').map((p) => int.tryParse(p) ?? 99).toList();
      if (positions.isNotEmpty) {
        // 第2コーナー(インデックス1)までの順位が馬群の1/4以内なら先行タイプと判定
        final horseCount = int.tryParse(record.numberOfHorses) ?? 12;
        if (positions.first <= (horseCount / 4)) {
          frontRunnerCount++;
        }
      }
    }
    // 3走中2走以上で先行していれば「逃げ・先行」と判断
    if (frontRunnerCount >= 2) return "逃げ・先行";
    return "差し・追込";
  }

  // レースに出走する全馬のデータを受け取り、レース全体の展開を予測して返すメソッド
  static RacePacePrediction predictRacePace(List<PredictionHorseDetail> horses, Map<String, List<HorseRaceRecord>> allPastRecords) {
    int frontRunnerCount = 0;
    for (var horse in horses) {
      final records = allPastRecords[horse.horseId] ?? [];
      final style = _getRunningStyle(records);
      if (style == "逃げ・先行") {
        frontRunnerCount++;
      }
    }

    String predictedPace;
    String advantageousStyle;

    // 逃げ・先行タイプの馬の数に応じてペースを予測
    if (frontRunnerCount >= (horses.length / 3)) {
      predictedPace = "ハイペース";
      advantageousStyle = "差し・追込有利";
    } else if (frontRunnerCount <= 1) {
      predictedPace = "スローペース";
      advantageousStyle = "逃げ・先行有利";
    } else {
      predictedPace = "ミドルペース";
      advantageousStyle = "展開次第";
    }

    return RacePacePrediction(
      predictedPace: predictedPace,
      advantageousStyle: advantageousStyle,
    );
  }
}