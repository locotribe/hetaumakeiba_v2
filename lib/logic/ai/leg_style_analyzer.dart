// lib/logic/ai/leg_style_analyzer.dart

import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';

class LegStyleProfile {
  final String primaryStyle;
  final Map<String, double> styleDistribution; // 脚質分布（頻度 %）
  final Map<String, double> styleWinRates;     // ★追加: 脚質別勝率（質 %）

  LegStyleProfile({
    required this.primaryStyle,
    required this.styleDistribution,
    this.styleWinRates = const {}, // ★追加: 既存コードへの影響を防ぐためデフォルト値を設定
  });

  Map<String, dynamic> toJson() {
    return {
      'primaryStyle': primaryStyle,
      'styleDistribution': styleDistribution,
      'styleWinRates': styleWinRates, // ★追加
    };
  }

  factory LegStyleProfile.fromJson(Map<String, dynamic> json) {
    final Map<String, double> distribution = (json['styleDistribution'] as Map<String, dynamic>).map(
          (key, value) => MapEntry(key, (value as num).toDouble()),
    );

    // ★追加: 古いJSONデータには styleWinRates がない可能性があるため、nullチェックを行う
    final Map<String, double> winRates = json['styleWinRates'] != null
        ? (json['styleWinRates'] as Map<String, dynamic>).map(
          (key, value) => MapEntry(key, (value as num).toDouble()),
    )
        : {};

    return LegStyleProfile(
      primaryStyle: json['primaryStyle'] as String,
      styleDistribution: distribution,
      styleWinRates: winRates,
    );
  }
}

class _RaceActionProfile {
  final double startPositionRate;
  final double finalPositionRate;
  final double positionGain;
  final double makuriIndex;
  final double longMakuriIndex;
  final double agariTime;

  _RaceActionProfile({
    required this.startPositionRate,
    required this.finalPositionRate,
    required this.positionGain,
    required this.makuriIndex,
    required this.longMakuriIndex,
    required this.agariTime,
  });
}

class LegStyleAnalyzer {
  static LegStyleProfile getRunningStyle(List<HorseRaceRecord> records) {
    if (records.isEmpty) {
      return LegStyleProfile(primaryStyle: "不明", styleDistribution: {}, styleWinRates: {});
    }

    // 脚質判定結果と、そのレースでの着順をペアで保持するリスト
    final List<Map<String, dynamic>> validRaceData = [];

    for (final record in records) {
      final positions = record.cornerPassage
          .split('-')
          .map((p) => int.tryParse(p))
          .toList();
      final horseCount = int.tryParse(record.numberOfHorses);
      final agari = double.tryParse(record.agari);

      if (horseCount == null ||
          horseCount == 0 ||
          agari == null ||
          positions.length < 2 ||
          positions.contains(null)) {
        continue;
      }

      double startPositionRate = 0;
      double finalPositionRate = 0;
      double positionGain = 0;
      double makuriIndex = 0;
      double longMakuriIndex = 0;

      if (positions.length == 4) {
        startPositionRate = positions[0]! / horseCount;
        finalPositionRate = positions[3]! / horseCount;
        positionGain = (positions[0]! - positions[3]!) / horseCount;
        makuriIndex = (positions[2]! - positions[3]!) / horseCount;
        longMakuriIndex = (positions[1]! - positions[3]!) / horseCount;
      } else if (positions.length == 3) {
        startPositionRate = positions[0]! / horseCount;
        finalPositionRate = positions[2]! / horseCount;
        positionGain = (positions[0]! - positions[2]!) / horseCount;
        makuriIndex = (positions[1]! - positions[2]!) / horseCount;
      } else if (positions.length == 2) {
        startPositionRate = positions[0]! / horseCount;
        finalPositionRate = positions[1]! / horseCount;
        positionGain = (positions[0]! - positions[1]!) / horseCount;
      }

      final profile = _RaceActionProfile(
        startPositionRate: startPositionRate,
        finalPositionRate: finalPositionRate,
        positionGain: positionGain,
        makuriIndex: makuriIndex,
        longMakuriIndex: longMakuriIndex,
        agariTime: agari,
      );

      final style = _getTentativeLegStyle(profile, positions.length);
      final rank = int.tryParse(record.rank);

      validRaceData.add({
        'style': style,
        'rank': rank,
      });
    }

    if (validRaceData.isEmpty) {
      return LegStyleProfile(primaryStyle: "不明", styleDistribution: {}, styleWinRates: {});
    }

    final Map<String, int> styleCounts = {};
    final Map<String, int> styleWinCounts = {}; // 脚質ごとの勝利数

    for (final data in validRaceData) {
      final style = data['style'] as String;
      final rank = data['rank'] as int?;

      styleCounts[style] = (styleCounts[style] ?? 0) + 1;
      if (rank == 1) {
        styleWinCounts[style] = (styleWinCounts[style] ?? 0) + 1;
      }
    }

    final totalRaces = validRaceData.length;

    final Map<String, double> styleDistribution = {
      '逃げ': (styleCounts['逃げ'] ?? 0) / totalRaces,
      '先行': (styleCounts['先行'] ?? 0) / totalRaces,
      '差し': (styleCounts['差し'] ?? 0) / totalRaces,
      '追い込み': (styleCounts['追い込み'] ?? 0) / totalRaces,
    };

    // ★追加: 勝率計算 (その脚質をとった回数のうち、勝った割合)
    final Map<String, double> styleWinRates = {};
    styleCounts.forEach((style, count) {
      if (count > 0) {
        styleWinRates[style] = (styleWinCounts[style] ?? 0) / count;
      } else {
        styleWinRates[style] = 0.0;
      }
    });

    String primaryStyle;
    final makuriRate = (styleCounts['マクリ'] ?? 0) / totalRaces;

    if (makuriRate > 0.3) {
      primaryStyle = 'マクリ';
    } else {
      final topStyleEntry = styleDistribution.entries
          .reduce((a, b) => a.value > b.value ? a : b);

      final hasFrontStyle = (styleDistribution['逃げ']! + styleDistribution['先行']!) > 0;
      final hasBackStyle = (styleDistribution['差し']! + styleDistribution['追い込み']!) > 0;

      if (topStyleEntry.value < 0.5 && hasFrontStyle && hasBackStyle) {
        primaryStyle = '自在';
      } else {
        primaryStyle = topStyleEntry.key;
      }
    }

    return LegStyleProfile(
      primaryStyle: primaryStyle,
      styleDistribution: styleDistribution,
      styleWinRates: styleWinRates, // ★追加
    );
  }

