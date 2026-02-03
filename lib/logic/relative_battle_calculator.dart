// lib/logic/relative_battle_calculator.dart

import 'dart:math';
import 'package:hetaumakeiba_v2/models/ai_prediction_race_data.dart';
import 'package:hetaumakeiba_v2/logic/ai/leg_style_analyzer.dart';
import '../models/relative_evaluation_model.dart';

/// 相対評価シミュレーションを実行する計算クラス
class RelativeBattleCalculator {
  final Random _random = Random();

  /// メインメソッド
  List<RelativeEvaluationResult> runSimulation(
      List<PredictionHorseDetail> horses, {
        int iterations = 100,
      }) {
    if (horses.length < 2) return [];

    final List<_HorseStaticData> staticDataList = horses.map((h) => _prepareStaticData(h)).toList();

    // 各シナリオを実行
    final overallResult = _runScenario(staticDataList, iterations, null);
    final slowResult = _runScenario(staticDataList, iterations, RacePace.slow);
    final middleResult = _runScenario(staticDataList, iterations, RacePace.middle);
    final highResult = _runScenario(staticDataList, iterations, RacePace.high);

    List<RelativeEvaluationResult> results = [];
    overallResult.sort((a, b) => b.winRate.compareTo(a.winRate));

    for (int i = 0; i < overallResult.length; i++) {
      final baseRes = overallResult[i];
      final aiRank = i + 1;

      final slowRes = slowResult.firstWhere((r) => r.horseId == baseRes.horseId);
      final middleRes = middleResult.firstWhere((r) => r.horseId == baseRes.horseId);
      final highRes = highResult.firstWhere((r) => r.horseId == baseRes.horseId);

      final Map<RacePace, double> scenarioWinRates = {
        RacePace.slow: slowRes.winRate,
        RacePace.middle: middleRes.winRate,
        RacePace.high: highRes.winRate,
      };

      final Map<RacePace, int> scenarioRanks = {
        RacePace.slow: slowRes.rank,
        RacePace.middle: middleRes.rank,
        RacePace.high: highRes.rank,
      };

      final staticData = staticDataList.firstWhere((d) => d.horseId == baseRes.horseId);

      double maxScenarioWinRate = [slowRes.winRate, middleRes.winRate, highRes.winRate].reduce(max);
      double reversalScore = (maxScenarioWinRate - baseRes.winRate) * 100;
      if (reversalScore < 0) reversalScore = 0;

      RacePace? bestPace;
      if (maxScenarioWinRate == slowRes.winRate) bestPace = RacePace.slow;
      else if (maxScenarioWinRate == highRes.winRate) bestPace = RacePace.high;
      else bestPace = RacePace.middle;

      double valueScore = 0.0;
      double winRate = baseRes.winRate;
      double odds = staticData.currentOdds ?? 0.0;
      int popularity = staticData.popularity ?? 99;

      if (winRate >= 0.03 && odds > 0) {
        double roi = winRate * odds;
        double gapBonus = (popularity - aiRank) * 5.0;
        valueScore = (roi * 100) + gapBonus;
      }

      // ★刷新: 3ブロック構成の動的コメント生成
      String comment = _generateRichComment(
        winRate: winRate,
        valueScore: valueScore,
        reversalScore: reversalScore,
        bestPace: bestPace,
        aptitudeScore: baseRes.factorScores['aptitude'] ?? 0,
        popularity: popularity,
        aiRank: aiRank,
        odds: odds,
        legStyleProfile: staticData.legStyleProfile,
      );

      results.add(RelativeEvaluationResult(
        horseId: baseRes.horseId,
        horseName: baseRes.horseName,
        popularity: baseRes.popularity,
        odds: odds,
        winRate: baseRes.winRate,
        rank: aiRank,
        reversalScore: reversalScore,
        confidence: baseRes.confidence,
        evaluationComment: comment,
        factorScores: {
          ...baseRes.factorScores,
          'value': valueScore,
        },
        scenarioWinRates: scenarioWinRates,
        scenarioRanks: scenarioRanks,
      ));
    }

    results.sort((a, b) => a.rank.compareTo(b.rank));
    return results;
  }

// ===========================================================================
  // ★ プロフェッショナル短評生成エンジン (3ブロック構成)
  // ===========================================================================

