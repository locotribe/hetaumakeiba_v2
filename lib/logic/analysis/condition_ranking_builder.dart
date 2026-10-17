// lib/logic/analysis/condition_ranking_builder.dart

import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
// [追加] 好走条件の改良 Step3: 馬場の列（クッション値・含水率） (v.2026.10.17+26101713)
import 'package:hetaumakeiba_v2/models/track_conditions_model.dart';
import 'package:hetaumakeiba_v2/logic/analysis/condition_aptitude_analyzer.dart';
// [追加] 好走条件・個別成績・相対評価の移動 Step1: 今回のクラスを出馬表のグレード欄から判定する (v.2026.10.17+26101706)
import 'package:hetaumakeiba_v2/logic/race_class_grade.dart';
// [追加] 好走条件の改良 Step1: 取消・除外・空欄の走を数えない判定（通算成績・回収率と同じ isCountedStart） (v.2026.10.17+26101711)
import 'package:hetaumakeiba_v2/logic/analysis/horse_record_stats.dart';

// [追加] 好走条件 相対順位付け StepB-1: 今回レース条件で全出走馬を横断比較するヒートマップの集約ロジック (v.2026.9.25+26092508)

/// 今回レースの確定条件（各列の今回値）
class RaceConditions {
  final String? surface; // 芝/ダ/障
  // [修正] 好走条件の改良 Step1: 距離帯ではなく距離ちょうど（1頭ページと同じ） (v.2026.10.17+26101711)
  final String? distanceLabel; // 例「芝1600」
  final String? direction; // 左/右
  final String? venue; // 例「東京」
  final String? classLabel; // 例「G1」
  // [追加] 好走条件の改良 Step3: 今回の馬場の帯（芝はクッション値、ダートは含水率ゴール前。1頭ページと同じ区切り）。当日の測定が無ければ null (v.2026.10.17+26101713)
  final String? trackBand; // 例「9.4-9」「7〜10%」
  const RaceConditions({
    this.surface,
    this.distanceLabel,
    this.direction,
    this.venue,
    this.classLabel,
    this.trackBand,
  });
}

/// build に渡す1頭ぶんの軽量入力
class HorseInput {
  final String horseId;
  final String horseName;
  final int horseNumber;
  final List<HorseRaceRecord> records;
  // [追加] 好走条件の改良 Step1: 今回取り消した馬（順位を付けず、いちばん下に出す） (v.2026.10.17+26101711)
  final bool isScratched;
  // [追加] 好走条件の改良 Step3: 過去走の馬場データ（レースID→馬場データ。無い走は null か、キーが無い） (v.2026.10.17+26101713)
  final Map<String, TrackConditionRecord?> trackConditions;
  const HorseInput({
    required this.horseId,
    required this.horseName,
    required this.horseNumber,
    required this.records,
    this.isScratched = false,
    this.trackConditions = const <String, TrackConditionRecord?>{},
  });
}

/// ヒートマップの列1つ
class RaceConditionColumn {
  // [修正] 好走条件の改良 Step3: 馬場（track）を足した (v.2026.10.17+26101713)
  final String key; // surface|distance|track|direction|venue|class|overall
  final String name; // 表示名
  final String todayValue; // 今回値（確定不可・総合は '—'）
  const RaceConditionColumn({
    required this.key,
    required this.name,
    required this.todayValue,
  });
}

/// 馬×列 の1セル
class HorseConditionCell {
  final RankTally tally; // 今回該当値での着度数（該当0なら total=0）
  final double? showRate; // 複勝率（該当0なら null）
  final bool isReference; // 0 < total < MIN_RACES（参考・淡色）
  final int? rank; // 列内相対順位（該当2走以上のみ。0走・参考は null）
  final int? rankOutOf; // 列内の異なる複勝率の数（グラデ正規化用。同上 null）
  const HorseConditionCell({
    required this.tally,
    required this.showRate,
    required this.isReference,
    this.rank,
    this.rankOutOf,
  });

  int get matchedCount => tally.total;
}

/// ヒートマップの1行（1頭）
class HorseConditionRow {
  final String horseId;
  final String horseName;
  final int horseNumber;
  final Map<String, HorseConditionCell> cells; // key → cell（overall 含む）
  final double? overallShowRate; // 総合列の値（並び替え・グラデ用。無ければ null）
  // [追加] 好走条件の改良 Step1: 今回取り消した馬（表で薄く出す） (v.2026.10.17+26101711)
  final bool isScratched;
  const HorseConditionRow({
    required this.horseId,
    required this.horseName,
    required this.horseNumber,
    required this.cells,
    required this.overallShowRate,
    this.isScratched = false,
  });
}

