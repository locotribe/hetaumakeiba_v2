// lib/logic/analysis/speed_index_backtest_runner.dart

// [追加] フェーズ6 スピード指数バックテスト・ハーネスの中核ロジック（UI非依存）。
// lib/screens/debug/speed_index_backtest_page.dart から利用される。UIから切り離すことで
// 単体テスト（実DBコピーを使った検証を含む）から直接呼び出せるようにする。
// memory/スピード指数_バックテストハーネス仕様.md の実装指示に従う。
// 段階4: 主指標を「直線処理後の生positionScore(outFinalPositionScores)昇順」ベースの
// シミュ順位に切り替える。development['直線']の隊列文字列(positionScore差0.8でグループ化
// された後の表示)由来のρは副指標として残す（0.15の効果は≈0.02オーダーで、隊列の
// グループ境界を跨がず量子化により消えΔρ≈0になりがちなため、粒度の粗い隊列だけを
// 主指標にすると効果を過小評価してしまう） (v.2026.9.4)

import 'package:hetaumakeiba_v2/db/repositories/horse_repository.dart';
import 'package:hetaumakeiba_v2/logic/analysis/horse_record_asof_filter.dart';
import 'package:hetaumakeiba_v2/logic/analysis/leg_style_analyzer.dart';
import 'package:hetaumakeiba_v2/logic/analysis/race_analyzer.dart';
import 'package:hetaumakeiba_v2/logic/analysis/race_result_prediction_converter.dart';
import 'package:hetaumakeiba_v2/logic/analysis/race_simulation_engine.dart';
import 'package:hetaumakeiba_v2/logic/analysis/simulation_params_calculator.dart';
import 'package:hetaumakeiba_v2/logic/analysis/speed_index_calculator.dart';
import 'package:hetaumakeiba_v2/logic/analysis/speed_index_constants.dart';
import 'package:hetaumakeiba_v2/logic/parse.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/horse_simulation_params_model.dart';
import 'package:hetaumakeiba_v2/models/horse_speed_index_model.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/services/jockey_analysis_service.dart';
import 'package:hetaumakeiba_v2/utils/spearman_correlation.dart';
import 'package:hetaumakeiba_v2/utils/speed_index_date_parser.dart';

// [追加] §6: cornersToPredictは最終順位取得に必要な全コーナーを含める (v.2026.9.4)
const List<String> kSpeedIndexBacktestAllCorners = [
  'テン', '1コーナー', '2コーナー', '3コーナー', '4コーナー', '直線',
];

// [追加] §8-2: 突き合わせ集合の頭数がこれ未満のレースはρ算出をスキップする (v.2026.9.4)
const int kSpeedIndexBacktestMinHorsesForRho = 5;

/// 1条件(あり/なし)分のスピアマンρ算出結果。
class SpeedIndexBacktestRhoResult {
  final double? rho;
  final int n;

  SpeedIndexBacktestRhoResult({required this.rho, required this.n});
}

/// 1レース分の実行結果。
class SpeedIndexBacktestSingleRaceResult {
  final RaceResult raceResult;
  final PredictionRaceData raceData;
  final DateTime asOf;
  final Map<String, String> devWith;
  final Map<String, String> devNone;
  final int horseCount;
  final int excludedForFutureLeakCount;

  // [追加] 主指標: 直線処理後の生positionScore(昇順=シミュ着順)ベースのρ (v.2026.9.4)
  final SpeedIndexBacktestRhoResult rhoWithRaw;
  final SpeedIndexBacktestRhoResult rhoNoneRaw;

  // [追加] 副指標: development['直線']の隊列(positionScore差0.8でグループ化)由来のρ (v.2026.9.4)
  final SpeedIndexBacktestRhoResult rhoWithTairetsu;
  final SpeedIndexBacktestRhoResult rhoNoneTairetsu;

  // [追加] 副指標: 直線隊列文字列が「あり/なし」で変化したか (v.2026.9.4)
  final bool tairetsuDiffers;