  /// 1レース分の脚質を判定して返す（外部呼び出し用） - 変更なし
  static String analyzeSingleRaceStyle(HorseRaceRecord record) {
    final positions = record.cornerPassage
        .split('-')
        .map((p) => int.tryParse(p))
        .toList();
    final horseCount = int.tryParse(record.numberOfHorses);
    final agari = double.tryParse(record.agari);

    if (horseCount == null ||
        horseCount == 0 ||
        agari == null ||
        positions.length < 2 ||
        positions.contains(null)) {
      return "不明";
    }

    double startPositionRate = 0;
    double finalPositionRate = 0;
    double positionGain = 0;
    double makuriIndex = 0;
    double longMakuriIndex = 0;

    if (positions.length == 4) {
      startPositionRate = positions[0]! / horseCount;
      finalPositionRate = positions[3]! / horseCount;
      positionGain = (positions[0]! - positions[3]!) / horseCount;
      makuriIndex = (positions[2]! - positions[3]!) / horseCount;
      longMakuriIndex = (positions[1]! - positions[3]!) / horseCount;
    } else if (positions.length == 3) {
      startPositionRate = positions[0]! / horseCount;
      finalPositionRate = positions[2]! / horseCount;
      positionGain = (positions[0]! - positions[2]!) / horseCount;
      makuriIndex = (positions[1]! - positions[2]!) / horseCount;
    } else if (positions.length == 2) {
      startPositionRate = positions[0]! / horseCount;
      finalPositionRate = positions[1]! / horseCount;
      positionGain = (positions[0]! - positions[1]!) / horseCount;
    }

    final cornerCount = positions.length;

    if (cornerCount == 4) {
      if (longMakuriIndex > 0.4 || makuriIndex > 0.3) {
        return 'マクリ';
      }
    }

    if (startPositionRate <= 0.15 && finalPositionRate <= 0.2) {
      return '逃げ';
    }
    if (startPositionRate <= 0.4 && positionGain.abs() < 0.2) {
      return '先行';
    }
    if (finalPositionRate >= 0.8 && agari <= 34.5) {
      return '追い込み';
    }
    if (positionGain > 0.15) {
      return '差し';
    }

    return '先行';
  }

  // 内部ロジック - 変更なし
  static String _getTentativeLegStyle(_RaceActionProfile profile, int cornerCount) {
    if (cornerCount == 4) {
      if (profile.longMakuriIndex > 0.4 || profile.makuriIndex > 0.3) {
        return 'マクリ';
      }
    }

    if (profile.startPositionRate <= 0.15 && profile.finalPositionRate <= 0.2) {
      return '逃げ';
    }
    if (profile.startPositionRate <= 0.4 && profile.positionGain.abs() < 0.2) {
      return '先行';
    }
    if (profile.finalPositionRate >= 0.8 && profile.agariTime <= 34.5) {
      return '追い込み';
    }
    if (profile.positionGain > 0.15) {
      return '差し';
    }

    return '先行';
  }
}