/// ヒートマップ全体
class ConditionRankingTable {
  // [修正] 好走条件の改良 Step3: 馬場（track）を足した (v.2026.10.17+26101713)
  final List<RaceConditionColumn> columns; // [surface, distance, track, direction, venue, class, overall]
  final List<HorseConditionRow> rows; // 総合降順で整列済み
  const ConditionRankingTable({required this.columns, required this.rows});
}

class ConditionRankingBuilder {
  ConditionRankingBuilder._();

  static const String kSurface = 'surface';
  static const String kDistance = 'distance';
  static const String kDirection = 'direction';
  static const String kVenue = 'venue';
  static const String kClass = 'class';
  static const String kOverall = 'overall';
  // [追加] 好走条件の改良 Step3: 馬場（クッション値・含水率の帯）の列 (v.2026.10.17+26101713)
  static const String kTrack = 'track';

  /// データ列の順序（総合は末尾に付ける）
  // [修正] 好走条件の改良 Step3: 距離の次に馬場 (v.2026.10.17+26101713)
  static const List<String> dataColumnKeys = [
    kSurface,
    kDistance,
    kTrack,
    kDirection,
    kVenue,
    kClass,
  ];

  static String _venueName(String venue) => venue.replaceAll(RegExp(r'[0-9]'), '');

  static String? _surfaceFromTrackType(String? trackType) {
    if (trackType == null) return null;
    if (trackType.contains('芝')) return '芝';
    if (trackType.contains('ダ')) return 'ダ';
    if (trackType.contains('障')) return '障';
    return null;
  }

  // [追加] 好走条件の改良 Step3: 馬場の帯。芝ならクッション値の帯、ダートなら含水率（ゴール前）の帯（1頭ページと同じ cushionBand・moistureBand）。
  // 馬場データが無い・値が無い・障害は null (v.2026.10.17+26101713)
  static String? trackBandOf(String? surface, TrackConditionRecord? trackCondition) {
    if (trackCondition == null) return null;
    if (surface == '芝') {
      final cv = trackCondition.cushionValue;
      return cv == null ? null : ConditionAptitudeAnalyzer.cushionBand(cv);
    }
    if (surface == 'ダ') {
      final mg = trackCondition.moistureDirtGoal;
      return mg == null ? null : ConditionAptitudeAnalyzer.moistureBand(mg);
    }
    return null;
  }

  /// 今回レースの各列の今回値を決める
  // [修正] 好走条件の改良 Step3: 今回の当日の馬場データ（無ければ null）を任意で受け取り、馬場の列の今回値にする (v.2026.10.17+26101713)
  static RaceConditions conditionsOf(PredictionRaceData raceData,
      {TrackConditionRecord? currentTrackCondition}) {
    final surface = _surfaceFromTrackType(raceData.trackType);

    // [修正] 好走条件の改良 Step1: 距離帯ではなく距離ちょうど（例「芝1600」。1頭ページの distanceExactLabelOf と同じ形） (v.2026.10.17+26101711)
    String? distanceLabel;
    if ((surface == '芝' || surface == 'ダ') && raceData.distanceValue != null) {
      distanceLabel = '$surface${raceData.distanceValue!}';
    }

    String? direction = raceData.direction;
    if (direction == null || direction.isEmpty) {
      direction = ConditionAptitudeAnalyzer.directionOf(raceData.venue);
    }

    final venue = _venueName(raceData.venue);

    // [修正] 好走条件・個別成績・相対評価の移動 Step1: 今回のレース名にはグレードが付かないので、G1 でも「条件」になっていた。
    // 出馬表のグレード欄（結果から作ったデータはレース名）から作った区分で判定する（能力分析と同じ raceClassGradeOfCurrentRace） (v.2026.10.17+26101706)
    final classLabel =
        ConditionAptitudeAnalyzer.gradeLabelOf(raceClassGradeOfCurrentRace(raceData));

    return RaceConditions(
      surface: surface,
      distanceLabel: distanceLabel,
      direction: direction,
      venue: venue.isEmpty ? null : venue,
      classLabel: classLabel,
      // [追加] 好走条件の改良 Step3 (v.2026.10.17+26101713)
      trackBand: trackBandOf(surface, currentTrackCondition),
    );
  }

  static String _columnName(String key) {
    switch (key) {
      case kSurface:
        return '芝ダ';
      case kDistance:
        return '距離';
      // [追加] 好走条件の改良 Step3 (v.2026.10.17+26101713)
      case kTrack:
        return '馬場';
      case kDirection:
        return '回り';
      case kVenue:
        return '開催地';
      case kClass:
        return 'クラス';
      case kOverall:
        return '総合';
    }
    return key;
  }

