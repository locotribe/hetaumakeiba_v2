// lib/models/horse_stats_model.dart

class HorseStats {
  final int raceCount; // 出走回数
  final double winRate; // 勝率
  final double placeRate; // 連対率
  final double showRate; // 複勝率
  final double winRecoveryRate; // 単勝回収率
  final double showRecoveryRate; // 複勝回収率

  HorseStats({
    this.raceCount = 0,
    this.winRate = 0.0,
    this.placeRate = 0.0,
    this.showRate = 0.0,
    this.winRecoveryRate = 0.0,
    this.showRecoveryRate = 0.0,
  });
}
