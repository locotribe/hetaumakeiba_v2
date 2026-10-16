// lib/logic/analysis/historical_match_engine.dart

import 'package:hetaumakeiba_v2/models/historical_match_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
// [修正] 前走と路線の部品 Step2: 前走は共通の部品で決め、日付は共通の関数で読む（自前の日付の読み取りを削除したので、日付の書式の import は不要） (v.2026.10.16+26101606)
import 'package:hetaumakeiba_v2/logic/previous_race.dart';
import 'package:hetaumakeiba_v2/utils/speed_index_date_parser.dart';
// [追加] 総合シンクロ率と血統クロス Step2: ローテ・血統の点数は、過去の全出走馬を路線・父・母父ごとに数えた表の複勝率の倍率×50 にする (v.2026.10.16+26101615)
import 'package:hetaumakeiba_v2/logic/analysis/past_race_lift.dart';
import 'package:hetaumakeiba_v2/logic/analysis/lift_match_score.dart';

// 各ファクターをインポート
// [削除] 総合シンクロ率と血統クロス Step2: rotation_factor・pedigree_factor は使わなくなったので削除した (v.2026.10.16+26101615)
import '../analysis/historical_match_engine_factors/weight_factor.dart';
import '../analysis/historical_match_engine_factors/frame_factor.dart';
import '../analysis/historical_match_engine_factors/popularity_factor.dart';
import '../analysis/historical_match_engine_factors/track_condition_factor.dart'; // ★追加
import 'package:hetaumakeiba_v2/models/horse_profile_model.dart'; // ★追加
import 'package:hetaumakeiba_v2/models/track_conditions_model.dart'; // ★新規追加: TrackConditionRecord用
import 'package:hetaumakeiba_v2/logic/race_class_grade.dart';

class HistoricalMatchEngine {
  // 各ファクターのインスタンス化
  final WeightFactor _weightFactor = WeightFactor();
  final FrameFactor _frameFactor = FrameFactor();
  final PopularityFactor _popularityFactor = PopularityFactor();
  final TrackConditionFactor _trackConditionFactor = TrackConditionFactor(); // ★追加

