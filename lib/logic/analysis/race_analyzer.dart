// lib/logic/analysis/race_analyzer.dart

import 'package:hetaumakeiba_v2/models/analysis_model.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/logic/race_data_parser.dart';
import 'package:hetaumakeiba_v2/logic/analysis/aptitude_analyzer.dart';
import 'package:hetaumakeiba_v2/logic/analysis/leg_style_analyzer.dart';
import 'package:hetaumakeiba_v2/db/repositories/course_preset_repository.dart';
import 'package:hetaumakeiba_v2/models/course_preset_model.dart';
import 'package:hetaumakeiba_v2/models/horse_simulation_params_model.dart';
import 'package:hetaumakeiba_v2/models/jockey_stats_model.dart';
import 'package:hetaumakeiba_v2/models/distance_category.dart';

class _SimHorse {
  final PredictionHorseDetail detail;
  double positionScore;
  final double staminaScore;
  final double finishingKickScore;
  final double abilityScore;
  // [追加] 斤量: 馬体重比ベースの実効kg負担（既定値0.0、後段で代入） (v.2026.7.26+26072601)
  double weightBurden = 0.0;
  // [追加] 0-4 距離延長短縮: 直線への補正値（既定値0.0、後段で代入） (v.2026.7.26+26072602)
  double distLastAdj = 0.0;
  // [追加] 0-8 着差ベースの相対力（既定値0.0、後段で代入） (v.2026.7.27+26072701)
  double marginPower = 0.0;

  _SimHorse({
    required this.detail,
    required this.positionScore,
    required this.staminaScore,
    required this.finishingKickScore,
    required this.abilityScore,
  });
}

class RaceAnalyzer {
  // JRA競馬場コードと名称のマッピング
  static final Map<String, String> venueCodeMap = {
    '札幌': '01', '函館': '02', '福島': '03', '新潟': '04', '東京': '05',
    '中山': '06', '中京': '07', '京都': '08', '阪神': '09', '小倉': '10',
  };

  // トラック種別をID用の文字列に変換するマッピング
  static final Map<String, String> trackIdMap = {
    '芝': 'shiba', 'ダ': 'dirt', '障': 'obstacle',
  };

  // [追加] 上がり局面での能力反映係数（実装後の挙動を見て微調整する初期値） (v.2026.7.25)
  static const double _kAbilityFactor4c = 0.8;   // 4コーナー
  static const double _kAbilityFactorLast = 0.5; // 直線

  // [追加] 1クラス差あたりの能力補正(点)。実装後の挙動を見て微調整する初期値 (v.2026.7.25+26072502)
  static const double _kClassAbilityWeight = 4.0;

  // [追加] レース名/グレードからクラスを1〜8にランク化（判定不能は0） (v.2026.7.25+26072502)
  static int _estimateClassLevel(String text) {
    final t = text;
    if (t.contains('G1') || t.contains('GⅠ') || t.contains('G I')) return 8;
    if (t.contains('G2') || t.contains('GⅡ')) return 7;
    if (t.contains('G3') || t.contains('GⅢ')) return 6;
    if (t.contains('リステッド') || t.contains('(L)') || t.contains('L)') ||
        t.contains('オープン') || t.contains('ＯＰ') || t.contains('OP')) return 5;
    if (t.contains('3勝') || t.contains('１６００万') || t.contains('1600万')) return 4;
    if (t.contains('2勝') || t.contains('１０００万') || t.contains('1000万')) return 3;
    if (t.contains('1勝') || t.contains('５００万') || t.contains('500万')) return 2;
    if (t.contains('新馬') || t.contains('未勝利')) return 1;
    return 0;
  }

  // [追加] 斤量の反映係数（実効kgあたり・実装後に微調整する初期値） (v.2026.7.26+26072601)
  static const double _kWeightFactorFront = 0.05; // 逃げ・先行のテンへの効き
  static const double _kWeightFactorBack = 0.03;  // 差し・追込等の上がりへの効き

