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

  // オッズ分析データ
  final double standardOddsLine;
  final double maxOddsLine;
  // [削除] chaosHorses を削除 (v.2.0)
  final int validHorseCount;

  // AI戦術メタデータ
  final String strategyName;   // 例: "4頭BOX (混戦)"
  final String strategyReason; // 例: "上位が拮抗..."
  final String betType;        // "3連単" or "3連複"
  final int estimatedPoints;   // 推定点数

  // [削除] tickets, budgetAllocation を削除 (v.2.0)

  FormationAnalysisResult({
    required this.frequencyMatrix,
    required this.basicRank1,
    required this.basicRank2,
    required this.basicRank3,
    required this.strategyRank1,
    required this.strategyRank2,
    required this.strategyRank3,
    // [修正] コンストラクタ引数から不要なプロパティを削除 (v.2.0)
    required this.standardOddsLine,
    required this.maxOddsLine,
    required this.validHorseCount,
    required this.strategyName,
    required this.strategyReason,
    required this.betType,
    required this.estimatedPoints,
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