  String _generateRichComment({
    required double winRate,
    required double valueScore,
    required double reversalScore,
    required RacePace? bestPace,
    required double aptitudeScore,
    required int popularity,
    required int aiRank,
    required double odds,
    required LegStyleProfile? legStyleProfile,
  }) {
    // 1. ブロック①: 主語・特徴 (Who/What)
    // ★修正: 引数に aiRank を追加しました
    String part1 = _selectSubjectPhrase(legStyleProfile, popularity, winRate, aptitudeScore, aiRank);

    // 2. ブロック②: 条件・展開 (If/When)
    String part2 = _selectConditionPhrase(bestPace, reversalScore, valueScore, winRate, odds);

    // 3. ブロック③: 結論 (Action)
    String part3 = _selectConclusionPhrase(winRate, valueScore, reversalScore, popularity);

    // 文脈結合
    return "$part1、$part2、$part3";
  }

  /// ブロック①選択ロジック
  // ★修正: 引数定義に int aiRank を追加しました
  String _selectSubjectPhrase(LegStyleProfile? profile, int popularity, double winRate, double aptitudeScore, int aiRank) {
    // 穴馬判定 (人気薄だがAI評価が高い)
    // ここで aiRank を使用するため、引数が必要でした
    if (popularity > 5 && (winRate > 0.15 || aiRank <= 3)) {
      return _getRandom(_subjectAnauma);
    }
    // コース巧者
    if (aptitudeScore >= 15.0) {
      return _getRandom(_subjectCourseSpecialist);
    }
    // 脚質ベース
    String style = profile?.primaryStyle ?? '自在';
    if (style == '逃げ') return _getRandom(_subjectNige);
    if (style == '先行') return _getRandom(_subjectSenko);
    if (style == '差し' || style == '追い込み') return _getRandom(_subjectSashi);

    // デフォルト
    return "自在性に富んだ取り口を見せ";
  }

  /// ブロック②選択ロジック
  String _selectConditionPhrase(RacePace? bestPace, double reversal, double value, double winRate, double odds) {
    // 逆転・展開待ち (最優先)
    if (reversal >= 20.0) {
      if (bestPace == RacePace.high) return _getRandom(_conditionHighPace);
      if (bestPace == RacePace.slow) return _getRandom(_conditionSlowPace);
    }
    // 妙味 (オッズの歪み)
    if (value >= 150.0 || (value >= 100.0 && odds >= 10.0)) {
      return _getRandom(_conditionValue);
    }
    // 能力上位 (勝率が高い)
    if (winRate >= 0.40) {
      return _getRandom(_conditionAbility);
    }
    // デフォルト (展開不問など)
    return "展開に左右されない強みがあり";
  }

  /// ブロック③選択ロジック
  String _selectConclusionPhrase(double winRate, double value, double reversal, int popularity) {
    // 危険な人気馬
    if (popularity <= 3 && winRate < 0.15) {
      return _getRandom(_conclusionDanger);
    }
    // 鉄板
    if (winRate >= 0.40) {
      return _getRandom(_conclusionIronclad);
    }
    // 一発逆転
    if (reversal >= 25.0 || (value >= 200.0 && winRate < 0.2)) {
      return _getRandom(_conclusionDarkHorse);
    }
    // 相手候補 (デフォルト)
    if (winRate >= 0.15) {
      return _getRandom(_conclusionContender);
    }
    // 厳しい
    return "静観するのが賢明でしょう。";
  }

  String _getRandom(List<String> list) => list[_random.nextInt(list.length)];

  // --- 語彙データベース (Internal Data Only) ---