  // [追加] 馬体重文字列から絶対値kgを取り出す（"480(+14)"→480.0、計不/空はnull） (v.2026.7.26+26072601)
  static double? _parseBodyWeight(String? text) {
    if (text == null) return null;
    final m = RegExp(r'(\d+)').firstMatch(text);
    if (m == null) return null;
    return double.tryParse(m.group(1)!);
  }

  // [追加] 過去成績を新しい順に走査し最初に取得できる馬体重を返す（海外/計不はスキップ） (v.2026.7.26)
  static double? _firstParsableBodyWeight(List<HorseRaceRecord>? records) {
    if (records == null) return null;
    for (final r in records) {
      final w = _parseBodyWeight(r.horseWeight);
      if (w != null) return w;
    }
    return null;
  }

  // [追加] 距離延長短縮の補正値（固定微小値・実装後に微調整） (v.2026.7.26+26072602)
  static const double _kDistTenAdj = 0.15;  // テン位置への補正
  static const double _kDistLastAdj = 0.15; // 直線への補正

  // [追加] 3コーナーのスタミナ反映係数（実装後に微調整する初期値） (v.2026.7.26+26072603)
  static const double _kStaminaFactor3c = 0.4;

  // [追加] 着差ベースの相対力の反映係数（直線・実装後に微調整する初期値） (v.2026.7.27+26072701)
  static const double _kMarginPowerFactor = 0.3;

  // [追加] 0-9 トラックバイアスの全体スケール係数（実装後に微調整する初期値） (v.2026.7.27+26072702)
  static const double _kTrackBiasScale = 0.05;

  // [追加] 0-9 馬場の硬軟から前残り/差しの全体バイアスBを算出（正=高速/前有利, 負=タフ/差し有利） (v.2026.7.27+26072702)
  // 芝: クッション値・含水率の線形。ダート: 含水率の単調写像(差し側に振らせない・芝より小さめ)。必要値がnullなら0.0(=バイアスなし)。
  static double calcTrackBias({
    double? cushionValue,
    double? moistureTurfGoal,
    double? moistureDirtGoal,
    required bool isDirt,
  }) {
    if (isDirt) {
      final m = moistureDirtGoal;
      if (m == null) return 0.0;
      return ((m - 2.0) * 0.1).clamp(0.0, 0.8);
    } else {
      final c = cushionValue;
      final m = moistureTurfGoal;
      if (c == null && m == null) return 0.0;
      final cushionTerm = c != null ? (c - 9.4) * 0.35 : 0.0;
      final moistureTerm = m != null ? (12.0 - m) * 0.15 : 0.0;
      return (cushionTerm + moistureTerm).clamp(-1.0, 1.0);
    }
  }

  // [追加] 0-9 脚質別トラックバイアス係数（テン局面） (v.2026.7.27+26072702)
  static double _trackBiasKTen(String? style) {
    switch (style) {
      case '逃げ':
        return 1.2;
      case '先行':
        return 0.8;
      default:
        return 0.0; // 差し/追込/自在/マクリ/不明はテンでは補正しない
    }
  }

  // [追加] 0-9 脚質別トラックバイアス係数（直線局面） (v.2026.7.27+26072702)
  static double _trackBiasKStr(String? style) {
    switch (style) {
      case '逃げ':
        return 0.8;
      case '先行':
        return 0.8;
      case '差し':
        return -1.4;
      case '追込':
        return -1.8;
      case 'マクリ':
        return -0.8;
      default:
        return 0.0; // 自在/不明は補正しない
    }
  }

