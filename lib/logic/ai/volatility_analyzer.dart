// lib/logic/ai/volatility_analyzer.dart

import 'package:hetaumakeiba_v2/models/race_result_model.dart';

class VolatilityResult {
  final double averagePopularity;
  final String diagnosis;
  final String description;

  VolatilityResult({
    required this.averagePopularity,
    required this.diagnosis,
    required this.description,
  });
}

class VolatilityAnalyzer {
  VolatilityResult analyze(List<RaceResult> pastRaces) {
    if (pastRaces.isEmpty) {
      return VolatilityResult(averagePopularity: 3.5, diagnosis: 'データ不足', description: '過去のレースデータがありません。');
    }

    double totalTopPop = 0.0;
    int topPopCount = 0;

    for (final r in pastRaces) {
      for (final h in r.horseResults) {
        int rank = int.tryParse(h.rank ?? '') ?? 0;
        int pop = int.tryParse(h.popularity ?? '') ?? 0;
        if (rank >= 1 && rank <= 3 && pop > 0) {
          totalTopPop += pop;
          topPopCount++;
        }
      }
    }

    double avgPop = topPopCount > 0 ? totalTopPop / topPopCount : 3.5;

    String diag = '標準';
    String desc = '人気馬と穴馬がバランスよく好走しています。';
    if (avgPop >= 4.5) {
      diag = '大波乱';
      desc = '過去の上位馬の平均人気が低く、荒れやすい傾向にあります。';
    } else if (avgPop <= 2.5) {
      diag = '堅い';
      desc = '上位人気馬が順当に結果を残す傾向が強いです。';
    }

    return VolatilityResult(
      averagePopularity: avgPop,
      diagnosis: diag,
      description: desc,
    );
  }
}

// 1. 配当 (中央値と分布の計算用)
class PayoutAnalysisResult {
  final Map<String, double> medians;
  final Map<String, double> averages;
  final Map<String, List<int>> rawPayouts; // グラフの分布（ヒストグラム）表示用

  PayoutAnalysisResult({
    required this.medians,
    required this.averages,
    required this.rawPayouts,
  });
}

// lib/logic/ai/volatility_analyzer.dart

class PayoutAnalyzer {
  // 実際のデータベースの券種ID（combination_calculator.dart）に合わせた名称マッピング
  final Map<String, String> _bettingDict = {
    '1': '単勝',
    '2': '複勝',
    '3': '枠連',
    '5': '馬連',   // 4から5に変更
    '6': '馬単',
    '7': 'ワイド', // 5から7に変更
    '8': '3連複',  // 7から8に変更
    '9': '3連単',  // 8から9に変更
  };

  PayoutAnalysisResult analyze(List<RaceResult> pastRaces) {
    final Map<String, List<int>> payoutLists = {};

    for (final r in pastRaces) {
      for (final refund in r.refunds) {
        // ticketTypeId が ID('4') の場合と名称('馬連') の場合の両方に対応
        String typeName = refund.ticketTypeId;
        if (_bettingDict.containsKey(typeName)) {
          typeName = _bettingDict[typeName]!;
        }

        payoutLists.putIfAbsent(typeName, () => []);
        for (final payout in refund.payouts) {
          final amt = int.tryParse(payout.amount.replaceAll(',', '')) ?? 0;
          if (amt > 0) payoutLists[typeName]!.add(amt);
        }
      }
    }

    final medians = <String, double>{};
    final averages = <String, double>{};

    payoutLists.forEach((type, list) {
      list.sort();
      if (list.isNotEmpty) {
        averages[type] = list.reduce((a, b) => a + b) / list.length;
        int mid = list.length ~/ 2;
        if (list.length % 2 == 0) {
          medians[type] = (list[mid - 1] + list[mid]) / 2.0;
        } else {
          medians[type] = list[mid].toDouble();
        }
      }
    });

    return PayoutAnalysisResult(
      medians: medians,
      averages: averages,
      rawPayouts: payoutLists,
    );
  }
}

// 2. 人気 (複勝圏内の分布計算用)
class PopularityAnalysisResult {
  final Map<int, int> winCounts;
  final Map<int, int> placeCounts;
  final Map<int, int> showCounts;
  final Map<int, int> totalCounts;

  PopularityAnalysisResult({
    required this.winCounts,
    required this.placeCounts,
    required this.showCounts,
    required this.totalCounts,
  });
}

