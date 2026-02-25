// lib/logic/ai/condition_match_engine.dart

import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_race_data.dart';
import 'package:hetaumakeiba_v2/logic/race_interval_analyzer.dart';
import 'package:hetaumakeiba_v2/logic/ai/leg_style_analyzer.dart';

/// 特定の着順グループにおける数値範囲を保持するモデル
class ConditionRange {
  double? minDistance;
  double? maxDistance;
  int? minWeight;
  int? maxWeight;
  double? minCarriedWeight;
  double? maxCarriedWeight;
  int? minInterval;
  int? maxInterval;

  ConditionRange();
}

/// 対戦成績の簡易情報を保持するモデル
class MatchupBrief {
  final String opponentName;
  final String opponentHorseId;
  final String myRank;
  final String opponentRank;
  final bool isWin;

  // 新規追加フィールド
  final String margin;              // 着差 (例: "1/2", "0.1"など)
  final String timeDiff;            // タイム差 (例: "-0.2", "+0.5")
  final String opponentHorseNumber; // 相手の馬番
  final String relativeGate;        // 枠順比較 (例: "内枠", "外枠", "同枠")

  MatchupBrief({
    required this.opponentName,
    required this.opponentHorseId,
    required this.myRank,
    required this.opponentRank,
    required this.isWin,
    this.margin = '-',
    this.timeDiff = '-',
    this.opponentHorseNumber = '-',
    this.relativeGate = '-',
  });
}

/// 各レースにおける対戦情報を保持するモデル
class RaceMatchupContext {
  final String raceId;
  final List<MatchupBrief> matchups;

  RaceMatchupContext({required this.raceId, required this.matchups});
}

/// 好走条件分析のための計算エンジン
class ConditionMatchEngine {

  /// 特定の馬の過去成績を着順ごとに分類し、統計と対戦情報を抽出する
  static Map<String, List<HorseRaceRecord>> groupRecordsByRank(List<HorseRaceRecord> records) {
    final Map<String, List<HorseRaceRecord>> grouped = {
      '1着': [],
      '2着': [],
      '3着': [],
      '4着以下': [],
    };

    for (var record in records) {
      final rank = int.tryParse(record.rank);
      if (rank == 1) {
        grouped['1着']!.add(record);
      } else if (rank == 2) {
        grouped['2着']!.add(record);
      } else if (rank == 3) {
        grouped['3着']!.add(record);
      } else {
        grouped['4着以下']!.add(record);
      }
    }
    return grouped;
  }

  /// 過去成績のリストから数値範囲を算出する
  static ConditionRange calculateRange(List<HorseRaceRecord> records, String currentRaceDate) {
    final range = ConditionRange();
    if (records.isEmpty) return range;

    for (var record in records) {
      // 距離の抽出 (例: "芝2000" -> 2000)
      final distMatch = RegExp(r'\d+').firstMatch(record.distance);
      if (distMatch != null) {
        final dist = double.tryParse(distMatch.group(0)!);
        if (dist != null) {
          range.minDistance = range.minDistance == null ? dist : (dist < range.minDistance! ? dist : range.minDistance);
          range.maxDistance = range.maxDistance == null ? dist : (dist > range.maxDistance! ? dist : range.maxDistance);
        }
      }

      // 馬体重の抽出 (例: "480(-2)" -> 480)
      final weightMatch = RegExp(r'\d+').firstMatch(record.horseWeight);
      if (weightMatch != null) {
        final w = int.tryParse(weightMatch.group(0)!);
        if (w != null) {
          range.minWeight = range.minWeight == null ? w : (w < range.minWeight! ? w : range.minWeight);
          range.maxWeight = range.maxWeight == null ? w : (w > range.maxWeight! ? w : range.maxWeight);
        }
      }

      // 斤量
      final cw = double.tryParse(record.carriedWeight);
      if (cw != null) {
        range.minCarriedWeight = range.minCarriedWeight == null ? cw : (cw < range.minCarriedWeight! ? cw : range.minCarriedWeight);
        range.maxCarriedWeight = range.maxCarriedWeight == null ? cw : (cw > range.maxCarriedWeight! ? cw : range.maxCarriedWeight);
      }
    }

    return range;
  }

