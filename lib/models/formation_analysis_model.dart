// lib/models/formation_analysis_model.dart

class FormationAnalysisResult {
  // 頻度マトリクス
  final List<List<int>> frequencyMatrix;

  // --- 基本フォーメーション (Fixed 1-2-5) ---
  final List<int> basicRank1; // 1頭
  final List<int> basicRank2; // 2頭
  final List<int> basicRank3; // 5頭

  // --- AI戦略フォーメーション (Dynamic) ---
  final List<int> strategyRank1;
  final List<int> strategyRank2;
  final List<int> strategyRank3;

  // 生成された推奨買い目リスト (AI戦略に基づく)
  final List<FormationTicket> tickets;

  // オッズ分析データ
  final double standardOddsLine;
  final double maxOddsLine;
  final List<String> chaosHorses;
  final int validHorseCount;

  // AI戦術メタデータ
  final String strategyName;   // 例: "4頭BOX (混戦)"
  final String strategyReason; // 例: "上位が拮抗..."
  final String betType;        // "3連単" or "3連複"
  final int estimatedPoints;   // 推定点数

  // 資金配分 (Ticket -> 推奨金額) ※予算10,000円想定
  final Map<FormationTicket, int> budgetAllocation;

  FormationAnalysisResult({
    required this.frequencyMatrix,
    required this.basicRank1,
    required this.basicRank2,
    required this.basicRank3,
    required this.strategyRank1,
    required this.strategyRank2,
    required this.strategyRank3,
    required this.tickets,
    required this.standardOddsLine,
    required this.maxOddsLine,
    required this.chaosHorses,
    required this.validHorseCount,
    required this.strategyName,
    required this.strategyReason,
    required this.betType,
    required this.estimatedPoints,
    required this.budgetAllocation, // 追加
  });
}

class FormationTicket {
  final List<int> popularities;
  final List<String> horseNames;
  final double weight;
  final String type;

  FormationTicket({
    required this.popularities,
    required this.horseNames,
    required this.weight,
    required this.type,
  });
}