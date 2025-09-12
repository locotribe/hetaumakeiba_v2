// lib/models/jockey_stats_model.dart

class JockeyStats {
  final String jockeyName;
  final String jockeyId;
  final FactorStats overallStats;
  final FactorStats? courseStats;
  final FactorStats popularHorseStats;
  final FactorStats unpopularHorseStats;

  JockeyStats({
    required this.jockeyName,
    required this.jockeyId,
    required this.overallStats,
    this.courseStats,
    required this.popularHorseStats,
    required this.unpopularHorseStats,
  });
}

class FactorStats {
  int raceCount = 0;
  int winCount = 0;
  int placeCount = 0; // 2nd or better
  int showCount = 0; // 3rd or better
  double totalWinInvestment = 0;
  double totalWinPayout = 0;
  double totalShowInvestment = 0;
  double totalShowPayout = 0;

  double get winRate => raceCount > 0 ? (winCount / raceCount) * 100 : 0.0;
  double get placeRate => raceCount > 0 ? (placeCount / raceCount) * 100 : 0.0;
  double get showRate => raceCount > 0 ? (showCount / raceCount) * 100 : 0.0;
  double get winRecoveryRate => totalWinInvestment > 0 ? (totalWinPayout / totalWinInvestment) * 100 : 0.0;
  double get showRecoveryRate => totalShowInvestment > 0 ? (totalShowPayout / totalShowInvestment) * 100 : 0.0;
  String get recordString => '$winCount-${placeCount - winCount}-${showCount - placeCount}-${raceCount - showCount}';
}