  // ①主語：逃げ
  static const _subjectNige = [
    "テンの速さを最大限に活かし", "果敢にハナを奪うスタイルで", "単騎マイペースの逃げなら", "自慢の快速を武器に主導権を握り",
    "自分のリズムで逃げられれば", "強引にでもハナを叩く構えで", "行き脚の良さはメンバー随一で", "淀みない流れを作る快速馬で",
    "先手を奪って主導権を渡さず", "ハナを奪う形がベストの構成で"
  ];
  // ①主語：先行
  static const _subjectSenko = [
    "好位のインで脚を溜め", "安定感ある取り口が武器で", "番手から抜け出す競馬が板につき", "隙のない立ち回りが持ち味で",
    "先団の直後で機を伺い", "好位で流れに乗る形が理想で", "器用な脚を使える先行タイプで", "先団の一角で流れに乗れば",
    "好位から安定した伸びを見せ", "経済コースを立ち回れる器用さがあり"
  ];
  // ①主語：差し・追込
  static const _subjectSashi = [
    "メンバー随一の末脚を誇り", "後方から虎視眈々と展開を伺い", "直線の切れ味を最大の武器に", "終い確実に脚を使うタイプで",
    "鋭い決め手を秘めており", "展開が嵌まった時の爆発力は凄まじく", "大外から豪快に脚を伸ばして", "溜めれば溜めるだけ伸びるタイプで",
    "混戦を切り裂くような末脚で", "自慢の瞬発力をフルに活かし"
  ];
  // ①主語：穴馬（人気薄・高評価）
  static const _subjectAnauma = [
    "実績面では見劣りするものの", "人気ほどの能力差は感じられず", "マークが薄くなるここは不気味で", "伏兵的存在ながら地力は秘めており",
    "潜在的な指数は上位に匹敵し", "配当的な旨味を感じさせる一頭で", "虎視眈々と波乱を狙う一角で", "隠れた実力馬として警戒が必要",
    "人気薄が予想される今回こそが買いで", "指数面では上位と互角の評価で"
  ];
  // ①主語：コース巧者
  static const _subjectCourseSpecialist = [
    "この舞台を庭にしており", "得意の条件に戻って一変が期待でき", "コース相性抜群で不安要素は少なく", "特定の距離で無類の強さを発揮し",
    "舞台適性の高さは証明済みで", "小回りコースでの立ち回りが巧みで", "この条件なら能力全開が可能で", "コース実績がメンバー中で抜けており"
  ];

  // ②条件：スロー（瞬発力）
  static const _conditionSlowPace = [
    "息の入るスローな流れになれば", "前が止まらない展開が味方し", "上がり勝負の決め手比べになれば", "瞬発力が要求される展開こそ理想で",
    "ペースが落ち着いて余力が残れば", "ヨーイドンの競馬に持ち込めれば", "逃げ馬不在の楽な流れが予想され", "後続に脚を使わせないスローなら",
    "緩い流れを味方に早め先頭を奪えば", "極端な上がり勝負がこの馬に合い"
  ];
  // ②条件：ハイ（消耗戦）
  static const _conditionHighPace = [
    "前が激流に巻き込まれれば", "前崩れの展開利を後方から得て", "タフな消耗戦になれば浮上し", "息の入らない厳しいラップになれば",
    "淀みのない流れで底力が問われ", "オーバーペースで前が脱落する中", "ハイペースを中団で死守できれば", "厳しい流れを経験してきた強みがあり",
    "激しい先行争いを尻目に脚を溜め", "バテ合いの展開で持ち前の粘りを発揮"
  ];
  // ②条件：妙味（オッズ）
  static const _conditionValue = [
    "実力に対し完全に過小評価されており", "配当妙味はメンバー中No.1で", "オッズ的な旨味が非常に大きく", "単勝期待値が極めて高いデータを示し",
    "盲点となっている今が絶好の狙い目", "複勝圏内の確実性はオッズ以上で", "穴党なら見逃せない魅力的な数値で", "期待値重視の戦略なら外せない一頭",
    "リスク・リターンのバランスが秀逸で", "伏兵ながら指数的には単穴以上の評価"
  ];
  // ②条件：能力上位
  static const _conditionAbility = [
    "地力は明らかに一枚上で", "ここでは能力が完全に抜けており", "死角らしい死角は見当たらず", "順当なら負けられない実力馬で",
    "指数的には圧倒的な優位に立ち", "どんな展開になっても対応できる", "凡走する姿が想像しにくい安定感で", "メンバー構成を見渡しても隙はなく",
    "圧倒的な指数が示す通り実力は本物", "ここは盤石の態勢で挑める一戦"
  ];