  static RacePacePrediction predictRacePace(
      List<PredictionHorseDetail> horses,
      Map<String, List<HorseRaceRecord>> allPastRecords,
      List<RaceResult> pastRaceResults,
      ) {
    // 1. 過去レースのペース傾向を分析
    final Map<String, int> pastPaceCounts = {'ハイ': 0, 'ミドル': 0, 'スロー': 0};
    if (pastRaceResults.isNotEmpty) {
      for (final result in pastRaceResults) {
        final pace = RaceDataParser.calculatePaceFromRaceResult(result);
        pastPaceCounts[pace] = (pastPaceCounts[pace] ?? 0) + 1;
      }
    }

    // 2. 今回のメンバー構成を分析
    int nigeCount = 0;
    int senkoCount = 0;
    for (var horse in horses) {
      final records = allPastRecords[horse.horseId] ?? [];
      final style = LegStyleAnalyzer.getRunningStyle(records).primaryStyle;
      if (style == "逃げ") nigeCount++;
      if (style == "先行") senkoCount++;
    }
    final frontRunnersRatio = (nigeCount + senkoCount) / horses.length;

    // 3. ベースとなる確率を計算
    Map<String, double> paceProbabilities = {'ハイペース': 0.33, 'ミドルペース': 0.34, 'スローペース': 0.33};

    // 4. メンバー構成に応じて確率を調整
    if (nigeCount >= 2 || frontRunnersRatio > 0.5) {
      paceProbabilities['ハイペース'] = (paceProbabilities['ハイペース'] ?? 0) + 0.3;
      paceProbabilities['スローペース'] = (paceProbabilities['スローペース'] ?? 0) - 0.3;
    } else if (nigeCount == 0 && frontRunnersRatio < 0.2) {
      paceProbabilities['ハイペース'] = (paceProbabilities['ハイペース'] ?? 0) - 0.3;
      paceProbabilities['スローペース'] = (paceProbabilities['スローペース'] ?? 0) + 0.3;
    }

    // 5. 過去レースの傾向に応じてさらに確率を調整
    final totalPastRaces = pastRaceResults.length;
    if (totalPastRaces > 5) { // 十分なデータ数がある場合のみ
      final pastHighPaceRatio = (pastPaceCounts['ハイ'] ?? 0) / totalPastRaces;
      final pastSlowPaceRatio = (pastPaceCounts['スロー'] ?? 0) / totalPastRaces;
      paceProbabilities['ハイペース'] = (paceProbabilities['ハイペース'] ?? 0) + (pastHighPaceRatio - 0.33) * 0.5;
      paceProbabilities['スローペース'] = (paceProbabilities['スローペース'] ?? 0) + (pastSlowPaceRatio - 0.33) * 0.5;
    }

    // 6. 確率の合計が1になるように正規化
    final totalProbability = paceProbabilities.values.reduce((a, b) => a + b);
    if (totalProbability > 0) {
      paceProbabilities.updateAll((key, value) => (value / totalProbability).clamp(0.0, 1.0));
    } else {
      // 予期せぬエラーで合計が0になった場合は均等割りにフォールバック
      paceProbabilities = {'ハイペース': 0.33, 'ミドルペース': 0.34, 'スローペース': 0.33};
    }

    // 最終的なキー名を調整
    final finalProbabilities = {
      'ハイペース': paceProbabilities['ハイペース']!,
      'ミドルペース': paceProbabilities['ミドルペース']!,
      'スローペース': paceProbabilities['スローペース']!,
    };

    return RacePacePrediction(paceProbabilities: finalProbabilities);
  }



