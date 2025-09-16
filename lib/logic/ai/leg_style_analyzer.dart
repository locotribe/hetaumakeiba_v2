// lib/logic/ai/leg_style_analyzer.dart

import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';

// 最終的な脚質判定結果を格納するクラス
class LegStyleProfile {
  final String primaryStyle; // 最も割合の高い主要な脚質
  final Map<String, double> styleDistribution; // 各脚質の割合を保持するマップ

  LegStyleProfile({
    required this.primaryStyle,
    required this.styleDistribution,
  });
  Map<String, dynamic> toJson() {
    return {
      'primaryStyle': primaryStyle,
      'styleDistribution': styleDistribution,
    };
  }

  factory LegStyleProfile.fromJson(Map<String, dynamic> json) {
    // JSONのvalueがdynamic型なので、doubleにキャストする
    final Map<String, double> distribution = (json['styleDistribution'] as Map<String, dynamic>).map(
          (key, value) => MapEntry(key, (value as num).toDouble()),
    );
    return LegStyleProfile(
      primaryStyle: json['primaryStyle'] as String,
      styleDistribution: distribution,
    );
  }
}

// 1レースごとの行動分析データ
class _RaceActionProfile {
  final double startPositionRate; // 1コーナーの相対的な位置取り
  final double finalPositionRate; // 4コーナーの相対的な位置取り
  final double positionGain; // 1コーナーから4コーナーにかけての順位変動
  final double makuriIndex; // 3コーナーから4コーナーへの順位変動
  final double agariTime; // 上がり3Fタイム

  _RaceActionProfile({
    required this.startPositionRate,
    required this.finalPositionRate,
    required this.positionGain,
    required this.makuriIndex,
    required this.agariTime,
  });
}

class LegStyleAnalyzer {
  // 新しい脚質判定メソッド
  static LegStyleProfile getRunningStyle(List<HorseRaceRecord> records) {
    if (records.isEmpty) {
      return LegStyleProfile(primaryStyle: "自在", styleDistribution: {});
    }

    final List<String> tentativeStyles = [];
    final List<_RaceActionProfile> profiles = [];

    // 1. 全レースのプロファイル化
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
          positions.length < 4 ||
          positions.contains(null)) {
        continue;
      }

      final profile = _RaceActionProfile(
        startPositionRate: positions[0]! / horseCount,
        finalPositionRate: positions[3]! / horseCount,
        positionGain: (positions[0]! - positions[3]!) / horseCount,
        makuriIndex: (positions[2]! - positions[3]!) / horseCount,
        agariTime: agari,
      );
      profiles.add(profile);
      tentativeStyles.add(_getTentativeLegStyle(profile));
    }

    if (tentativeStyles.isEmpty) {
      return LegStyleProfile(primaryStyle: "自在", styleDistribution: {});
    }

    // 2. 暫定脚質の集計
    final Map<String, int> styleCounts = {};
    for (final style in tentativeStyles) {
      styleCounts[style] = (styleCounts[style] ?? 0) + 1;
    }

    // 3. 最終判定
    final totalRaces = tentativeStyles.length;

    // 3a. 基本4脚質の分布図を作成
    final Map<String, double> styleDistribution = {
      '逃げ': (styleCounts['逃げ'] ?? 0) / totalRaces,
      '先行': (styleCounts['先行'] ?? 0) / totalRaces,
      '差し': (styleCounts['差し'] ?? 0) / totalRaces,
      '追い込み': (styleCounts['追い込み'] ?? 0) / totalRaces,
    };

    // 3b. 主要ラベル（キャッチコピー）を決定
    String primaryStyle;
    final makuriRate = (styleCounts['マクリ'] ?? 0) / totalRaces;

    if (makuriRate > 0.3) { // 例：マクリ率が30%以上なら最優先
      primaryStyle = 'マクリ';
    } else {
      // 最も出現率の高い基本脚質を見つける
      final topStyleEntry = styleDistribution.entries
          .reduce((a, b) => a.value > b.value ? a : b);

      // 「自在」の判定
      final hasFrontStyle = (styleDistribution['逃げ']! + styleDistribution['先行']!) > 0;
      final hasBackStyle = (styleDistribution['差し']! + styleDistribution['追い込み']!) > 0;

      if (topStyleEntry.value < 0.5 && hasFrontStyle && hasBackStyle) {
        primaryStyle = '自在';
      } else if (totalRaces <= 2 && topStyleEntry.value < 1.0) {
        primaryStyle = '自在'; // キャリアが浅い場合
      }
      else {
        primaryStyle = topStyleEntry.key; // 最も多い脚質
      }
    }

    return LegStyleProfile(
      primaryStyle: primaryStyle,
      styleDistribution: styleDistribution,
    );
  }

  // 1レースごとの暫定脚質を判定するヘルパー (変更なし)
  static String _getTentativeLegStyle(_RaceActionProfile profile) {
    // マクリ判定
    if (profile.makuriIndex > 0.3) {
      return 'マクリ';
    }
    // 逃げ判定
    if (profile.startPositionRate <= 0.15 && profile.finalPositionRate <= 0.2) {
      return '逃げ';
    }
    // 先行判定
    if (profile.startPositionRate <= 0.4 && profile.positionGain.abs() < 0.2) {
      return '先行';
    }
    // 追い込み判定
    if (profile.finalPositionRate >= 0.8 && profile.agariTime <= 34.5) {
      return '追い込み';
    }
    // 差し判定
    if (profile.positionGain > 0.15) {
      return '差し';
    }

    // デフォルトで先行と判定
    return '先行';
  }
}