  /// レース詳細を集計して表示用のサマリー文字列（脚質、回り、馬場）を生成する
  static Map<String, String> calculateSummaries(List<HorseRaceRecord> records) {
    if (records.isEmpty) {
      return {
        'legStyle': '',
        'direction': '',
        'trackCondition': '',
      };
    }

    final Map<String, int> legStyleCounts = {};
    final Map<String, int> directionCounts = {};
    final Map<String, int> conditionCounts = {};

    for (var record in records) {
      // 1. 脚質集計
      final style = LegStyleAnalyzer.analyzeSingleRaceStyle(record);
      if (style != '不明') {
        String shortStyle = style;
        switch (style) {
          case '逃げ': shortStyle = '逃'; break;
          case '先行': shortStyle = '先'; break;
          case '差し': shortStyle = '差'; break;
          case '追い込み': shortStyle = '追'; break;
          case 'マクリ': shortStyle = 'マ'; break;
        }
        legStyleCounts[shortStyle] = (legStyleCounts[shortStyle] ?? 0) + 1;
      }

      // 2. 回り集計
      final venueName = record.venue.replaceAll(RegExp(r'[0-9]'), '');
      if (venueName.isNotEmpty) {
        String direction = '右'; // デフォルト
        if (['東京', '中京', '新潟'].contains(venueName)) {
          direction = '左';
        }
        directionCounts[direction] = (directionCounts[direction] ?? 0) + 1;
      }

      // 3. 馬場状態集計
      final condition = record.trackCondition;
      if (condition.isNotEmpty) {
        String shortCond = condition;
        if (condition == '稍重') shortCond = '稍';
        if (condition == '不良') shortCond = '不';
        conditionCounts[shortCond] = (conditionCounts[shortCond] ?? 0) + 1;
      }
    }

    String buildSummary(Map<String, int> counts, List<String> order) {
      final List<String> parts = [];
      for (var key in order) {
        if (counts.containsKey(key) && counts[key]! > 0) {
          parts.add('$key(${counts[key]})');
        }
      }
      return parts.join(' ');
    }

    return {
      'legStyle': buildSummary(legStyleCounts, ['逃', '先', '差', '追', 'マ']),
      'direction': buildSummary(directionCounts, ['右', '左']),
      'trackCondition': buildSummary(conditionCounts, ['良', '稍', '重', '不']),
    };
  }

  /// 特定のレースにおける今回の出走メンバーとの対戦成績をスキャンする
  static RaceMatchupContext? scanMatchups({
    required String targetRaceId,
    required String myHorseId,
    required String myRank,
    required List<PredictionHorseDetail> currentRaceMembers,
    required Map<String, List<HorseRaceRecord>> allHorsesPastRecords,
  }) {
    final List<MatchupBrief> matchups = [];

    // 自分の過去走データを取得（タイム比較用）
    HorseRaceRecord? myRecord;
    try {
      final myRecords = allHorsesPastRecords[myHorseId] ?? [];
      myRecord = myRecords.firstWhere((r) => r.raceId == targetRaceId);
    } catch (_) {
      // 自分のデータが見つからない場合はタイム差計算不可
    }

    for (var opponent in currentRaceMembers) {
      if (opponent.horseId == myHorseId) continue;

      final opponentRecords = allHorsesPastRecords[opponent.horseId] ?? [];
      try {
        final opponentPastRecord = opponentRecords.firstWhere((r) => r.raceId == targetRaceId);

        final myRankInt = int.tryParse(myRank) ?? 999;
        final opRankInt = int.tryParse(opponentPastRecord.rank) ?? 999;

        // --- 追加計算ロジック ---

        // 1. タイム差計算
        String timeDiffStr = '-';
        if (myRecord != null) {
          final myTime = _parseTime(myRecord.time);
          final opTime = _parseTime(opponentPastRecord.time);
          if (myTime != null && opTime != null) {
            final diff = myTime - opTime;
            // 自分が勝った場合、タイムは自分の方が小さいのでマイナスになるはず
            // 表示形式: "-0.2" (0.2秒勝ち), "+0.5" (0.5秒負け)
            final sign = diff > 0 ? '+' : '';
            timeDiffStr = '$sign${diff.toStringAsFixed(1)}';
          }
        }

        // 2. 枠順比較
        String relativeGateStr = '-';
        if (myRecord != null) {
          final myFrame = int.tryParse(myRecord.frameNumber);
          final opFrame = int.tryParse(opponentPastRecord.frameNumber);
          if (myFrame != null && opFrame != null) {
            if (myFrame < opFrame) {
              relativeGateStr = '内枠';
            } else if (myFrame > opFrame) {
              relativeGateStr = '外枠';
            } else {
              relativeGateStr = '同枠';
            }
          }
        }

        matchups.add(MatchupBrief(
          opponentName: opponent.horseName,
          opponentHorseId: opponent.horseId,
          myRank: myRank,
          opponentRank: opponentPastRecord.rank,
          isWin: myRankInt < opRankInt,
          // 新規項目の設定
          margin: opponentPastRecord.margin.isNotEmpty ? opponentPastRecord.margin : '-',
          timeDiff: timeDiffStr,
          opponentHorseNumber: opponentPastRecord.horseNumber,
          relativeGate: relativeGateStr,
        ));
      } catch (_) {
        // 対戦なし
      }
    }

    if (matchups.isEmpty) return null;
    return RaceMatchupContext(raceId: targetRaceId, matchups: matchups);
  }

  /// タイム文字列（"1:33.4" または "58.2"）を秒（double）に変換するヘルパー
  static double? _parseTime(String timeStr) {
    if (timeStr.isEmpty) return null;
    try {
      final parts = timeStr.split(':');
      if (parts.length == 2) {
        // 分:秒.ミリ秒
        final min = double.parse(parts[0]);
        final sec = double.parse(parts[1]);
        return min * 60 + sec;
      } else {
        // 秒.ミリ秒
        return double.parse(timeStr);
      }
    } catch (_) {
      return null;
    }
  }

  /// 【追加】範囲表示用の文字列を生成するヘルパー
  static String formatRange(num? min, num? max, String unit) {
    if (min == null || max == null) {
      return '-';
    }
    if (min == max) {
      return '$min$unit';
    } else {
      return '$min$unit〜$max$unit';
    }
  }
}