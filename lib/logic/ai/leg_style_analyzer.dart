// lib/logic/ai/leg_style_analyzer.dart

import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';

class LegStyleProfile {
  final String primaryStyle;
  final Map<String, double> styleDistribution;

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
    final Map<String, double> distribution = (json['styleDistribution'] as Map<String, dynamic>).map(
          (key, value) => MapEntry(key, (value as num).toDouble()),
    );
    return LegStyleProfile(
      primaryStyle: json['primaryStyle'] as String,
      styleDistribution: distribution,
    );
  }
}

class _RaceActionProfile {
  final double startPositionRate; // 1コーナーの相対的な位置取り
  final double finalPositionRate; // 4コーナーの相対的な位置取り
  final double positionGain; // 1コーナーから4コーナーにかけての順位変動
  final double makuriIndex; // 3コーナーから4コーナーへの順位変動
  final double longMakuriIndex; // 2コーナーから4コーナーへの順位変動
  final double agariTime; // 上がり3Fタイム

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
      return LegStyleProfile(primaryStyle: "不明", styleDistribution: {});
    }

    final List<String> tentativeStyles = [];
    final List<_RaceActionProfile> profiles = [];

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
      profiles.add(profile);
      tentativeStyles.add(_getTentativeLegStyle(profile, positions.length));
    }

    if (tentativeStyles.isEmpty) {
      return LegStyleProfile(primaryStyle: "不明", styleDistribution: {});
    }

    final Map<String, int> styleCounts = {};
    for (final style in tentativeStyles) {
      styleCounts[style] = (styleCounts[style] ?? 0) + 1;
    }

    final totalRaces = tentativeStyles.length;

    final Map<String, double> styleDistribution = {
      '逃げ': (styleCounts['逃げ'] ?? 0) / totalRaces,
      '先行': (styleCounts['先行'] ?? 0) / totalRaces,
      '差し': (styleCounts['差し'] ?? 0) / totalRaces,
      '追い込み': (styleCounts['追い込み'] ?? 0) / totalRaces,
    };

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
        primaryStyle = topStyleEntry.key; // 最も多い脚質
      }
    }

    return LegStyleProfile(
      primaryStyle: primaryStyle,
      styleDistribution: styleDistribution,
    );
  }

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