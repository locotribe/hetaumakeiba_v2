// lib/logic/analysis/volatility_analyzer.dart

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

// 4. 脚質の分析結果クラスを拡張
class LegStyleAnalysisResult {
  final Map<String, int> winCounts;
  final Map<String, int> placeCounts; // ★追加: 2着数
  final Map<String, int> showCounts;  // ★追加: 3着数
  final Map<String, int> totalCounts;

  LegStyleAnalysisResult({
    required this.winCounts,
    required this.placeCounts, // ★追加
    required this.showCounts,  // ★追加
    required this.totalCounts,
  });
}

class LegStyleAnalyzer {
  LegStyleAnalysisResult analyze(List<RaceResult> pastRaces) {
    final winCounts = <String, int>{};
    final placeCounts = <String, int>{}; // ★追加
    final showCounts = <String, int>{};  // ★追加
    final totalCounts = <String, int>{};

    // ★修正: 判定ロジックを精細化（逃げと先行を分離、差しと追込の基準設定）
    String determineLegStyle(String? cornerStr) {
      if (cornerStr == null || cornerStr.isEmpty) return '不明';
      final corners = cornerStr.split('-');
      if (corners.isEmpty) return '不明';

      final lastCornerStr = corners.last.replaceAll(RegExp(r'[^0-9]'), '');
      final pos = int.tryParse(lastCornerStr);
      if (pos == null) return '不明';

      if (pos == 1) return '逃げ';       // 1番手のみ逃げ
      if (pos <= 5) return '先行';      // 2〜5番手
      if (pos <= 10) return '差し';     // 6〜10番手
      return '追込';                    // 11番手以降
    }

    for (final r in pastRaces) {
      for (final h in r.horseResults) {
        int rank = int.tryParse(h.rank ?? '') ?? 0;
        String style = determineLegStyle(h.cornerRanking);

        if (style != '不明') {
          totalCounts[style] = (totalCounts[style] ?? 0) + 1;
          // 各着順ごとにカウント
          if (rank == 1) winCounts[style] = (winCounts[style] ?? 0) + 1;
          if (rank == 2) placeCounts[style] = (placeCounts[style] ?? 0) + 1;
          if (rank == 3) showCounts[style] = (showCounts[style] ?? 0) + 1;
        }
      }
    }

    return LegStyleAnalysisResult(
      winCounts: winCounts,
      placeCounts: placeCounts, // ★追加
      showCounts: showCounts,   // ★追加
      totalCounts: totalCounts,
    );
  }
}


// 5. 馬体重 (勝ち馬の平均からの散布度合いと、増減別成績用)
// [修正] 絶対値と増減の両方で汎用的に利用できるようクラス名を WeightChangeStats から WeightStats に変更 (v.1.1)
class WeightStats {
  int total = 0;
  int win = 0;
  int place = 0;
  int show = 0;
}

class HorseWeightAnalysisResult {
  final List<double> winningWeights;
  final double averageWinningWeight;
  final double medianWinningWeight;
  // [修正] 型を WeightStats に変更 (v.1.1)
  final Map<String, WeightStats> changeStats; // 増減別の集計データ
  // [追加] 馬体重（絶対値）の階級別集計データを追加 (v.1.1)
  final Map<String, WeightStats> absoluteStats;

  HorseWeightAnalysisResult({
    required this.winningWeights,
    required this.averageWinningWeight,
    required this.medianWinningWeight,
    required this.changeStats,
    // [追加] コンストラクタ引数に追加 (v.1.1)
    required this.absoluteStats,
  });
}