  static String? _todayValueOf(String key, RaceConditions c) {
    switch (key) {
      case kSurface:
        return c.surface;
      case kDistance:
        return c.distanceLabel;
      // [追加] 好走条件の改良 Step3 (v.2026.10.17+26101713)
      case kTrack:
        return c.trackBand;
      case kDirection:
        return c.direction;
      case kVenue:
        return c.venue;
      case kClass:
        return c.classLabel;
    }
    return null;
  }

  /// 指定列の今回値に該当する過去走だけを返す
  // [修正] 好走条件の改良 Step1: 取消・除外・空欄の走は返さない（セルの走数とタップで出る走をそろえる）。距離は距離ちょうどで比べる (v.2026.10.17+26101711)
  // [修正] 好走条件の改良 Step3: 馬場の列のため、過去走の馬場データ（レースID→馬場データ）を任意で受け取る (v.2026.10.17+26101713)
  static List<HorseRaceRecord> recordsForColumn(
      String key, String todayValue, List<HorseRaceRecord> records,
      {Map<String, TrackConditionRecord?> trackConditions = const <String, TrackConditionRecord?>{}}) {
    if (todayValue.isEmpty || todayValue == '—') return const [];
    bool match(HorseRaceRecord r) {
      if (!isCountedStart(r.rank)) return false;
      switch (key) {
        case kSurface:
          return ConditionAptitudeAnalyzer.surfaceOf(r.distance) == todayValue;
        case kDistance:
          return ConditionAptitudeAnalyzer.distanceExactLabelOf(r) == todayValue;
        // [追加] 好走条件の改良 Step3: その走の馬場の帯が今回と同じ（芝の帯とダートの帯は字が違うので混ざらない） (v.2026.10.17+26101713)
        case kTrack:
          return trackBandOf(ConditionAptitudeAnalyzer.surfaceOf(r.distance), trackConditions[r.raceId]) ==
              todayValue;
        case kDirection:
          return ConditionAptitudeAnalyzer.directionOf(r.venue) == todayValue;
        case kVenue:
          return _venueName(r.venue) == todayValue;
        case kClass:
          // [修正] クラス判定の共通化 Step3: 過去走は過去走用の判定（主催も見る）にした (v.2026.10.16+26101603)
          return ConditionAptitudeAnalyzer.gradeClassOfRecord(r) == todayValue;
      }
      return false;
    }

    return records.where(match).toList();
  }

  /// 今回レース＋全馬過去走からヒートマップを作る
  // [修正] 好走条件の改良 Step3: 全馬の過去走の馬場データ（馬ID→レースID→馬場データ）と今回の馬場データを任意で受け取る (v.2026.10.17+26101713)
  static ConditionRankingTable build({
    required PredictionRaceData raceData,
    required Map<String, List<HorseRaceRecord>> allPastRecords,
    Map<String, Map<String, TrackConditionRecord?>> trackConditionsByHorse =
        const <String, Map<String, TrackConditionRecord?>>{},
    TrackConditionRecord? currentTrackCondition,
  }) {
    final conditions = conditionsOf(raceData, currentTrackCondition: currentTrackCondition);
    final horses = raceData.horses
        .map((h) => HorseInput(
              horseId: h.horseId,
              horseName: h.horseName,
              horseNumber: h.horseNumber,
              records: allPastRecords[h.horseId] ?? const [],
              // [追加] 好走条件の改良 Step1 (v.2026.10.17+26101711)
              isScratched: h.isScratched,
              // [追加] 好走条件の改良 Step3 (v.2026.10.17+26101713)
              trackConditions:
                  trackConditionsByHorse[h.horseId] ?? const <String, TrackConditionRecord?>{},
            ))
        .toList();
    return buildFrom(conditions: conditions, horses: horses);
  }