  // ③結論：鉄板
  static const _conclusionIronclad = [
    "勝ち負け必至です。", "軸として最も信頼できます。", "中心視して間違いありません。", "首位争いの筆頭候補です。",
    "堂々の主役を務めます。", "信頼度はメンバー中随一。", "順当に白星を掴むでしょう。", "勝利への最短距離にいます。",
    "盤石の軸馬として指名します。", "迷わず中心に据えるべき一頭。"
  ];
  // ③結論：相手候補
  static const _conclusionContender = [
    "連対候補として押さえるべき。", "相手には必ず入れておきたい一頭。", "3着なら十分に圏内です。", "圏内への食い込みは濃厚です。",
    "ヒモ穴として注意を払いたい。", "連下の一角として軽視禁物。", "善戦以上の期待がかかります。", "馬券内には拾っておきたい。",
    "相手なりに走る堅実さを信頼。", "手広く買うなら外せぬ一頭。"
  ];
  // ③結論：一発逆転
  static const _conclusionDarkHorse = [
    "波乱の主役になり得ます。", "一発大駆けの魅力十分です。", "頭まで突き抜けるシーンも。", "爆発力は上位を脅かす存在。",
    "高配当のキーマンはこの馬。", "大番狂わせを期待させる一頭。", "穴党なら迷わず狙いたい。", "突き抜ければ高配当必至。",
    "展開次第で主役に躍り出る。", "面白い穴馬として推奨します。"
  ];
  // ③結論：危険
  static const _conclusionDanger = [
    "全幅の信頼は置けません。", "静観するのが賢明でしょう。", "リスクの方が大きい評価です。", "今回は評価を下げるのが妥当。",
    "過信は禁物の危うさがあり。", "人気先行の感が否めません。", "今回は苦戦が予想されます。", "馬券的な妙味は薄いと判断。",
    "見送る勇気も必要な一頭。", "過剰人気に対する懸念あり。"
  ];

  // --- 既存メソッド（変更なし） ---
  List<RelativeEvaluationResult> _runScenario(
      List<_HorseStaticData> staticDataList,
      int iterations,
      RacePace? forcedPace,
      ) {
    final winCounts = {for (var h in staticDataList) h.horseId: 0};
    final scoreAccumulator = {
      for (var h in staticDataList)
        h.horseId: {'base': 0.0, 'style': 0.0, 'pace': 0.0, 'aptitude': 0.0}
    };

    for (int i = 0; i < iterations; i++) {
      _runSingleIteration(staticDataList, winCounts, scoreAccumulator, forcedPace);
    }

    List<RelativeEvaluationResult> results = [];
    var sortedEntries = winCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final int maxWinsPerIteration = staticDataList.length - 1;
    final int totalMatchups = iterations * maxWinsPerIteration;

    for (int i = 0; i < sortedEntries.length; i++) {
      final entry = sortedEntries[i];
      final horseId = entry.key;
      final winCount = entry.value;
      final staticData = staticDataList.firstWhere((d) => d.horseId == horseId);

      final winRate = totalMatchups > 0 ? winCount / totalMatchups : 0.0;
      final acc = scoreAccumulator[horseId]!;

      final factorScores = {
        'base': acc['base']! / iterations,
        'style': acc['style']! / iterations,
        'pace': acc['pace']! / iterations,
        'aptitude': acc['aptitude']! / iterations,
      };

      results.add(RelativeEvaluationResult(
        horseId: horseId,
        horseName: staticData.horseName,
        popularity: staticData.popularity,
        odds: staticData.currentOdds ?? 0.0,
        winRate: winRate,
        rank: i + 1,
        reversalScore: 0.0,
        confidence: _calculateConfidence(winRate, iterations),
        evaluationComment: "",
        factorScores: factorScores,
        scenarioWinRates: {},
        scenarioRanks: {},
      ));
    }
    return results;
  }

  _HorseStaticData _prepareStaticData(PredictionHorseDetail horse) {
    double baseAbility = 50.0;
    if (horse.overallScore != null) {
      baseAbility = horse.overallScore!;
    } else if (horse.effectiveOdds != null) {
      double? odds = double.tryParse(horse.effectiveOdds!);
      if (odds != null) {
        baseAbility = 100.0 - (odds * 2.0).clamp(0, 80);
      }
    } else if (horse.odds != null) {
      baseAbility = 100.0 - (horse.odds! * 2.0).clamp(0, 80);
    }

    double aptitudeScore = 0.0;
    if (horse.distanceCourseAptitudeStats != null) {
      final stats = horse.distanceCourseAptitudeStats!;
      double winRate = 0.0;
      if (stats.raceCount > 0) {
        winRate = stats.winCount / stats.raceCount;
      }
      aptitudeScore += (winRate * 30.0);
    }

    double? currentOdds;
    if (horse.effectiveOdds != null) {
      currentOdds = double.tryParse(horse.effectiveOdds!);
    } else {
      currentOdds = horse.odds;
    }

    return _HorseStaticData(
      horseId: horse.horseId,
      horseName: horse.horseName,
      popularity: horse.popularity,
      baseAbility: baseAbility,
      aptitudeScore: aptitudeScore,
      currentOdds: currentOdds,
      legStyleProfile: horse.legStyleProfile,
    );
  }