class PopularityAnalyzer {
  PopularityAnalysisResult analyze(List<RaceResult> pastRaces) {
    final winCounts = <int, int>{};
    final placeCounts = <int, int>{};
    final showCounts = <int, int>{};
    final totalCounts = <int, int>{};

    for (final r in pastRaces) {
      for (final h in r.horseResults) {
        int rank = int.tryParse(h.rank ?? '') ?? 0;
        int pop = int.tryParse(h.popularity ?? '') ?? 0;
        if (pop > 0) {
          totalCounts[pop] = (totalCounts[pop] ?? 0) + 1;
          if (rank == 1) winCounts[pop] = (winCounts[pop] ?? 0) + 1;
          if (rank >= 1 && rank <= 2) placeCounts[pop] = (placeCounts[pop] ?? 0) + 1;
          if (rank >= 1 && rank <= 3) showCounts[pop] = (showCounts[pop] ?? 0) + 1;
        }
      }
    }

    return PopularityAnalysisResult(
      winCounts: winCounts,
      placeCounts: placeCounts,
      showCounts: showCounts,
      totalCounts: totalCounts,
    );
  }
}

// 3. 枠番
class FrameAnalysisResult {
  final Map<int, int> winCounts;
  final Map<int, int> placeCounts; // ★追加: 連対数
  final Map<int, int> showCounts;
  final Map<int, int> totalCounts;

  FrameAnalysisResult({
    required this.winCounts,
    required this.placeCounts, // ★追加
    required this.showCounts,
    required this.totalCounts,
  });
}

class FrameAnalyzer {
  FrameAnalysisResult analyze(List<RaceResult> pastRaces) {
    final winCounts = <int, int>{};
    final placeCounts = <int, int>{}; // ★追加
    final showCounts = <int, int>{};
    final totalCounts = <int, int>{};

    for (final r in pastRaces) {
      for (final h in r.horseResults) {
        int rank = int.tryParse(h.rank ?? '') ?? 0;
        int frame = int.tryParse(h.frameNumber ?? '') ?? 0;
        if (frame > 0) {
          totalCounts[frame] = (totalCounts[frame] ?? 0) + 1;
          if (rank == 1) winCounts[frame] = (winCounts[frame] ?? 0) + 1;
          if (rank >= 1 && rank <= 2) placeCounts[frame] = (placeCounts[frame] ?? 0) + 1; // ★追加
          if (rank >= 1 && rank <= 3) showCounts[frame] = (showCounts[frame] ?? 0) + 1;
        }
      }
    }

    return FrameAnalysisResult(
      winCounts: winCounts,
      placeCounts: placeCounts, // ★追加
      showCounts: showCounts,
      totalCounts: totalCounts,
    );
  }
}

// 4. 脚質
class LegStyleAnalysisResult {
  final Map<String, int> winCounts;
  final Map<String, int> showCounts;
  final Map<String, int> totalCounts;

  LegStyleAnalysisResult({
    required this.winCounts,
    required this.showCounts,
    required this.totalCounts,
  });
}

class LegStyleAnalyzer {
  LegStyleAnalysisResult analyze(List<RaceResult> pastRaces) {
    final winCounts = <String, int>{};
    final showCounts = <String, int>{};
    final totalCounts = <String, int>{};

    String determineLegStyle(String? cornerStr) {
      if (cornerStr == null || cornerStr.isEmpty) return '不明';
      final corners = cornerStr.split('-');
      if (corners.isEmpty) return '不明';
      final lastCornerStr = corners.last.replaceAll(RegExp(r'[^0-9]'), '');
      final pos = int.tryParse(lastCornerStr);
      if (pos == null) return '不明';
      if (pos <= 3) return '逃げ・先行';
      if (pos <= 8) return '差し';
      return '追込';
    }

    for (final r in pastRaces) {
      for (final h in r.horseResults) {
        int rank = int.tryParse(h.rank ?? '') ?? 0;
        String style = determineLegStyle(h.cornerRanking);
        if (style != '不明') {
          totalCounts[style] = (totalCounts[style] ?? 0) + 1;
          if (rank == 1) winCounts[style] = (winCounts[style] ?? 0) + 1;
          if (rank >= 1 && rank <= 3) showCounts[style] = (showCounts[style] ?? 0) + 1;
        }
      }
    }

    return LegStyleAnalysisResult(
      winCounts: winCounts,
      showCounts: showCounts,
      totalCounts: totalCounts,
    );
  }
}


// 5. 馬体重 (勝ち馬の平均からの散布度合いと、増減別成績用)
class WeightChangeStats {
  int total = 0;
  int win = 0;
  int place = 0;
  int show = 0;
}

