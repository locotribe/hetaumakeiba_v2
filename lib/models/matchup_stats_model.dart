// lib/models/matchup_stats_model.dart

/// 2頭の馬間の直接対決の成績を保持するためのデータモデルクラスです。
class MatchupStats {
  final String horseIdA; // 馬AのID
  final String horseIdB; // 馬BのID
  final int matchupCount; // 直接対決した回数
  final int horseAWins; // 馬Aが馬Bに先着した回数

  MatchupStats({
    required this.horseIdA,
    required this.horseIdB,
    required this.matchupCount,
    required this.horseAWins,
  });

  /// 馬Bが馬Aに先着した回数を計算して返します。
  int get horseBWins => matchupCount - horseAWins;
}