  void _runSingleIteration(
      List<_HorseStaticData> staticDataList,
      Map<String, int> winCounts,
      Map<String, Map<String, double>> scoreAccumulator,
      RacePace? forcedPace,
      ) {
    final Map<String, String> currentStyles = {};
    int nigeCount = 0;

    for (var horse in staticDataList) {
      String selectedStyle = '自在';
      if (horse.legStyleProfile != null) {
        double rand = _random.nextDouble();
        double cumulative = 0.0;
        bool determined = false;

        final dist = horse.legStyleProfile!.styleDistribution;
        for (var style in ['逃げ', '先行', '差し', '追い込み']) {
          cumulative += (dist[style] ?? 0.0);
          if (rand <= cumulative) {
            selectedStyle = style;
            determined = true;
            break;
          }
        }
        if (!determined) selectedStyle = horse.legStyleProfile!.primaryStyle;
      }
      currentStyles[horse.horseId] = selectedStyle;
      if (selectedStyle == '逃げ') nigeCount++;
    }

    RacePace pace;
    if (forcedPace != null) {
      pace = forcedPace;
    } else {
      pace = RacePace.middle;
      if (nigeCount <= 1) pace = RacePace.slow;
      else if (nigeCount >= 3) pace = RacePace.high;
    }

    final Map<String, double> currentStrengths = {};

    for (var horse in staticDataList) {
      double score = horse.baseAbility + horse.aptitudeScore;

      double styleQualityBonus = 0.0;
      final style = currentStyles[horse.horseId]!;
      if (horse.legStyleProfile != null) {
        double winRate = horse.legStyleProfile!.styleWinRates[style] ?? 0.0;
        styleQualityBonus = winRate * 50.0;
      }
      score += styleQualityBonus;

      double paceBonus = 0.0;
      if (pace == RacePace.slow) {
        if (style == '逃げ') paceBonus += 15.0;
        else if (style == '先行') paceBonus += 5.0;
        else if (style == '追い込み') paceBonus -= 5.0;
      } else if (pace == RacePace.high) {
        if (style == '逃げ') paceBonus -= 10.0;
        else if (style == '差し') paceBonus += 5.0;
        else if (style == '追い込み') paceBonus += 10.0;
      }
      score += paceBonus;
      score += (_random.nextDouble() - 0.5) * 10.0;

      currentStrengths[horse.horseId] = score;

      scoreAccumulator[horse.horseId]!['base'] = scoreAccumulator[horse.horseId]!['base']! + horse.baseAbility;
      scoreAccumulator[horse.horseId]!['style'] = scoreAccumulator[horse.horseId]!['style']! + styleQualityBonus;
      scoreAccumulator[horse.horseId]!['pace'] = scoreAccumulator[horse.horseId]!['pace']! + paceBonus;
      scoreAccumulator[horse.horseId]!['aptitude'] = scoreAccumulator[horse.horseId]!['aptitude']! + horse.aptitudeScore;
    }

    for (int i = 0; i < staticDataList.length; i++) {
      for (int j = i + 1; j < staticDataList.length; j++) {
        String idA = staticDataList[i].horseId;
        String idB = staticDataList[j].horseId;
        double strA = currentStrengths[idA]!;
        double strB = currentStrengths[idB]!;
        double probA = 1 / (1 + exp(-(strA - strB) / 15.0));

        if (_random.nextDouble() < probA) {
          winCounts[idA] = (winCounts[idA] ?? 0) + 1;
        } else {
          winCounts[idB] = (winCounts[idB] ?? 0) + 1;
        }
      }
    }
  }

  double _calculateConfidence(double winRate, int iterations) {
    if (winRate == 0 || winRate == 1) return 1.0;
    return 1.0 - (sqrt(winRate * (1 - winRate) / iterations));
  }
}

class _HorseStaticData {
  final String horseId;
  final String horseName;
  final int? popularity;
  final double baseAbility;
  final double aptitudeScore;
  final double? currentOdds;
  final LegStyleProfile? legStyleProfile;

  _HorseStaticData({
    required this.horseId,
    required this.horseName,
    this.popularity,
    required this.baseAbility,
    required this.aptitudeScore,
    this.currentOdds,
    this.legStyleProfile,
  });
}