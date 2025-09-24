// lib/models/horse_stats_model.dart

class HorseStats {
  final int raceCount; // 出走回数
  final double winRate; // 勝率
  final double placeRate; // 連対率
  final double showRate; // 複勝率
  final double winRecoveryRate; // 単勝回収率
  final double showRecoveryRate; // 複勝回収率
  final String g1Stats; // G1成績
  final String g2Stats; // G2成績
  final String g3Stats; // G3成績
  final String opStats; // OP成績
  final String conditionStats; // 条件戦成績

  HorseStats({
    this.raceCount = 0,
    this.winRate = 0.0,
    this.placeRate = 0.0,
    this.showRate = 0.0,
    this.winRecoveryRate = 0.0,
    this.showRecoveryRate = 0.0,
    this.g1Stats = '0-0-0-0',
    this.g2Stats = '0-0-0-0',
    this.g3Stats = '0-0-0-0',
    this.opStats = '0-0-0-0',
    this.conditionStats = '0-0-0-0',
  });
}