  Map<String, dynamic> analyze({
    required String currentRaceName,
    // [追加] クラス判定の共通化 Step2: 人気妙味の「クラスの壁」の基準にする今回のクラス。currentRaceName は呼び出し側の変更を増やさないため残す (v.2026.10.16+26101602)
    required RaceClassGrade currentRaceClass,
    // [追加] 前走と路線の部品 Step2: 今回のレースの日付（今回の馬の前走を決める基準。'2026年10月18日' や '2026/10/18' の形） (v.2026.10.16+26101606)
    required String currentRaceDate,
    required double pastRaceVolatility,
    required List<PredictionHorseDetail> currentHorses,
    required List<RaceResult> pastRaces,
    required Map<String, List<HorseRaceRecord>> currentHorseHistory,
    required Map<String, List<HorseRaceRecord>> pastTopHorseRecords,
    // [追加] 総合シンクロ率と血統クロス Step2: 過去レースの全出走馬（取消・除外を除く）の戦績。ローテの表を作るのに使う (v.2026.10.16+26101615)
    required Map<String, List<HorseRaceRecord>> pastHorseRecords,
    // [修正] 総合シンクロ率と血統クロス Step2: 過去レースの全出走馬と今回の馬の血統。血統の表を作るのに使う（血統クロスの結果 pedigreeCrossResult は受け取らなくなった） (v.2026.10.16+26101615)
    required Map<String, HorseProfile> horseProfileMap,
    required TrackConditionTrendResult trackConditionTrendResult,
    required Map<String, TrackConditionRecord> horsePastTrackConditions, // ★新規追加: 個別の馬の馬場データ
    required bool isDirt, // ★新規追加: 芝・ダート判定
  }) {
    // 1. 過去の上位馬抽出
    final topHorses = _extractTopHorses(pastRaces);

    if (topHorses.isEmpty) {
      return {'results': <HistoricalMatchModel>[], 'summary': null};
    }

    // 2. 傾向データ算出 (マクロ分析)
    final double medianWeight = _calculateMedianWeight(topHorses);
    final Map<String, double> zoneWinRates = _calculateZoneWinRates(topHorses);

    String bestZone = '中';
    double maxRate = -1.0;
    zoneWinRates.forEach((key, value) {
      if (value > maxRate) {
        maxRate = value;
        bestZone = key;
      }
    });

    // [修正] 総合シンクロ率と血統クロス Step2: 前走の傾向からは前走の平均人気だけを出す（よく来た路線は下のローテの表で決める） (v.2026.10.16+26101615)
    final double avgPrevPop = _calculateAvgPrevPopularity(topHorses, pastTopHorseRecords);

    // [追加] 総合シンクロ率と血統クロス Step2: 過去の全出走馬を前走の路線・父・母父ごとに数えた表（過去分析のローテ・血統タブと同じ作り方） (v.2026.10.16+26101615)
    final rotationTable = buildRotationLiftTable(
      pastRaces: pastRaces,
      pastHorseRecords: pastHorseRecords,
      currentHorseRecords: {
        for (final horse in currentHorses)
          horse.horseId: currentHorseHistory[horse.horseId] ?? const <HorseRaceRecord>[],
      },
      currentRaceDate: parseRaceDateForSpeedIndex(currentRaceDate),
    );
    final currentHorseIds = [for (final horse in currentHorses) horse.horseId];
    final sireTable = buildPedigreeLiftTable(
      pastRaces: pastRaces,
      profiles: horseProfileMap,
      currentHorseIds: currentHorseIds,
      damSire: false,
    );
    final damSireTable = buildPedigreeLiftTable(
      pastRaces: pastRaces,
      profiles: horseProfileMap,
      currentHorseIds: currentHorseIds,
      damSire: true,
    );

    // [修正] 総合シンクロ率と血統クロス Step2: 上の帯の「ローテ」は、過去の出走2頭以上の路線で複勝率がいちばん高い路線。好走血統（bestSire）は画面で使っていないので出さない (v.2026.10.16+26101615)
    final summary = TrendSummary(
      medianWeight: medianWeight,
      bestZone: bestZone,
      bestRotation: bestLiftRowLabel(rotationTable),
      bestPrevPop: '${avgPrevPop.toStringAsFixed(1)}番人気以内',
      avgCushion: trackConditionTrendResult.avgCushion, // ★追加
    );

    // [削除] 波乱度(過去1〜3着馬の平均人気)は引数 pastRaceVolatility で受け取る。
    // 呼び出し側(stats_match_tab.dart)が VolatilityAnalyzer.analyze() で算出済みの
    // averagePopularity を渡すため、ここでの同名ローカル変数による再計算(旧74〜88行)は削除。 (v.2026.9.26+26092601)

    // 3. 各馬のマッチング計算 (ファクター呼び出し)
    final List<HistoricalMatchModel> results = [];

    for (final horse in currentHorses) {
      final history = currentHorseHistory[horse.horseId] ?? [];
      // [修正] 前走と路線の部品 Step2: 前走を履歴の先頭ではなく、今回のレース日より前に実際に出走した一番新しい走にする（過去のレースを開くとそのレース自身や後の走を、取消・除外の行も前走にしていた） (v.2026.10.16+26101606)
      final prevRecord = _getPreviousRaceRecord(history, currentRaceDate);

      // 各ファクターに分析を委譲
      final weightRes = _weightFactor.analyze(horse, prevRecord, medianWeight);
      // [修正] 結果分析の枠順: 過去側（_calculateZoneWinRates）と同じく馬番÷頭数で内・中・外を決める。枠番だと12頭以上で外が出ず、大半の馬が隣のゾーンで採点されていた (v.2026.10.15+26101513)
      final frameRes = _frameFactor.analyze(horse.horseNumber, currentHorses.length, zoneWinRates, maxRate);
      final popRes = _popularityFactor.analyze(horse, history, currentRaceClass, pastRaceVolatility);
      // [修正] 総合シンクロ率と血統クロス Step2: ローテは前走の路線の複勝率の倍率×50、血統は父と母父の倍率×50 を 父3:母父1 で合わせる（100点で頭打ち。前走・血統が分からない、過去の例が1頭以下は50点） (v.2026.10.16+26101615)
      final rotRes = liftMatchScoreOf(rotationTable, horse.horseId);

      // ★新規追加: 血統と馬場の分析
      final pedRes = pedigreeMatchScoreOf(
        sireTable: sireTable,
        damSireTable: damSireTable,
        horseId: horse.horseId,
      );
      final tcRes = _trackConditionFactor.analyze(
        history: history,
        horsePastTrackConditions: horsePastTrackConditions,
        isDirt: isDirt,
        trendResult: trackConditionTrendResult,
      );

      // 基本スコアの算出 (血統を含めるように変更)
      double baseScore;
      if (frameRes.isGateFixed) {
        baseScore = (weightRes.score * 0.2) + (frameRes.score * 0.2) + (popRes.score * 0.2) + (rotRes.score * 0.2) + (pedRes.score * 0.2);
      } else {
        baseScore = (weightRes.score * 0.25) + (popRes.score * 0.25) + (rotRes.score * 0.25) + (pedRes.score * 0.25);
      }

      // ★新規追加: シナリオ別総合スコアの算出 (馬場ファクターを加味)
      final Map<String, double> scenarioTotalScores = {
        'high': (baseScore * 0.8) + (tcRes.scenarioScores['high']! * 0.2),
        'standard': (baseScore * 0.8) + (tcRes.scenarioScores['standard']! * 0.2),
        'low': (baseScore * 0.8) + (tcRes.scenarioScores['low']! * 0.2),
      };

      int prevPop = 0;
      if (prevRecord != null) {
        prevPop = int.tryParse(prevRecord.popularity) ?? 0;
      }
      int currPop = int.tryParse(horse.popularity?.toString() ?? '') ?? 0;

      results.add(HistoricalMatchModel(
        horseId: horse.horseId,
        horseName: horse.horseName,
        totalScore: baseScore, // ベーススコアをセット
        weightScore: weightRes.score,
        usedWeight: weightRes.usedWeight,
        weightDiff: weightRes.diff,
        isWeightCurrent: weightRes.isCurrent,
        weightStr: weightRes.displayStr,
        frameScore: frameRes.score,
        gateNumber: horse.gateNumber,
        totalHorses: currentHorses.length,
        relativePos: frameRes.relativePos,
        positionZone: frameRes.zone,
        popularityScore: popRes.score,
        valueIndex: popRes.valueIndex,
        currentPopStr: currPop > 0 ? '$currPop人' : '-',
        prevPopStr: prevPop > 0 ? '$prevPop人' : '-',
        popDiagnosis: popRes.diag,
        valueReasoning: popRes.reasoning,
        rotationScore: rotRes.score,
        // [修正] 総合シンクロ率と血統クロス Step2: 前走名はそのまま。ローテの診断は倍率の文字（'1.42倍'・'例なし'・'前走不明'）、路線名は表の表示名 (v.2026.10.16+26101615)
        prevRaceName: prevRecord?.raceName ?? '-',
        rotDiagnosis: rotRes.liftText(unknownText: '前走不明'),
        rotationRouteLabel: rotRes.row?.label ?? '-',
        pedigreeScore: pedRes.score, // ★追加
        // [修正] 総合シンクロ率と血統クロス Step2: 血統の診断は '父1.42倍・母父0.80倍' の形（血統が無ければ 'データなし'） (v.2026.10.16+26101615)
        pedigreeDiag: pedRes.diagText,
        trackConditionScores: tcRes.scenarioScores, // ★追加
        scenarioTotalScores: scenarioTotalScores,   // ★追加
        recentHistory: history,
      ));
    }

    results.sort((a, b) => b.totalScore.compareTo(a.totalScore));

    return {
      'results': results,
      'summary': summary,
    };
  }