class HorseWeightAnalysisResult {
  final List<double> winningWeights;
  final double averageWinningWeight;
  final double medianWinningWeight;
  final Map<String, WeightChangeStats> changeStats; // 増減別の集計データ

  HorseWeightAnalysisResult({
    required this.winningWeights,
    required this.averageWinningWeight,
    required this.medianWinningWeight,
    required this.changeStats,
  });
}

class HorseWeightAnalyzer {
  HorseWeightAnalysisResult analyze(List<RaceResult> pastRaces) {
    final List<double> winningWeights = [];
    final Map<String, WeightChangeStats> changeStats = {
      '-10kg以下': WeightChangeStats(),
      '-4~-8kg': WeightChangeStats(),
      '-2~+2kg': WeightChangeStats(),
      '+4~+8kg': WeightChangeStats(),
      '+10kg以上': WeightChangeStats(),
    };

    for (final r in pastRaces) {
      for (final h in r.horseResults) {
        int rank = int.tryParse(h.rank ?? '') ?? 0;
        final weightStr = h.horseWeight ?? '';

        bool isWin = rank == 1;
        bool isPlace = rank >= 1 && rank <= 2;
        bool isShow = rank >= 1 && rank <= 3;

        // statistics_service.dart と同一の正規表現・抽出ロジックを使用
        final weightMatch = RegExp(r'(\d+)\(([\+\-]\d+)\)').firstMatch(weightStr);
        if (weightMatch != null) {
          final weight = double.tryParse(weightMatch.group(1)!);
          final weightChange = int.tryParse(weightMatch.group(2)!);

          if (weight != null && weightChange != null) {
            if (isWin) winningWeights.add(weight);

            String category;
            if (weightChange <= -10) {
              category = '-10kg以下';
            } else if (weightChange <= -4) {
              category = '-4~-8kg';
            } else if (weightChange <= 2) {
              category = '-2~+2kg';
            } else if (weightChange <= 8) {
              category = '+4~+8kg';
            } else {
              category = '+10kg以上';
            }

            changeStats[category]!.total += 1;
            if (isWin) changeStats[category]!.win += 1;
            if (isPlace) changeStats[category]!.place += 1;
            if (isShow) changeStats[category]!.show += 1;
          }
        }
      }
    }

    double avg = 0.0;
    double median = 0.0;

    if (winningWeights.isNotEmpty) {
      winningWeights.sort();
      avg = winningWeights.reduce((a, b) => a + b) / winningWeights.length;
      int mid = winningWeights.length ~/ 2;
      if (winningWeights.length % 2 == 0) {
        median = (winningWeights[mid - 1] + winningWeights[mid]) / 2.0;
      } else {
        median = winningWeights[mid];
      }
    }

    return HorseWeightAnalysisResult(
      winningWeights: winningWeights,
      averageWinningWeight: avg,
      medianWinningWeight: median,
      changeStats: changeStats,
    );
  }
}

// 6. 過去上位3頭の抽出用
class PastTopHorse {
  final int rank;
  final String frameNumber;
  final String horseNumber;
  final String horseName;
  final String popularity;

  PastTopHorse({
    required this.rank,
    required this.frameNumber,
    required this.horseNumber,
    required this.horseName,
    required this.popularity,
  });
}

class PastRaceTop3Result {
  final String raceId;
  final String year;
  final String raceName;
  final String raceInfo; // ★追加: コース情報 (芝/ダート判定用)
  final List<PastTopHorse> topHorses;

  PastRaceTop3Result({
    required this.raceId,
    required this.year,
    required this.raceName,
    required this.raceInfo, // ★追加
    required this.topHorses,
  });
}

