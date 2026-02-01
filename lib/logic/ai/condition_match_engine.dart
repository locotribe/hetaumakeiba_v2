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

  MatchupBrief({
    required this.opponentName,
    required this.opponentHorseId,
    required this.myRank,
    required this.opponentRank,
    required this.isWin,
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
  /// 全出走馬の過去成績から、レースIDをキーとした出走馬マップを作成
  static Map<String, List<PredictionHorseDetail>> buildRaceParticipantMap(List<PredictionHorseDetail> allHorses) {
    // 実際に計算で利用するのは詳細な過去成績だが、
    // まずは今回の出走メンバーがどのレースにいたかを特定するためのインデックスが必要
    return {}; // 実装は分析メソッド内で行う
  }

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

      // レース間隔 (前走データが必要なため、ここではロジックの枠組みのみ定義)
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
          case '逃げ':
            shortStyle = '逃';
            break;
          case '先行':
            shortStyle = '先';
            break;
          case '差し':
            shortStyle = '差';
            break;
          case '追い込み':
            shortStyle = '追';
            break;
          case 'マクリ':
            shortStyle = 'マ';
            break;
        }
        legStyleCounts[shortStyle] = (legStyleCounts[shortStyle] ?? 0) + 1;
      }

      // 2. 回り集計
      // 開催地名から数字を除去 (例: "2東京4" -> "東京")
      final venueName = record.venue.replaceAll(RegExp(r'[0-9]'), '');
      if (venueName.isNotEmpty) {
        String direction = '右'; // デフォルト
        if (['東京', '中京', '新潟'].contains(venueName)) {
          direction = '左';
        }
        directionCounts[direction] = (directionCounts[direction] ?? 0) + 1;
      }

      // 3. 馬場状態集計
      // (例: "良", "稍重", "重", "不良")
      final condition = record.trackCondition;
      if (condition.isNotEmpty) {
        String shortCond = condition;
        if (condition == '稍重') shortCond = '稍';
        if (condition == '不良') shortCond = '不';
        conditionCounts[shortCond] = (conditionCounts[shortCond] ?? 0) + 1;
      }
    }

    // 文字列生成ヘルパー
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

    for (var opponent in currentRaceMembers) {
      if (opponent.horseId == myHorseId) continue;

      final opponentRecords = allHorsesPastRecords[opponent.horseId] ?? [];
      try {
        final opponentPastRecord = opponentRecords.firstWhere((r) => r.raceId == targetRaceId);

        final myRankInt = int.tryParse(myRank) ?? 999;
        final opRankInt = int.tryParse(opponentPastRecord.rank) ?? 999;

        matchups.add(MatchupBrief(
          opponentName: opponent.horseName,
          opponentHorseId: opponent.horseId,
          myRank: myRank,
          opponentRank: opponentPastRecord.rank,
          isWin: myRankInt < opRankInt,
        ));
      } catch (_) {
        // 対戦なし
      }
    }

    if (matchups.isEmpty) return null;
    return RaceMatchupContext(raceId: targetRaceId, matchups: matchups);
  }

  /// 【追加】範囲表示用の文字列を生成するヘルパー
  /// minとmaxが同じ場合は単一の値を返す
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