  // [追加] 対象レース開催日より過去の最新レースレコードを取得するヘルパーメソッド (v.1.0)
  // [修正] 前走と路線の部品 Step2: 共通の部品 previousStartOf で決める（取消・除外・着順が空欄の行を飛ばす）。日付は共通の parseRaceDateForSpeedIndex で読み、読めなければ従来どおり null (v.2026.10.16+26101606)
  HorseRaceRecord? _getPreviousRaceRecord(List<HorseRaceRecord>? history, String referenceDateStr) {
    final referenceDate = parseRaceDateForSpeedIndex(referenceDateStr);
    if (referenceDate == null) return null;
    return previousStartOf(history, referenceDate);
  }

  // --- ヘルパーメソッド群 (変更なし) ---
  // [修正] 総合シンクロ率と血統クロス Step2: 前走の路線の数え上げ（前走名の括弧を外して数えていた）をやめ、過去の1〜3着馬の前走の平均人気だけを出す (v.2026.10.16+26101615)
  double _calculateAvgPrevPopularity(List<_HorseContext> topHorses, Map<String, List<HorseRaceRecord>> pastRecords) {
    int totalPop = 0;
    int popCount = 0;
    for (final ctx in topHorses) {
      final records = pastRecords[ctx.horse.horseId];
      if (records == null || records.isEmpty) continue;
      // [修正] 前走と路線の部品 Step2: 同じ馬が複数の年に出ていても、その馬が1〜3着だった年のレース日を基準に前走を決める（以前は最初に見つかった年を基準にしていた） (v.2026.10.16+26101606)
      final prevRace = _getPreviousRaceRecord(records, ctx.raceDate);

      if (prevRace != null) {
        int pop = int.tryParse(prevRace.popularity) ?? 0;
        if (pop > 0) { totalPop += pop; popCount++; }
      }
    }
    return popCount > 0 ? totalPop / popCount : 0.0;
  }