class HorseWeightAnalyzer {
  HorseWeightAnalysisResult analyze(List<RaceResult> pastRaces) {
    final List<double> winningWeights = [];
    // [修正] 型を WeightStats に変更 (v.1.1)
    final Map<String, WeightStats> changeStats = {
      '-10kg以下': WeightStats(),
      '-4~-8kg': WeightStats(),
      '-2~+2kg': WeightStats(),
      '+4~+8kg': WeightStats(),
      '+10kg以上': WeightStats(),
    };

    // [追加] 絶対馬体重の階級（20kg刻み）の初期化 (v.1.1)
    final Map<String, WeightStats> absoluteStats = {
      '~439kg': WeightStats(),
      '440~459kg': WeightStats(),
      '460~479kg': WeightStats(),
      '480~499kg': WeightStats(),
      '500~519kg': WeightStats(),
      '520kg~': WeightStats(),
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

            // --- 増減別の集計 ---
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

            // [追加] 絶対値の階級別集計ロジック (v.1.1)
            String absCategory;
            if (weight < 440) {
              absCategory = '~439kg';
            } else if (weight < 460) {
              absCategory = '440~459kg';
            } else if (weight < 480) {
              absCategory = '460~479kg';
            } else if (weight < 500) {
              absCategory = '480~499kg';
            } else if (weight < 520) {
              absCategory = '500~519kg';
            } else {
              absCategory = '520kg~';
            }

            absoluteStats[absCategory]!.total += 1;
            if (isWin) absoluteStats[absCategory]!.win += 1;
            if (isPlace) absoluteStats[absCategory]!.place += 1;
            if (isShow) absoluteStats[absCategory]!.show += 1;
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
      // [追加] 戻り値に絶対値の集計結果を含める (v.1.1)
      absoluteStats: absoluteStats,
    );
  }
}

// 6. 過去上位3頭の抽出用
// [修正] 過去上位3頭のデータ構造に性齢、タイム、上がり、コーナー通過順位を追加 (v.1.0)
class PastTopHorse {
  final int rank;
  final String frameNumber;
  final String horseNumber;
  final String horseName;
  final String popularity;
  final String sexAndAge;
  final String time;
  final String agari;
  final String cornerRanking;

  PastTopHorse({
    required this.rank,
    required this.frameNumber,
    required this.horseNumber,
    required this.horseName,
    required this.popularity,
    required this.sexAndAge,
    required this.time,
    required this.agari,
    required this.cornerRanking,
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
          // [追加] 抽出時に性齢、タイム、上がり、コーナー順位の値をセット (v.1.0)
          topHorses.add(PastTopHorse(
            rank: rank,
            frameNumber: h.frameNumber,
            horseNumber: h.horseNumber,
            horseName: h.horseName,
            popularity: h.popularity,
            sexAndAge: h.sexAndAge,
            time: h.time,
            agari: h.agari,
            cornerRanking: h.cornerRanking,
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

// 8. compute()によるバックグラウンド実行用のラッパー
// [追加] 各アナライザーの結果をまとめてcompute()の戻り値として返すためのクラス (v.13.40.5)
class VolatilityAnalysisBundle {
  final VolatilityResult volatilityResult;
  final PayoutAnalysisResult payoutResult;
  final PopularityAnalysisResult popularityResult;
  final FrameAnalysisResult frameResult;
  final LegStyleAnalysisResult legStyleResult;
  final HorseWeightAnalysisResult horseWeightResult;
  final List<PastRaceTop3Result> pastTop3Result;
  final LapTimeAnalysisResult? lapTimeResult;

  VolatilityAnalysisBundle({
    required this.volatilityResult,
    required this.payoutResult,
    required this.popularityResult,
    required this.frameResult,
    required this.legStyleResult,
    required this.horseWeightResult,
    required this.pastTop3Result,
    required this.lapTimeResult,
  });
}

// [追加] 8種類の解析処理をまとめて実行するトップレベル関数。
// compute()に渡すことで別Isolateで実行し、UIスレッドのフリーズを防ぐ (v.13.40.5)
VolatilityAnalysisBundle runVolatilityAnalysis(List<RaceResult> pastRaces) {
  return VolatilityAnalysisBundle(
    volatilityResult: VolatilityAnalyzer().analyze(pastRaces),
    payoutResult: PayoutAnalyzer().analyze(pastRaces),
    popularityResult: PopularityAnalyzer().analyze(pastRaces),
    frameResult: FrameAnalyzer().analyze(pastRaces),
    legStyleResult: LegStyleAnalyzer().analyze(pastRaces),
    horseWeightResult: HorseWeightAnalyzer().analyze(pastRaces),
    pastTop3Result: PastTopHorsesAnalyzer().analyze(pastRaces),
    lapTimeResult: LapTimeAnalyzer().analyze(pastRaces),
  );
}