class PastTopHorsesAnalyzer {
  List<PastRaceTop3Result> analyze(List<RaceResult> pastRaces) {
    List<PastRaceTop3Result> results = [];
    for (final r in pastRaces) {
      List<PastTopHorse> topHorses = [];
      for (final h in r.horseResults) {
        int rank = int.tryParse(h.rank ?? '') ?? 0;
        if (rank >= 1 && rank <= 3) {
          topHorses.add(PastTopHorse(
            rank: rank,
            frameNumber: h.frameNumber ?? '-',
            horseNumber: h.horseNumber ?? '-',
            horseName: h.horseName ?? '',
            popularity: h.popularity ?? '-',
          ));
        }
      }
      // 着順でソート
      topHorses.sort((a, b) => a.rank.compareTo(b.rank));

      String raceName = r.raceTitle;
      String year = '-';
      String raceInfo = r.raceInfo; // ★追加: 芝/ダートの判定用文字列を取得

      if (r.raceDate.contains('年')) {
        year = r.raceDate.split('年').first;
      } else if (r.raceDate.length >= 4) {
        year = r.raceDate.substring(0, 4);
      }

      results.add(PastRaceTop3Result(
        raceId: r.raceId,
        year: year,
        raceName: raceName,
        raceInfo: raceInfo, // ★追加
        topHorses: topHorses,
      ));
    }
    return results;
  }
}
// 7. ラップタイム・ペース
class PaceLegStyleStats {
  int total = 0;
  Map<String, int> showCounts = {
    '逃げ': 0,
    '先行': 0,
    '差し': 0,
    '追込': 0,
  };
}

class RaceLapData {
  final String raceId;
  final String raceName;
  final String raceDate; // ★追加: レース年月日
  final String winningHorseName; // ★追加: 勝ち馬名
  final String paceCategory; // ハイペース, ミドルペース, スローペース
  final bool isAccelerating; // 加速ラップか
  final List<double> lapTimes;
  final double first3F;
  final double last3F;
  final String trackCondition; // ★追加: 馬場状態

  RaceLapData({
    required this.raceId,
    required this.raceName,
    required this.raceDate, // ★追加
    required this.winningHorseName, // ★追加
    required this.paceCategory,
    required this.isAccelerating,
    required this.lapTimes,
    required this.first3F,
    required this.last3F,
    required this.trackCondition,
  });
}

class LapTimeAnalysisResult {
  final List<double> averageLapTimes;
  final double averageFirst3F;
  final double averageLast3F;
  final Map<String, PaceLegStyleStats> paceLegStyleStats;
  final List<RaceLapData> acceleratingRaces;
  final String typicalPace;
  final List<RaceLapData> allRacesLapData; // ★追加: 全レースのラップデータ

  LapTimeAnalysisResult({
    required this.averageLapTimes,
    required this.averageFirst3F,
    required this.averageLast3F,
    required this.paceLegStyleStats,
    required this.acceleratingRaces,
    required this.typicalPace,
    required this.allRacesLapData, // ★追加
  });
}

