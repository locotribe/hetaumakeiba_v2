// lib/models/jockey_combo_stats_model.dart

class JockeyComboStats {
  final bool isFirstRide; // 初騎乗（テン乗り）かどうか
  final int rideCount; // コンビでの騎乗回数
  final double winRate; // 勝率
  final double placeRate; // 連対率
  final double showRate; // 複勝率
  final double winRecoveryRate; // 単勝回収率
  final double showRecoveryRate; // 複勝回収率
  final String recordString; // 度数 (1-2-3-4 形式)

  JockeyComboStats({
    this.isFirstRide = false,
    this.rideCount = 0,
    this.winRate = 0.0,
    this.placeRate = 0.0,
    this.showRate = 0.0,
    this.winRecoveryRate = 0.0,
    this.showRecoveryRate = 0.0,
    this.recordString = '0-0-0-0',
  });
}