  /// 各馬の脚質と枠順を元に、各コーナーの展開を予測（シミュレーション）します。
  // [修正] horsesOverride を追加。渡された場合は raceData.horses の代わりに使用する (v.13.43.0)
  static Future<Map<String, String>> simulateRaceDevelopment(
      PredictionRaceData raceData,
      Map<String, List<HorseRaceRecord>> allPastRecords,
      List<String> cornersToPredict,
      Map<String, JockeyStats> allJockeyStats,
      {
      List<PredictionHorseDetail>? horsesOverride,
      // [追加] フェーズ2: tenAccelIndex/staminaIndex/finishingPowerをキーフレームに反映 (v.2026.6.19)
      Map<String, HorseSimulationParams> simulationParams = const {},
      // [追加] 0-9 馬場の硬軟による前残り/差しの全体バイアス (v.2026.7.27+26072702)
      double trackBias = 0.0,
      // [追加] 0-9b-3 ユーザーによるペース手動選択（未指定時はアプリ予想を使用） (v.2026.7.27+26072707)
      String? paceOverride,
      }
      ) async {
    final CoursePresetRepository coursePresetRepo = CoursePresetRepository();
    final venueCode = venueCodeMap[raceData.venue];
    String trackType = '';
    String distance = '';

    final raceInfo = raceData.raceDetails1 ?? '';
    if (raceInfo.contains('障')) {
      trackType = 'obstacle';
    } else if (raceInfo.contains('ダ')) {
      trackType = 'dirt';
    } else {
      trackType = 'shiba';
    }

    final distanceMatch = RegExp(r'(\d+)m').firstMatch(raceInfo);
    if (distanceMatch != null) {
      distance = distanceMatch.group(1)!;
    }

    final courseId = '${venueCode}_${trackType}_$distance';
    final CoursePreset? coursePreset = await coursePresetRepo.getCoursePreset(courseId);

    // [修正] horsesOverride が渡された場合はそちらを使用する (v.13.43.0)
    final simHorses = (horsesOverride ?? raceData.horses)
        .where((horse) => !horse.isScratched)
        .map((horse) {
      final pastRecords = allPastRecords[horse.horseId] ?? [];
      final distribution = horse.legStyleProfile?.styleDistribution ?? {};
      double initialPositionScore;

      final nigeRate = distribution['逃げ'] ?? 0.0;
      final senkoRate = distribution['先行'] ?? 0.0;
      final sashiRate = distribution['差し'] ?? 0.0;
      final oikomiRate = distribution['追込'] ?? 0.0;

      if ((nigeRate + senkoRate + sashiRate + oikomiRate) > 0) {
        initialPositionScore =
            (nigeRate * 1.0) + (senkoRate * 2.0) + (sashiRate * 3.5) +
                (oikomiRate * 4.5);
      } else {
        final style = horse.legStyleProfile?.primaryStyle ?? '不明';
        switch (style) {
          case '逃げ':
            initialPositionScore = 1.0;
            break;
          case '先行':
            initialPositionScore = 2.0;
            break;
          case '差し':
            initialPositionScore = 3.0;
            break;
          case '追込':
            initialPositionScore = 4.0;
            break;
          default:
            initialPositionScore = 2.5;
        }
      }
      // 騎手要因による補正
      final jockeyStats = allJockeyStats[horse.jockeyId];
      if (jockeyStats != null && jockeyStats.courseStats != null &&
          jockeyStats.courseStats!.raceCount > 2) {
        // 当該コースの複勝率をスコアに反映（平均15%を基準とする）
        final courseShowRate = jockeyStats.courseStats!.showRate / 100.0;
        initialPositionScore -= (courseShowRate - 0.15) * 0.5; // 影響度は小さめに設定
      }

      final earlySpeedScore =
      AptitudeAnalyzer.evaluateEarlySpeedFit(horse, raceData, pastRecords);
      initialPositionScore -= (earlySpeedScore / 100.0) * 0.5;

      // コース特性による補正
      if (coursePreset != null) {
        if (coursePreset.keyPoints.contains('内枠有利') &&
            horse.gateNumber <= 2) {
          initialPositionScore -= 0.2; // 内枠ボーナス
        }
        if (coursePreset.keyPoints.contains('外枠不利') &&
            horse.gateNumber >= 7) {
          initialPositionScore += 0.2; // 外枠ペナルティ
        }
      }


      // [追加] 総合適性(能力)を展開実行時にその場算出 (v.2026.7.25)
      final abilityScore = AptitudeAnalyzer.calculateOverallAptitudeScore(
          horse, raceData, pastRecords);

      // [追加] クラス(相手関係)補正: 経験クラスと今回クラスの差でabilityScoreを増減 (v.2026.7.25+26072502)
      final currentClass = _estimateClassLevel('${raceData.raceGrade} ${raceData.raceDetails1 ?? ''}');
      final pastClasses = pastRecords
          .take(5)
          .map((r) => _estimateClassLevel(r.raceName))
          .where((c) => c > 0)
          .toList();
      double classAdjustedAbility = abilityScore;
      if (currentClass > 0 && pastClasses.isNotEmpty) {
        final avgPastClass =
            pastClasses.reduce((a, b) => a + b) / pastClasses.length;
        final classDelta = (avgPastClass - currentClass).clamp(-3.0, 3.0);
        classAdjustedAbility =
            (abilityScore + classDelta * _kClassAbilityWeight).clamp(0.0, 100.0);
      }

      return _SimHorse(
        detail: horse,
        positionScore: initialPositionScore,
        staminaScore:
        AptitudeAnalyzer.evaluateStaminaFit(horse, raceData, pastRecords),
        finishingKickScore: AptitudeAnalyzer.evaluateFinishingKickFit(
            horse, raceData, pastRecords),
        abilityScore: classAdjustedAbility,
      );
    }).toList();

    final development = <String, String>{};
    // [修正] 0-9b-3 ペース手動選択(paceOverride)があれば優先。未指定時は従来どおりアプリ予想を使用 (v.2026.7.27+26072707)
    final predictedPace = paceOverride ??
        raceData.racePacePrediction?.predictedPace ??
        'ミドルペース';

    // [追加] 能力差を相対評価するための場内平均 (v.2026.7.25)
    final meanAbility = simHorses.isEmpty
        ? 60.0
        : simHorses.map((h) => h.abilityScore).reduce((a, b) => a + b) /
        simHorses.length;

    // [追加] 斤量: 馬体重比ベースの実効kg負担を算出 (v.2026.7.26+26072601)
    final bodyWeights = <_SimHorse, double?>{};
    for (final sh in simHorses) {
      // [修正] 直近1走が海外(馬体重null)でも、過去成績を遡って国内の馬体重を使う (v.2026.7.26)
      bodyWeights[sh] = _parseBodyWeight(sh.detail.horseWeight) ??
          _parseBodyWeight(sh.detail.previousHorseWeight) ??
          _firstParsableBodyWeight(allPastRecords[sh.detail.horseId]);
    }
    final validBodyWeights = bodyWeights.values.whereType<double>().toList();
    final meanBodyWeight = validBodyWeights.isEmpty
        ? 470.0
        : validBodyWeights.reduce((a, b) => a + b) / validBodyWeights.length;
    final ratios = <_SimHorse, double>{};
    for (final sh in simHorses) {
      final bw = bodyWeights[sh] ?? meanBodyWeight;
      ratios[sh] = sh.detail.carriedWeight / bw;
    }
    final meanRatio = ratios.isEmpty
        ? 0.0
        : ratios.values.reduce((a, b) => a + b) / ratios.length;
    for (final sh in simHorses) {
      sh.weightBurden = (ratios[sh]! - meanRatio) * meanBodyWeight;
    }

    // [追加] 0-8 着差ベースの相対力(marginPower)を近走から算出（直線でのみ使用） (v.2026.7.27+26072701)
    for (final horse in simHorses) {
      final records = allPastRecords[horse.detail.horseId];
      if (records == null || records.isEmpty) {
        horse.marginPower = 0.0;
        continue;
      }
      double totalWeighted = 0.0;
      double totalWeight = 0.0;
      double weight = 1.0;
      for (final r in records.take(5)) {
        final margin = double.tryParse(r.margin.trim()); // 秒。勝ち馬:マイナス, 敗者:プラス
        final dist = int.tryParse(r.distance.replaceAll(RegExp(r'[^0-9]'), ''));
        if (margin == null || dist == null || dist <= 0) {
          weight *= 0.8;
          continue;
        }
        final normMargin = margin / (dist / 1000.0); // 1000mあたり着差(秒)
        final raw = -normMargin;                      // 勝ち=プラス, 負け=マイナス
        final clamped = raw.clamp(-1.0, 1.5);         // 非対称クランプ(大敗はノイズ多く-1.0で打ち切り)
        totalWeighted += clamped * weight;
        totalWeight += weight;
        weight *= 0.8;                                // 近走ほど重み大
      }
      horse.marginPower = totalWeight > 0 ? totalWeighted / totalWeight : 0.0;
    }

    simHorses.sort((a, b) => a.positionScore.compareTo(b.positionScore));

    // [追加] 斤量(逃げ・先行): 初速=テンの位置取りに反映。重い馬はテンでやや後退 (v.2026.7.26+26072601)
    for (final horse in simHorses) {
      final style = horse.detail.legStyleProfile?.primaryStyle;
      if (style == '逃げ' || style == '先行') {
        horse.positionScore += horse.weightBurden * _kWeightFactorFront;
      }
    }

    // [追加] 0-4 距離延長短縮: 隣接カテゴリ跨ぎ×脚質でテン/直線を補正 (v.2026.7.26+26072602)
    final currentDistanceMeters = int.tryParse(distance);
    final currentCategory = distanceCategoryOf(currentDistanceMeters);
    for (final horse in simHorses) {
      final records = allPastRecords[horse.detail.horseId];
      if (currentCategory == null || records == null || records.isEmpty) continue;
      final prev = records.first;
      String prevSurface;
      if (prev.distance.startsWith('障')) {
        prevSurface = 'obstacle';
      } else if (prev.distance.startsWith('ダ')) {
        prevSurface = 'dirt';
      } else {
        prevSurface = 'shiba';
      }
      if (prevSurface != trackType) continue; // 馬場替わりは対象外
      final prevMeters =
          int.tryParse(prev.distance.replaceAll(RegExp(r'[^0-9]'), ''));
      final prevCategory = distanceCategoryOf(prevMeters);
      if (prevCategory == null) continue;
      final diff = currentCategory.index - prevCategory.index;
      if (diff.abs() != 1) continue; // 隣接1カテゴリ跨ぎのみ
      final style = horse.detail.legStyleProfile?.primaryStyle;
      final isFront = style == '逃げ' || style == '先行';
      final isBack = style == '差し' || style == '追込';
      if (diff > 0) {
        // 距離延長
        if (isFront) {
          horse.positionScore -= _kDistTenAdj; // テン前進
          horse.distLastAdj -= _kDistLastAdj;  // 直線も前進(息が入る)
        }
        // 差し・追込の延長はテン・直線とも変化なし（スタミナ別ロジックに委ねる）
      } else {
        // 距離短縮
        if (isFront) {
          horse.distLastAdj += _kDistLastAdj;  // 直線で失速=後退
        } else if (isBack) {
          horse.positionScore += _kDistTenAdj; // テン後退
        }
      }
      // 自在・マクリ・不明は補正なし
    }

    // [追加] 0-9 トラックバイアス(テン): 逃げ・先行を馬場傾向で微補正 (v.2026.7.27+26072702)
    for (final horse in simHorses) {
      final k = _trackBiasKTen(horse.detail.legStyleProfile?.primaryStyle);
      if (k != 0.0) {
        horse.positionScore -= trackBias * _kTrackBiasScale * k;
      }
    }

    simHorses.sort((a, b) => a.positionScore.compareTo(b.positionScore));

    // [追加] テン: 初期ソート直後の隊列（枠番・脚質ベース、テン指数未反映） (v.2026.6.19)
    if (cornersToPredict.contains('テン')) {
      development['テン'] = _formatTairetsu(simHorses);
    }

    // [追加] 1コーナー: テン加速指数が高い馬が前に出る (v.2026.6.19)
    if (cornersToPredict.contains('1コーナー')) {
      for (final horse in simHorses) {
        final params = simulationParams[horse.detail.horseNumber.toString()];
        final tenAccel = params?.tenAccelIndex ?? 0.5;
        // tenAccelIndex>0.5の馬はpositionScoreを下げて前進、<0.5は後退
        horse.positionScore -= (tenAccel - 0.5) * 0.6;
      }
      simHorses.sort((a, b) => a.positionScore.compareTo(b.positionScore));
      development['1コーナー'] = _formatTairetsu(simHorses);
    }

    // [修正] スタミナ不足補正のforループを削除（2コーナーは疲労で動く局面ではないため、隊列出力自体は維持） (v.2026.7.26+26072603)
    if (cornersToPredict.contains('2コーナー')) {
      simHorses.sort((a, b) => a.positionScore.compareTo(b.positionScore));
      development['2コーナー'] = _formatTairetsu(simHorses);
    }

    if (cornersToPredict.contains('1-2コーナー')) {
      development['1-2コーナー'] = _formatTairetsu(simHorses);
    }

    if (cornersToPredict.contains('3コーナー')) {
      for (final horse in simHorses) {
        // [修正] 死んだ2値条件を廃止し、連続スタミナで統一（高スタミナ=進出/低=後退、ハイで増幅） (v.2026.7.26+26072603)
        final staminaDelta = (horse.staminaScore - 50.0) / 100.0; // -0.5〜+0.5
        double paceFactor = 1.0;
        if (predictedPace.contains('ハイ')) {
          paceFactor = 1.5;
        } else if (predictedPace.contains('スロー')) {
          paceFactor = 0.6;
        }
        horse.positionScore -= staminaDelta * _kStaminaFactor3c * paceFactor;
      }
      simHorses.sort((a, b) => a.positionScore.compareTo(b.positionScore));
      development['3コーナー'] = _formatTairetsu(simHorses);
    }

    if (cornersToPredict.contains('4コーナー')) {
      for (final horse in simHorses) {
        // ペースによる影響
        double kickFactor = 1.5;
        if (predictedPace.contains('スロー')) {
          kickFactor = 2.0; // スローなら瞬発力の影響を大きく
        } else if (predictedPace.contains('ハイ')) {
          kickFactor = 1.0; // ハイペースなら瞬発力の影響を小さく
        }

        // コース特性による補正
        if (coursePreset != null) {
          if (coursePreset.straightLength > 450) { // 長い直線
            horse.positionScore -=
                (horse.finishingKickScore / 100.0) * kickFactor * 1.2;
          } else if (coursePreset.straightLength < 330) { // 短い直線
            horse.positionScore -=
                (horse.finishingKickScore / 100.0) * kickFactor * 0.8;
            if (horse.positionScore < 3.0 && horse.finishingKickScore < 75.0) {
              horse.positionScore += 0.4; // 前の馬はさらに粘りやすく
            }
          } else {
            horse.positionScore -=
                (horse.finishingKickScore / 100.0) * kickFactor;
          }
        } else {
          horse.positionScore -=
              (horse.finishingKickScore / 100.0) * kickFactor;
        }


        if (horse.positionScore < 3.0 && horse.finishingKickScore < 70.0) {
          horse.positionScore += 0.3;
        }

        // [追加] 能力反映: 平均より強い馬は位置を上げ、弱い馬は下げる (v.2026.7.25)
        final abilityDelta4c = (horse.abilityScore - meanAbility) / 100.0; // 概ね -0.5〜+0.5
        horse.positionScore -= abilityDelta4c * _kAbilityFactor4c;

        // [追加] 斤量(差し・追込・自在・マクリ): 再加速=上がりに反映。重い馬は伸び鈍化 (v.2026.7.26+26072601)
        final style = horse.detail.legStyleProfile?.primaryStyle;
        if (style == '差し' || style == '追込' || style == '自在' || style == 'マクリ') {
          horse.positionScore += horse.weightBurden * _kWeightFactorBack;
        }
      }
      simHorses.sort((a, b) => a.positionScore.compareTo(b.positionScore));
      development['4コーナー'] = _formatTairetsu(simHorses);
    }

    // [追加] 直線: finishingPowerで上がり3F区間の伸び/粘りを反映 (v.2026.6.19)
    if (cornersToPredict.contains('直線')) {
      for (final horse in simHorses) {
        final params = simulationParams[horse.detail.horseNumber.toString()];
        final finishingPower = params?.finishingPower ?? 0.5;
        double kickFactor = 1.5;
        if (predictedPace.contains('スロー')) {
          kickFactor = 2.0; // スローペースは瞬発力勝負
        } else if (predictedPace.contains('ハイ')) {
          kickFactor = 1.0; // ハイペースは消耗戦で末脚の差が縮む
        }
        horse.positionScore -= (finishingPower - 0.5) * kickFactor;

        // [追加] 能力反映: 直線でも能力差を反映 (v.2026.7.25)
        final abilityDeltaLast = (horse.abilityScore - meanAbility) / 100.0;
        horse.positionScore -= abilityDeltaLast * _kAbilityFactorLast;

        // [追加] 斤量(差し・追込・自在・マクリ): 再加速=上がりに反映。重い馬は伸び鈍化 (v.2026.7.26+26072601)
        final style = horse.detail.legStyleProfile?.primaryStyle;
        if (style == '差し' || style == '追込' || style == '自在' || style == 'マクリ') {
          horse.positionScore += horse.weightBurden * _kWeightFactorBack;
        }

        // [追加] 0-4 距離延長短縮: 直線での距離ローテ補正（符号はdistLastAdjに格納済み） (v.2026.7.26+26072602)
        horse.positionScore += horse.distLastAdj;

        // [追加] 0-8 着差ベースの相対力を直線で反映（強い勝ち方の馬ほど最後に伸びる） (v.2026.7.27+26072701)
        horse.positionScore -= horse.marginPower * _kMarginPowerFactor;

        // [追加] 0-9 トラックバイアス(直線): 全脚質を馬場傾向で微補正（前残り/差しの再現） (v.2026.7.27+26072702)
        final kStr = _trackBiasKStr(horse.detail.legStyleProfile?.primaryStyle);
        if (kStr != 0.0) {
          horse.positionScore -= trackBias * _kTrackBiasScale * kStr;
        }
      }
      simHorses.sort((a, b) => a.positionScore.compareTo(b.positionScore));
      development['直線'] = _formatTairetsu(simHorses);
    }

    return development;
  }

  static String _formatTairetsu(List<_SimHorse> simHorses) {
    final List<List<_SimHorse>> groups = [];
    if (simHorses.isNotEmpty) {
      groups.add([simHorses.first]);
      for (int i = 1; i < simHorses.length; i++) {
        final currentHorse = simHorses[i];
        final prevHorse = simHorses[i - 1];
        if ((currentHorse.positionScore - prevHorse.positionScore).abs() > 0.8) {
          groups.add([]);
        }
        groups.last.add(currentHorse);
      }
    }

    // [修正] グループ内ゲートソートを除去。positionScore順を維持することで
    // 各馬がそれぞれ独立したポジションとして扱われ隊列が仮番号順に戻らない (v.13.43.0)
    return groups.map((group) {
      final parallelGroups = <String>[];
      for (int i = 0; i < group.length; i++) {
        parallelGroups.add(group[i].detail.horseNumber.toString());
      }
      return parallelGroups.join('-');
    }).join('-');
  }
}