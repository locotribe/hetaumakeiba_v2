// lib/logic/analysis/game_race_display.dart
// [追加] 展開シミュゲーム式移植Step4a: ゲーム式エンジンの結果を、今の再生(コース平面図)とステータス表に渡す形へ直す純粋ロジック。
// 設計は memory/展開シミュ_ゲーム式移植_設計書.md の7章 (v.2026.10.27+26102704)

import 'package:hetaumakeiba_v2/logic/analysis/game_race_engine.dart';

/// 再生用の1点(実時間の秒・ゴールまでの距離 m・横の位置)。
/// 横の位置は今の再生と同じ「laneRank」(1 ≒ 1m。内ラチは約 -9.5)。
class GameRaceTrackPoint {
  final double time;
  final double distanceFromGoal;
  final double laneRank;

  const GameRaceTrackPoint(this.time, this.distanceFromGoal, this.laneRank);
}

class GameRaceDisplay {
  GameRaceDisplay._();

  /// 内ラチにぴったり付いた馬(横の位置0)の laneRank。今の再生の内ラチ(約 -9.5)から馬の半分(約0.5m)外
  static const double laneRankAtRail = -9.0;

  /// 脚質の名前(0=逃げ〜3=追込)
  static const List<String> styleLabels = ['逃げ', '先行', '差し', '追込'];

  /// 画面のスタミナの値を作るときの、スタミナ指数が無い馬の値
  static const double defaultStaminaIndex = 0.35;

  /// 横の位置(コース幅の単位)を laneRank にする
  static double laneRankOf(double lane) =>
      lane * GameRaceEngine.courseWidthMeters + laneRankAtRail;

  /// 1回ぶんの位置の記録を、再生用の点(実時間)にする。[timeScale] はゲームの時間から実時間への倍率。
  static List<List<GameRaceTrackPoint>> trackPointsOf(
    GameRaceRunResult run, {
    required double distance,
    required double timeScale,
  }) {
    return [
      for (final trace in run.traces)
        [
          for (final p in trace)
            GameRaceTrackPoint(
              p.time * timeScale,
              distance - p.distance,
              laneRankOf(p.lane),
            )
        ]
    ];
  }

  /// 再生の長さ(秒)。いちばん最後の点の時刻
  static double totalTimeOf(List<List<GameRaceTrackPoint>> tracks) {
    double t = 0.0;
    for (final tr in tracks) {
      if (tr.isNotEmpty && tr.last.time > t) t = tr.last.time;
    }
    return t;
  }

  /// 画面に出すスタミナの値(0〜1200程度)。スタミナ指数(0〜1)を 200 + 1000 × 指数 にする。
  /// 計算に使うスタミナ(多くの馬が下限近く)をそのまま出すと、大半がGランクになるため
  static double staminaDisplay(double? staminaIndex) =>
      200.0 + 1000.0 * (staminaIndex ?? defaultStaminaIndex);

  /// 脚質(連続値)の名前
  static String styleLabelOf(double style) =>
      styleLabels[GameRaceEngine.styleClass(style)];
}