class LapTimeAnalyzer {
  LapTimeAnalysisResult? analyze(List<RaceResult> pastRaces) {
    if (pastRaces.isEmpty) return null;

    int? targetDistance;
    int targetLapCount = 0;

    List<List<double>> validLapsList = [];
    List<double> allFirst3F = [];
    List<double> allLast3F = [];

    final paceLegStyleStats = {
      'ハイペース': PaceLegStyleStats(),
      'ミドルペース': PaceLegStyleStats(),
      'スローペース': PaceLegStyleStats(),
    };

    List<RaceLapData> acceleratingRaces = [];
    List<RaceLapData> allRacesLapData = []; // ★追加: 全レースデータを保持するリスト
    Map<String, int> paceCounts = {'ハイペース': 0, 'ミドルペース': 0, 'スローペース': 0};

    String determineLegStyle(String? cornerStr) {
      if (cornerStr == null || cornerStr.isEmpty) return '不明';
      final corners = cornerStr.split('-');
      if (corners.isEmpty) return '不明';
      final lastCornerStr = corners.last.replaceAll(RegExp(r'[^0-9]'), '');
      final pos = int.tryParse(lastCornerStr);
      if (pos == null) return '不明';
      if (pos == 1) return '逃げ';
      if (pos <= 5) return '先行';
      if (pos <= 10) return '差し';
      return '追込';
    }

    for (final r in pastRaces) {
      // 距離の抽出（距離が異なるレースを計算から除外するため）
      final distMatch = RegExp(r'\d{4}').firstMatch(r.raceInfo);
      if (distMatch == null) continue;
      final distance = int.tryParse(distMatch.group(0)!);
      if (distance == null) continue;

      if (targetDistance == null) {
        targetDistance = distance;
      } else if (targetDistance != distance) {
        continue; // 距離が違うレースは除外
      }

      List<double> lapList = [];
      double first3F = 0.0;
      double last3F = 0.0;

      for (String lapStr in r.lapTimes) {
        if (lapStr.startsWith('ラップ:')) {
          final laps = lapStr.replaceAll('ラップ:', '').split('-');
          lapList = laps.map((e) => double.tryParse(e.trim()) ?? 0.0).toList();
        } else if (lapStr.startsWith('ペース:')) {
          final match = RegExp(r'\(([\d\.]+)-([\d\.]+)\)').firstMatch(lapStr);
          if (match != null) {
            first3F = double.tryParse(match.group(1) ?? '') ?? 0.0;
            last3F = double.tryParse(match.group(2) ?? '') ?? 0.0;
          }
        }
      }

      // ペースデータがない場合（パース失敗等）の代替計算
      if (lapList.length >= 3) {
        if (first3F == 0.0) {
          first3F = lapList.take(3).fold(0.0, (a, b) => a + b);
        }
        if (last3F == 0.0) {
          last3F = lapList.skip(lapList.length - 3).fold(0.0, (a, b) => a + b);
        }
      }

      if (lapList.isEmpty || first3F == 0.0 || last3F == 0.0) continue;

      if (targetLapCount == 0) {
        targetLapCount = lapList.length;
      } else if (targetLapCount != lapList.length) {
        continue; // ハロン数が違う場合は除外
      }

      validLapsList.add(lapList);
      allFirst3F.add(first3F);
      allLast3F.add(last3F);

      // ペース判定（前後半3Fの差が0.5秒より大きいかで判定）
      String paceCategory = 'ミドルペース';
      if (first3F < last3F - 0.5) {
        paceCategory = 'ハイペース';
      } else if (first3F > last3F + 0.5) {
        paceCategory = 'スローペース';
      }
      paceCounts[paceCategory] = (paceCounts[paceCategory] ?? 0) + 1;
      paceLegStyleStats[paceCategory]!.total += 1;

      // 脚質集計
      for (final h in r.horseResults) {
        int rank = int.tryParse(h.rank ?? '') ?? 0;
        if (rank >= 1 && rank <= 3) {
          String style = determineLegStyle(h.cornerRanking);
          if (paceLegStyleStats[paceCategory]!.showCounts.containsKey(style)) {
            paceLegStyleStats[paceCategory]!.showCounts[style] =
                paceLegStyleStats[paceCategory]!.showCounts[style]! + 1;
          }
        }
      }

      // 馬場状態判定
      String trackCondition = '良';
      if (r.raceInfo.contains('不良')) {
        trackCondition = '不良';
      } else if (r.raceInfo.contains('稍重')) {
        trackCondition = '稍重';
      } else if (r.raceInfo.contains('重')) {
        trackCondition = '重';
      } else if (r.raceInfo.contains('良')) {
        trackCondition = '良';
      }

      // ★追加: 勝ち馬（1着馬）の特定
      String winningHorseName = '不明';
      for (final h in r.horseResults) {
        if (h.rank == '1') {
          winningHorseName = h.horseName ?? '不明';
          break;
        }
      }

      // 加速ラップ判定（最後から2番目のハロン > 最後のハロン であれば終盤加速とみなす）
      bool isAccelerating = false;
      if (lapList.length >= 2) {
        if (lapList[lapList.length - 2] > lapList.last) {
          isAccelerating = true;
        }
      }

      final raceLapData = RaceLapData(
        raceId: r.raceId,
        raceName: r.raceTitle,
        raceDate: r.raceDate, // ★追加
        winningHorseName: winningHorseName, // ★追加
        paceCategory: paceCategory,
        isAccelerating: isAccelerating,
        lapTimes: lapList,
        first3F: first3F,
        last3F: last3F,
        trackCondition: trackCondition,
      );

      allRacesLapData.add(raceLapData); // ★追加: 全レースのラップデータを保存

      if (isAccelerating) {
        acceleratingRaces.add(raceLapData);
      }
    }

    if (validLapsList.isEmpty) return null;

    // 平均計算
    List<double> avgLaps = List.filled(targetLapCount, 0.0);
    for (int i = 0; i < targetLapCount; i++) {
      double sum = 0;
      for (var laps in validLapsList) {
        sum += laps[i];
      }
      avgLaps[i] = sum / validLapsList.length;
    }

    double avgFirst3F = allFirst3F.reduce((a, b) => a + b) / allFirst3F.length;
    double avgLast3F = allLast3F.reduce((a, b) => a + b) / allLast3F.length;

    String typicalPace = paceCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    return LapTimeAnalysisResult(
      averageLapTimes: avgLaps,
      averageFirst3F: avgFirst3F,
      averageLast3F: avgLast3F,
      paceLegStyleStats: paceLegStyleStats,
      acceleratingRaces: acceleratingRaces,
      typicalPace: typicalPace,
      allRacesLapData: allRacesLapData, // ★追加
    );
  }
}