  /// 軽量入力からヒートマップを作る（テスト用の純粋関数）
  static ConditionRankingTable buildFrom({
    required RaceConditions conditions,
    required List<HorseInput> horses,
  }) {
    final int minRaces = ConditionAptitudeAnalyzer.MIN_RACES;

    // 列（今回値ラベル。確定不可は '—'）
    final List<RaceConditionColumn> columns = [];
    for (final key in dataColumnKeys) {
      final tv = _todayValueOf(key, conditions);
      columns.add(RaceConditionColumn(
        key: key,
        name: _columnName(key),
        todayValue: (tv == null || tv.isEmpty) ? '—' : tv,
      ));
    }
    columns.add(const RaceConditionColumn(key: kOverall, name: '総合', todayValue: '—'));

    // 各馬のデータ列セル＋総合値（順位はこの後で付ける）
    final Map<String, Map<String, HorseConditionCell>> cellByHorse = {};
    final Map<String, double?> overallByHorse = {};

    for (final h in horses) {
      final Map<String, HorseConditionCell> cells = {};
      final List<double> qualifyingRates = [];
      for (final key in dataColumnKeys) {
        final tv = _todayValueOf(key, conditions);
        final matched = (tv == null || tv.isEmpty)
            ? const <HorseRaceRecord>[]
            // [修正] 好走条件の改良 Step3: 馬場の列のため、その馬の過去走の馬場データを渡す (v.2026.10.17+26101713)
            : recordsForColumn(key, tv, h.records, trackConditions: h.trackConditions);
        final tally = ConditionAptitudeAnalyzer.rankTallyOf(matched);
        final total = tally.total;
        final showRate = total > 0 ? tally.showRate : null;
        final isRef = total > 0 && total < minRaces;
        if (total >= minRaces && showRate != null) {
          qualifyingRates.add(showRate);
        }
        cells[key] = HorseConditionCell(
          tally: tally,
          showRate: showRate,
          isReference: isRef,
        );
      }
      final overall = qualifyingRates.isEmpty
          ? null
          : qualifyingRates.reduce((a, b) => a + b) / qualifyingRates.length;
      overallByHorse[h.horseId] = overall;
      cells[kOverall] = HorseConditionCell(
        tally: const RankTally(),
        showRate: overall,
        isReference: false,
      );
      cellByHorse[h.horseId] = cells;
    }

    // 列ごとに順位付け（データ5列＋総合列）
    final allKeys = [...dataColumnKeys, kOverall];
    for (final key in allKeys) {
      // 順位対象＝該当2走以上（総合列は overall!=null）
      final List<MapEntry<String, HorseConditionCell>> ranked = [];
      for (final h in horses) {
        // [追加] 好走条件の改良 Step1: 今回取り消した馬は順位を付けない (v.2026.10.17+26101711)
        if (h.isScratched) continue;
        final cell = cellByHorse[h.horseId]![key]!;
        final bool eligible = key == kOverall
            ? cell.showRate != null
            : cell.matchedCount >= minRaces && cell.showRate != null;
        if (eligible) ranked.add(MapEntry(h.horseId, cell));
      }
      if (ranked.isEmpty) continue;

      int cmp(MapEntry<String, HorseConditionCell> a, MapEntry<String, HorseConditionCell> b) {
        final ra = a.value.showRate!;
        final rb = b.value.showRate!;
        final c1 = rb.compareTo(ra);
        if (c1 != 0) return c1;
        final c2 = b.value.matchedCount.compareTo(a.value.matchedCount);
        if (c2 != 0) return c2;
        return b.value.tally.winRate.compareTo(a.value.tally.winRate);
      }

      ranked.sort(cmp);

      // dense rank（複勝率が同じなら同順位＝同色）
      final List<int> ranks = List<int>.filled(ranked.length, 1);
      int dense = 1;
      for (int i = 0; i < ranked.length; i++) {
        if (i > 0 && ranked[i].value.showRate! < ranked[i - 1].value.showRate!) {
          dense++;
        }
        ranks[i] = dense;
      }
      final int rankOutOf = dense; // 異なる複勝率の数

      for (int i = 0; i < ranked.length; i++) {
        final horseId = ranked[i].key;
        final old = cellByHorse[horseId]![key]!;
        cellByHorse[horseId]![key] = HorseConditionCell(
          tally: old.tally,
          showRate: old.showRate,
          isReference: old.isReference,
          rank: ranks[i],
          rankOutOf: rankOutOf,
        );
      }
    }

    // 行（総合降順→馬番昇順。総合 null は末尾）
    final rows = horses
        .map((h) => HorseConditionRow(
              horseId: h.horseId,
              horseName: h.horseName,
              horseNumber: h.horseNumber,
              cells: cellByHorse[h.horseId]!,
              overallShowRate: overallByHorse[h.horseId],
              // [追加] 好走条件の改良 Step1 (v.2026.10.17+26101711)
              isScratched: h.isScratched,
            ))
        .toList();

    // [修正] 好走条件の改良 Step1: 今回取り消した馬は、ほかの馬の後に馬番順で並べる (v.2026.10.17+26101711)
    rows.sort((a, b) {
      if (a.isScratched != b.isScratched) return a.isScratched ? 1 : -1;
      if (a.isScratched) return a.horseNumber.compareTo(b.horseNumber);
      final ao = a.overallShowRate;
      final bo = b.overallShowRate;
      if (ao == null && bo == null) return a.horseNumber.compareTo(b.horseNumber);
      if (ao == null) return 1;
      if (bo == null) return -1;
      final c = bo.compareTo(ao);
      if (c != 0) return c;
      return a.horseNumber.compareTo(b.horseNumber);
    });

    return ConditionRankingTable(columns: columns, rows: rows);
  }
}
