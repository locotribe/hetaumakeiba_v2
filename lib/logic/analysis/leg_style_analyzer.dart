// lib/logic/analysis/leg_style_analyzer.dart

import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/logic/analysis/leg_style_classifier.dart'; // [追加] 脚質の基底4分類を共通関数へ委譲 (v.2026.9.26+26092605)

class LegStyleProfile {
  final String primaryStyle;
  final Map<String, double> styleDistribution; // 脚質分布（頻度 %）
  final Map<String, double> styleWinRates;     // ★追加: 脚質別勝率（質 %）
  // [追加] 脚質別着度数 [1着,2着,3着,着外]（マクリ含む・中止/除外は着外に合算） (v.2026.9.24+26092403)
  final Map<String, List<int>> styleRecordCounts;

  LegStyleProfile({
    required this.primaryStyle,
    required this.styleDistribution,
    this.styleWinRates = const {}, // ★追加: 既存コードへの影響を防ぐためデフォルト値を設定
    // [追加] 既存コード・旧キャッシュへの影響を防ぐためデフォルト値を設定 (v.2026.9.24+26092403)
    this.styleRecordCounts = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'primaryStyle': primaryStyle,
      'styleDistribution': styleDistribution,
      'styleWinRates': styleWinRates, // ★追加
      'styleRecordCounts': styleRecordCounts, // [追加] (v.2026.9.24+26092403)
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

    // [追加] 古いJSONデータには styleRecordCounts がない可能性があるため、nullチェックを行う (v.2026.9.24+26092403)
    final Map<String, List<int>> recordCounts = json['styleRecordCounts'] != null
        ? (json['styleRecordCounts'] as Map<String, dynamic>).map(
          (key, value) => MapEntry(
        key,
        (value as List).map((e) => (e as num).toInt()).toList(),
      ),
    )
        : {};

    return LegStyleProfile(
      primaryStyle: json['primaryStyle'] as String,
      styleDistribution: distribution,
      styleWinRates: winRates,
      styleRecordCounts: recordCounts, // [追加] (v.2026.9.24+26092403)
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
      return LegStyleProfile(primaryStyle: "不明", styleDistribution: {}, styleWinRates: {}, styleRecordCounts: {});
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

      final style = _getTentativeLegStyle(profile, positions.length, record.cornerPassage, horseCount);
      final rank = int.tryParse(record.rank);

      validRaceData.add({
        'style': style,
        'rank': rank,
      });
    }

    if (validRaceData.isEmpty) {
      return LegStyleProfile(primaryStyle: "不明", styleDistribution: {}, styleWinRates: {}, styleRecordCounts: {});
    }

    final Map<String, int> styleCounts = {};
    final Map<String, int> styleWinCounts = {}; // 脚質ごとの勝利数
    // [追加] 脚質ごとの着度数 [1着,2着,3着,着外]。着順が数値でない場合(中止・除外等)は着外に合算する (v.2026.9.24+26092403)
    final Map<String, List<int>> styleRecordCounts = {};

    for (final data in validRaceData) {
      final style = data['style'] as String;
      final rank = data['rank'] as int?;

      styleCounts[style] = (styleCounts[style] ?? 0) + 1;
      if (rank == 1) {
        styleWinCounts[style] = (styleWinCounts[style] ?? 0) + 1;
      }

      // [追加] 着度数の集計。1着/2着/3着/着外(4着以下・中止・除外等)を数える (v.2026.9.24+26092403)
      final bucket = styleRecordCounts.putIfAbsent(style, () => [0, 0, 0, 0]);
      if (rank == 1) {
        bucket[0] += 1;
      } else if (rank == 2) {
        bucket[1] += 1;
      } else if (rank == 3) {
        bucket[2] += 1;
      } else {
        bucket[3] += 1;
      }
    }

    final totalRaces = validRaceData.length;

    // [修正] マクリ判定のレースが分母(totalRaces)に含まれるため4脚質の合計が
    // 100%にならず、その分だけ前寄りに計算されていた問題を修正。
    // 4脚質の実数合計で正規化する (v.2026.9.18+26091802)
    final int styleTotalCount = (styleCounts['逃げ'] ?? 0) +
        (styleCounts['先行'] ?? 0) +
        (styleCounts['差し'] ?? 0) +
        (styleCounts['追込'] ?? 0);
    // 全レースがマクリ判定の場合は0除算になるためtotalRacesにフォールバックする
    // (この場合4脚質は全て0となり、primaryStyleはマクリ判定側で決まる)
    final int styleDenominator =
        styleTotalCount > 0 ? styleTotalCount : totalRaces;

    final Map<String, double> styleDistribution = {
      '逃げ': (styleCounts['逃げ'] ?? 0) / styleDenominator,
      '先行': (styleCounts['先行'] ?? 0) / styleDenominator,
      '差し': (styleCounts['差し'] ?? 0) / styleDenominator,
      '追込': (styleCounts['追込'] ?? 0) / styleDenominator,
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

      // [修正] 自在は前後どちらかが僅少なら付けない。前(逃げ+先行)・後(差し+追込)の両シェアが0.3以上のときのみ自在 (v.2026.9.26+26092606)
      final frontShare = styleDistribution['逃げ']! + styleDistribution['先行']!;
      final backShare = styleDistribution['差し']! + styleDistribution['追込']!;

      if (topStyleEntry.value < 0.5 && frontShare >= 0.3 && backShare >= 0.3) {
        primaryStyle = '自在';
      } else {
        primaryStyle = topStyleEntry.key;
      }
    }

    return LegStyleProfile(
      primaryStyle: primaryStyle,
      styleDistribution: styleDistribution,
      styleWinRates: styleWinRates, // ★追加
      styleRecordCounts: styleRecordCounts, // [追加] (v.2026.9.24+26092403)
    );
  }

  /// 1レース分の脚質を判定して返す（外部呼び出し用）
  // [修正] マクリ判定（4コーナー）は温存し、基底4分類は共通関数 classifyLegStyle へ委譲 (v.2026.9.26+26092605)
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

    // マクリ判定用の指標（4コーナーのときのみ算出）
    if (positions.length == 4) {
      final makuriIndex = (positions[2]! - positions[3]!) / horseCount;
      final longMakuriIndex = (positions[1]! - positions[3]!) / horseCount;
      if (longMakuriIndex > 0.4 || makuriIndex > 0.3) {
        return 'マクリ';
      }
    }

    return classifyLegStyle(record.cornerPassage, horseCount);
  }

  // [修正] マクリ判定（4コーナー）は温存し、基底4分類は共通関数 classifyLegStyle へ委譲。start/final/positionGain/agari による旧カスケードは廃止 (v.2026.9.26+26092605)
  static String _getTentativeLegStyle(
      _RaceActionProfile profile, int cornerCount, String cornerStr, int fieldSize) {
    if (cornerCount == 4) {
      if (profile.longMakuriIndex > 0.4 || profile.makuriIndex > 0.3) {
        return 'マクリ';
      }
    }
    return classifyLegStyle(cornerStr, fieldSize);
  }
}
