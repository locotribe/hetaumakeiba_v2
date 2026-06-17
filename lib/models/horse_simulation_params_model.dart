// lib/models/horse_simulation_params_model.dart

/// 展開シミュレーション用の競走馬パラメータを保持するモデル。
/// HorseRaceRecord から自動計算され、horse_simulation_params テーブルに永続化される。
class HorseSimulationParams {
  final String horseId;
  final double tenAccelIndex;  // テン加速指数 (0.0〜1.0): 1コーナー通過順位率の逆数の平均
  final double finishingPower; // 終い瞬発力 (0.0〜1.0): 最終コーナー→着順の順位改善の平均
  final double staminaIndex;   // スタミナ指数 (0.0〜1.0): 長距離レースでの複勝率ベース
  final String legStyle;       // 脚質 (逃げ/先行/差し/追込/マクリ/自在/不明)
  final String calculatedAt;   // 計算日時 (ISO8601)

  HorseSimulationParams({
    required this.horseId,
    required this.tenAccelIndex,
    required this.finishingPower,
    required this.staminaIndex,
    required this.legStyle,
    required this.calculatedAt,
  });

  factory HorseSimulationParams.fromMap(Map<String, dynamic> map) {
    return HorseSimulationParams(
      horseId: map['horse_id'] as String,
      tenAccelIndex: (map['ten_accel_index'] as num).toDouble(),
      finishingPower: (map['finishing_power'] as num).toDouble(),
      staminaIndex: (map['stamina_index'] as num).toDouble(),
      legStyle: map['leg_style'] as String,
      calculatedAt: map['calculated_at'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'horse_id': horseId,
      'ten_accel_index': tenAccelIndex,
      'finishing_power': finishingPower,
      'stamina_index': staminaIndex,
      'leg_style': legStyle,
      'calculated_at': calculatedAt,
    };
  }
}
