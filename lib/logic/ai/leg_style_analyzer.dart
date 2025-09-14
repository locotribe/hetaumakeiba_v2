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
    String primaryStyle = styleCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    final totalRaces = tentativeStyles.length;
    final styleDistribution = styleCounts
        .map((key, value) => MapEntry(key, value / totalRaces));

    // 「自在」判定
    final topStyleRate = styleCounts.values.reduce((a, b) => a > b ? a : b) / totalRaces;
    final hasFrontStyle = styleCounts.containsKey('逃げ') || styleCounts.containsKey('先行');
    final hasBackStyle = styleCounts.containsKey('差し') || styleCounts.containsKey('追い込み');

    if (topStyleRate < 0.5 && hasFrontStyle && hasBackStyle) {
      primaryStyle = '自在';
    } else if (totalRaces <= 2 && topStyleRate < 1.0) {
      // キャリアが浅い場合は安易に決めつけず「自在」とする
      primaryStyle = '自在';
    }

    return LegStyleProfile(
      primaryStyle: primaryStyle,
      styleDistribution: styleDistribution,
    );
  }

  // 1レースごとの暫定脚質を判定するヘルパー
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