// lib/logic/analysis/inward_drift_end_resolver.dart
// [追加] 展開シミュ骨格整理Step1: 内ラチ側(直線コースは外ラチ側)への寄せを
// どこまで続けるか(寄せの終点)をコースデータから決める純粋ロジック (v.2026.10.9+26100905)

import 'package:hetaumakeiba_v2/models/elevation_model.dart';

/// 寄せる向き。
enum LaneDriftDirection {
  /// 内ラチ側へ寄せる(通常)
  inward,

  /// 外ラチ側へ寄せる(コーナーの無い直線コース)
  outward,
}

/// 寄せの向きと終点。
class LaneDriftPlan {
  final LaneDriftDirection direction;

  /// 寄せをやめる地点(スタートからの距離 m)。
  final double endDistanceFromStart;

  const LaneDriftPlan({
    required this.direction,
    required this.endDistanceFromStart,
  });
}

class InwardDriftEndResolver {
  InwardDriftEndResolver._();

  /// 引き込み線の線分の向きの変化の合計がこの角度(度)以上なら、
  /// 引き込み線がカーブしているとみなし、合流点を終点にする。
  static const double curvedApproachTurnDegrees = 30.0;

  /// コースデータが無いときの終点(レース距離に対する割合)。
  static const double fallbackEndRatio = 0.25;

  /// 寄せの向きと終点を決める。
  /// - コーナー区間(名前が corner_ で始まる)が無い: 外ラチ側へ、レース全体
  /// - 引き込み線がカーブしている: 内ラチ側へ、合流点まで
  /// - それ以外: 内ラチ側へ、最初のコーナー区間の開始地点まで
  static LaneDriftPlan resolve(
    RaceCourseData? course, {
    required double raceDistance,
  }) {
    if (course == null) {
      return LaneDriftPlan(
        direction: LaneDriftDirection.inward,
        endDistanceFromStart: raceDistance * fallbackEndRatio,
      );
    }

    CourseSection? firstCorner;
    for (final section in course.sections) {
      if (section.name.startsWith('corner_')) {
        firstCorner = section;
        break;
      }
    }
    if (firstCorner == null) {
      return LaneDriftPlan(
        direction: LaneDriftDirection.outward,
        endDistanceFromStart: raceDistance,
      );
    }

    final List<CourseApproach>? approach = course.approachPath;
    if (approach != null &&
        approach.isNotEmpty &&
        approachTurnDegrees(approach) >= curvedApproachTurnDegrees) {
      return LaneDriftPlan(
        direction: LaneDriftDirection.inward,
        endDistanceFromStart: approachLength(approach),
      );
    }

    return LaneDriftPlan(
      direction: LaneDriftDirection.inward,
      endDistanceFromStart: firstCorner.startDistance,
    );
  }

  /// 引き込み線の長さ(m)。
  static double approachLength(List<CourseApproach> approach) {
    double total = 0.0;
    for (final segment in approach) {
      total += segment.distance;
    }
    return total;
  }

  /// 引き込み線の線分どうしの向きの変化の合計(度)。
  static double approachTurnDegrees(List<CourseApproach> approach) {
    double total = 0.0;
    for (int i = 1; i < approach.length; i++) {
      final double diff =
          ((approach[i].angle - approach[i - 1].angle + 180.0) % 360.0) -
              180.0;
      total += diff.abs();
    }
    return total;
  }
}