  List<_HorseContext> _extractTopHorses(List<RaceResult> races) {
    final List<_HorseContext> targets = [];
    for (final race in races) {
      final int totalHorses = race.horseResults.length;
      for (final horse in race.horseResults) {
        final rank = int.tryParse(horse.rank ?? '');
        // [修正] 前走と路線の部品 Step2: そのレースの日付も持たせる (v.2026.10.16+26101606)
        if (rank != null && rank <= 3) targets.add(_HorseContext(horse, totalHorses, race.raceDate));
      }
    }
    return targets;
  }

  double _calculateMedianWeight(List<_HorseContext> horses) {
    final weights = <double>[];
    for (final c in horses) {
      final w = WeightFactor.parseWeight(c.horse.horseWeight);
      if (w != null) weights.add(w);
    }
    if (weights.isEmpty) return 0.0;
    weights.sort();
    final middle = weights.length ~/ 2;
    return (weights.length % 2 == 1) ? weights[middle] : (weights[middle - 1] + weights[middle]) / 2.0;
  }

  Map<String, double> _calculateZoneWinRates(List<_HorseContext> horses) {
    int inner = 0, mid = 0, outer = 0, valid = 0;
    for (final c in horses) {
      final gate = int.tryParse(c.horse.horseNumber) ?? 0;
      final total = c.totalHorses;
      if (gate > 0 && total > 0) {
        final pos = (total > 1) ? (gate - 1) / (total - 1) : 0.0;
        final zone = FrameFactor.getZone(pos);
        if (zone == '内') inner++; else if (zone == '中') mid++; else if (zone == '外') outer++;
        valid++;
      }
    }
    if (valid == 0) return {'内': 0.0, '中': 0.0, '外': 0.0};
    return {'内': inner / valid, '中': mid / valid, '外': outer / valid};
  }
}

class _HorseContext {
  final HorseResult horse;
  final int totalHorses;
  // [追加] 前走と路線の部品 Step2: この馬が1〜3着だったレースの日付（前走を決める基準） (v.2026.10.16+26101606)
  final String raceDate;
  _HorseContext(this.horse, this.totalHorses, this.raceDate);
}