  // [追加] 集計用メタ情報（距離帯別・ペース別・confidence帯別の内訳に使う） (v.2026.9.4)
  final String surface; // '芝' or 'ダ'（障害はisEligibleRaceで除外済み）
  final int? distanceMeters;
  final String distanceBand; // 例: '~1400' '1400-1800' '1800-2200' '2200+'
  final String pace; // 'ハイペース' / 'ミドルペース' / 'スローペース'
  final double meanConfidence; // 出走馬(非取消)のspeedIndex confidence平均

  SpeedIndexBacktestSingleRaceResult({
    required this.raceResult,
    required this.raceData,
    required this.asOf,
    required this.devWith,
    required this.devNone,
    required this.horseCount,
    required this.excludedForFutureLeakCount,
    required this.rhoWithRaw,
    required this.rhoNoneRaw,
    required this.rhoWithTairetsu,
    required this.rhoNoneTairetsu,
    required this.tairetsuDiffers,
    required this.surface,
    required this.distanceMeters,
    required this.distanceBand,
    required this.pace,
    required this.meanConfidence,
  });

  // Δρ(主指標・生スコア) = ρ_with − ρ_none。どちらかがnull(n<5等でスキップ)ならnull
  double? get dRhoRaw {
    final w = rhoWithRaw.rho;
    final none = rhoNoneRaw.rho;
    if (w == null || none == null) return null;
    return w - none;
  }

  // Δρ(副指標・隊列由来) = ρ_with − ρ_none。どちらかがnullならnull
  double? get dRhoTairetsu {
    final w = rhoWithTairetsu.rho;
    final none = rhoNoneTairetsu.rho;
    if (w == null || none == null) return null;
    return w - none;
  }
}

/// 過去レースにRaceAnalyzer.simulateRaceDevelopmentを「スピード指数あり／なし」で
/// 走らせ、シミュ着順予測と実着順のスピアマン順位相関を比較する。
/// 本体ロジック(simulateRaceDevelopment, SpeedIndexCalculator, 係数)は変更せず、呼ぶだけ。
class SpeedIndexBacktestRunner {
  SpeedIndexBacktestRunner._();

  // [追加] §3 除外条件: 障害・結果未確定(有効着順5頭未満)・JRA外(raceId[4:6]が
  // racecourseDictに無い)を除外する (v.2026.9.4)
  static bool isEligibleRace(RaceResult r) {
    if (r.isIncomplete) return false;
    if (r.raceInfo.contains('障')) return false;
    if (r.raceId.length < 6) return false;
    final placeCode = r.raceId.substring(4, 6);
    if (!racecourseDict.containsKey(placeCode)) return false;
    final validRankCount =
        r.horseResults.where((hr) => int.tryParse(hr.rank) != null).length;
    if (validRankCount < 5) return false;
    return true;
  }

  // [追加] §2, §4〜§8 1レース分の入力再構築とsimulateRaceDevelopment(あり/なし)実行、
  // シミュ着順(主指標=生スコア§段階4／副指標=§7隊列)と実着順(§8-1)を突き合わせ(§8-2)、
  // tie対応スピアマンρ(§8-3)を算出する。[speedFactorOverride]は§9(任意)係数掃引用に
  // そのままsimulateRaceDevelopmentへ転送するのみ(省略時nullは既存係数を使用)。
  // [speedIndexConfidenceCeiling]は診断A(confidence天井)用: trueの場合、sampleCount>0の
  // 馬のspeedParamsのみconfidence=1.0に置き換えたコピーを「あり」側にだけ渡す
  // (本体race_analyzer.dartは一切変更しない。「なし」は従来どおりconst{}のまま) (v.2026.9.4)
  static Future<SpeedIndexBacktestSingleRaceResult> runSingleRace(
    RaceResult raceResult, {
    required HorseRepository horseRepo,
    double? speedFactorOverride,
    bool speedIndexConfidenceCeiling = false,
  }) async {
    // §4-1 過去レース→PredictionRaceData変換（race_page.dartと共有のロジック）
    final raceData =
        await RaceResultPredictionConverter.convert(raceResult, horseRepo);

    // §4-2 日付パース（asOf）。パース不能ならこのレースはスキップ扱い
    final asOf = parseRaceDateForSpeedIndex(raceData.raceDate);
    if (asOf == null) {
      throw StateError('raceDateのパースに失敗しました: ${raceData.raceDate}');
    }

    // §5 【最重要・リーク防止】asOfより前 かつ 対象レース自身を除外したfilteredのみを
    // legStyleProfile / simParams / speedParams / ペース予想の全てに使う
    // [修正] フィルタ本体をlib/logic/analysis/horse_record_asof_filter.dartへ共通化。
    // shutuba_table_page.dartの_fetchDataWithUserMarks()からも同一ロジックを再利用するため
    // （挙動は不変） (v.2026.9.4+26090404)
    int excludedForFutureLeakCount = 0;
    final allPastRecords = <String, List<HorseRaceRecord>>{};
    for (final horse in raceData.horses) {
      final all = await horseRepo.getHorsePerformanceRecords(horse.horseId);
      final filtered = filterRecordsBeforeAsOf(
        all,
        asOf: asOf,
        excludeRaceId: raceResult.raceId,
      );
      excludedForFutureLeakCount += all.length - filtered.length;
      allPastRecords[horse.horseId] = filtered;

      // §4-3 legStyleProfile付与（filteredRecordsを使用。必ずリーク防止後のデータで算出する）
      horse.legStyleProfile = LegStyleAnalyzer.getRunningStyle(filtered);
    }

    // [追加] 段階4: ペース予想（shutuba_table_page.dartの実運用配線と同一呼び出し：
    // pastRaceResultsは実運用でも常に[]で呼ばれている）。あり/なし両条件を計算する前に
    // raceData.racePacePredictionへ設定することで、simulateRaceDevelopment内部の
    // `paceOverride ?? raceData.racePacePrediction?.predictedPace ?? 'ミドルペース'`
    // 解決が両条件で完全に同一のペースを使う (v.2026.9.4)
    raceData.racePacePrediction =
        RaceAnalyzer.predictRacePace(raceData.horses, allPastRecords, const []);
    final pace = raceData.racePacePrediction!.predictedPace;

    // §4-4 jockeyStats（§5補足: 現在のDB全体を参照する副次リークがあるが、
    // あり/なし両条件に等しく効くためΔρはほぼ相殺される。仕様書の判断を踏襲）
    final jockeyIds = raceData.horses
        .map((h) => h.jockeyId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    final jockeyStats = await JockeyAnalysisService()
        .analyzeAllJockeys(jockeyIds, raceData: raceData);

    // simParams / speedParams（キーはhorseNumber文字列。filteredRecordsから算出）
    final simParams = <String, HorseSimulationParams>{};
    final speedParams = <String, HorseSpeedIndex>{};
    for (final horse in raceData.horses) {
      final filtered = allPastRecords[horse.horseId] ?? [];
      simParams[horse.horseNumber.toString()] =
          SimulationParamsCalculator.calculate(horse.horseId, filtered);
      speedParams[horse.horseNumber.toString()] =
          SpeedIndexCalculator.calculate(horse.horseId, filtered, asOf: asOf);
    }

    // §6 あり／なしの切り替え。speedIndexParams以外の入力は完全に同一に固定する。
    // outFinalPositionScoresで主指標(生スコア)用の値も同時に取得する (v.2026.9.4)
    // [追加] 診断A: 「あり」側にのみconfidence天井を適用したspeedParamsを渡す。
    // meanConfidence(集計用メタ情報)は実測値のspeedParamsのまま変えない (v.2026.9.4)
    final speedParamsForWith = speedIndexConfidenceCeiling
        ? speedParams
            .map((key, value) => MapEntry(key, _withCeilingConfidence(value)))
        : speedParams;
    final outWith = <String, double>{};
    final devWith = await RaceAnalyzer.simulateRaceDevelopment(
      raceData,
      allPastRecords,
      kSpeedIndexBacktestAllCorners,
      jockeyStats,
      horsesOverride: raceData.horses,
      simulationParams: simParams,
      speedIndexParams: speedParamsForWith,
      speedFactorOverride: speedFactorOverride,
      outFinalPositionScores: outWith,
    );
    final outNone = <String, double>{};
    final devNone = await RaceAnalyzer.simulateRaceDevelopment(
      raceData,
      allPastRecords,
      kSpeedIndexBacktestAllCorners,
      jockeyStats,
      horsesOverride: raceData.horses,
      simulationParams: simParams,
      speedIndexParams: const {},
      speedFactorOverride: speedFactorOverride,
      outFinalPositionScores: outNone,
    );

    // §8-1 実着順（取消等int.tryParse不能な馬は除外。horseNumberで突き合わせる）
    final actualRanks = _actualRanksFromRaceResult(raceResult);

    // 主指標: 生positionScore(昇順=シミュ着順)由来のランクでρ算出
    final rhoWithRaw = _computeRho(_simRanksFromScores(outWith), actualRanks);
    final rhoNoneRaw = _computeRho(_simRanksFromScores(outNone), actualRanks);

    // 副指標: §7 隊列(development['直線'])由来のランクでρ算出
    final rhoWithTairetsu =
        _computeRho(_simRanksFromTairetsu(devWith['直線']), actualRanks);
    final rhoNoneTairetsu =
        _computeRho(_simRanksFromTairetsu(devNone['直線']), actualRanks);

    final activeHorses = raceData.horses.where((h) => !h.isScratched).toList();
    final meanConfidence = activeHorses.isEmpty
        ? 0.0
        : activeHorses
                .map((h) =>
                    speedParams[h.horseNumber.toString()]?.confidence ?? 0.0)
                .reduce((a, b) => a + b) /
            activeHorses.length;

    final surface = raceData.trackType ?? '';
    final distanceMeters = raceData.distanceValue;

    return SpeedIndexBacktestSingleRaceResult(
      raceResult: raceResult,
      raceData: raceData,
      asOf: asOf,
      devWith: devWith,
      devNone: devNone,
      horseCount: activeHorses.length,
      excludedForFutureLeakCount: excludedForFutureLeakCount,
      rhoWithRaw: rhoWithRaw,
      rhoNoneRaw: rhoNoneRaw,
      rhoWithTairetsu: rhoWithTairetsu,
      rhoNoneTairetsu: rhoNoneTairetsu,
      tairetsuDiffers: devWith['直線'] != devNone['直線'],
      surface: surface,
      distanceMeters: distanceMeters,
      distanceBand: _distanceBandLabel(surface, distanceMeters),
      pace: pace,
      meanConfidence: meanConfidence,
    );
  }

  // [追加] 段階4: 対象レース群を順に実行するバッチヘルパー。asOfパース不能等で
  // runSingleRaceが例外を投げたレースはスキップして続行する(§4-2)。範囲(直近N件/年)の
  // 絞り込みは呼び出し側(UI/検証スクリプト)が[races]を絞ってから渡す (v.2026.9.4)
  static Future<List<SpeedIndexBacktestSingleRaceResult>> runBatch(
    List<RaceResult> races, {
    required HorseRepository horseRepo,
    double? speedFactorOverride,
    bool speedIndexConfidenceCeiling = false,
    void Function(int done, int total)? onProgress,
    void Function(RaceResult race, Object error)? onError,
  }) async {
    final results = <SpeedIndexBacktestSingleRaceResult>[];
    for (var i = 0; i < races.length; i++) {
      try {
        results.add(await runSingleRace(
          races[i],
          horseRepo: horseRepo,
          speedFactorOverride: speedFactorOverride,
          speedIndexConfidenceCeiling: speedIndexConfidenceCeiling,
        ));
      } catch (e) {
        onError?.call(races[i], e);
      }
      onProgress?.call(i + 1, races.length);
    }
    return results;
  }

  // [追加] 診断A用: sampleCount>0の馬のみconfidenceを1.0に置き換えたコピーを返す。
  // sampleCount==0(無走馬。bestIndex/recentAvgIndex=0)はconfidence=0のまま据え置き、
  // 指数0の巨大な負deltaが混入して結果を汚さないようにする (v.2026.9.4)
  static HorseSpeedIndex _withCeilingConfidence(HorseSpeedIndex s) {
    if (s.sampleCount <= 0) return s;
    return HorseSpeedIndex(
      horseId: s.horseId,
      bestIndex: s.bestIndex,
      recentAvgIndex: s.recentAvgIndex,
      trend: s.trend,
      confidence: 1.0,
      sampleCount: s.sampleCount,
      calculatedAt: s.calculatedAt,
    );
  }

  // [追加] 段階4: 距離帯ラベルを算出する。SpeedIndexConstantsの距離係数テーブル
  // (turfDistCoef/dirtDistCoef)の帯境界をそのまま流用し、指数算出側の距離帯定義と
  // 一致させる (v.2026.9.4)
  static String _distanceBandLabel(String surface, int? meters) {
    if (meters == null) return '不明';
    final table = surface == 'ダ'
        ? SpeedIndexConstants.dirtDistCoef
        : SpeedIndexConstants.turfDistCoef;
    for (final band in table) {
      final lower = band[0].toInt();
      final upper = band[1].toInt();
      if (meters >= lower && meters < upper) {
        if (lower == 0) return '~$upper';
        if (upper >= 9999) return '$lower+';
        return '$lower-$upper';
      }
    }
    return '不明';
  }

  // [追加] 主指標: horseNumber文字列→生positionScoreのマップから、昇順(小さいほど上位)で
  // シミュ順位(horseNumber→順位)を算出する。厳密な同値(浮動小数点一致)のみtie扱いとして
  // 平均順位を割り当てる (v.2026.9.4)
  static Map<int, double> _simRanksFromScores(Map<String, double> scores) {
    final entries = <MapEntry<int, double>>[];
    scores.forEach((key, value) {
      final horseNumber = int.tryParse(key);
      if (horseNumber != null) {
        entries.add(MapEntry(horseNumber, value));
      }
    });
    entries.sort((a, b) => a.value.compareTo(b.value));

    final ranks = <int, double>{};
    int i = 0;
    while (i < entries.length) {
      int j = i;
      while (j + 1 < entries.length && entries[j + 1].value == entries[i].value) {
        j++;
      }
      final avgRank = (i + 1 + j + 1) / 2.0; // 1-based順位 i+1..j+1 の平均
      for (int k = i; k <= j; k++) {
        ranks[entries[k].key] = avgRank;
      }
      i = j + 1;
    }
    return ranks;
  }

  // [追加] §7 "(3,5)-7-12"形式の直線隊列文字列をシミュ順位(horseNumber→順位)へ変換する。
  // 「-」区切りの前グループほど上位。並走(同一()グループ)は平均順位(tie rank)を割り当てる (v.2026.9.4)
  static Map<int, double> _simRanksFromTairetsu(String? tairetsu) {
    final groups = RaceSimulationEngine.parseTairetsuGroups(tairetsu);
    final ranks = <int, double>{};
    int position = 1;
    for (final group in groups) {
      final size = group.length;
      final avgRank = position + (size - 1) / 2.0;
      for (final token in group) {
        final horseNumber = int.tryParse(token);
        if (horseNumber != null) {
          ranks[horseNumber] = avgRank;
        }
      }
      position += size;
    }
    return ranks;
  }

  // [追加] §8-1 実着順(horseNumber→着順)。rankがint化できない馬(取消等)は除外する (v.2026.9.4)
  static Map<int, double> _actualRanksFromRaceResult(RaceResult raceResult) {
    final ranks = <int, double>{};
    for (final hr in raceResult.horseResults) {
      final horseNumber = int.tryParse(hr.horseNumber);
      final rank = int.tryParse(hr.rank);
      if (horseNumber != null && rank != null) {
        ranks[horseNumber] = rank.toDouble();
      }
    }
    return ranks;
  }

  // [追加] §8-2 突き合わせ(sim順位・実着順の両方に存在する馬番のみ)＋§8-3 tie対応
  // スピアマンρ算出。突き合わせ後の頭数がkSpeedIndexBacktestMinHorsesForRho未満なら
  // ρ=null(スキップ) (v.2026.9.4)
  static SpeedIndexBacktestRhoResult _computeRho(
      Map<int, double> simRanks, Map<int, double> actualRanks) {
    final common =
        simRanks.keys.toSet().intersection(actualRanks.keys.toSet()).toList()
          ..sort();
    if (common.length < kSpeedIndexBacktestMinHorsesForRho) {
      return SpeedIndexBacktestRhoResult(rho: null, n: common.length);
    }
    final a = common.map((k) => simRanks[k]!).toList();
    final b = common.map((k) => actualRanks[k]!).toList();
    return SpeedIndexBacktestRhoResult(
        rho: tieAdjustedSpearman(a, b), n: common.length);
  }
}
