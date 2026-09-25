// lib/logic/analysis/condition_ranking_builder.dart

import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/logic/analysis/condition_aptitude_analyzer.dart';

// [追加] 好走条件 相対順位付け StepB-1: 今回レース条件で全出走馬を横断比較するヒートマップの集約ロジック (v.2026.9.25+26092508)

/// 今回レースの確定条件（各列の今回値）
class RaceConditions {
  final String? surface; // 芝/ダ/障
  final String? distanceLabel; // 例「芝1400-1600」
  final String? direction; // 左/右
  final String? venue; // 例「東京」
  final String? classLabel; // 例「G1」
  const RaceConditions({
    this.surface,
    this.distanceLabel,
    this.direction,
    this.venue,
    this.classLabel,
  });
}

/// build に渡す1頭ぶんの軽量入力
class HorseInput {
  final String horseId;
  final String horseName;
  final int horseNumber;
  final List<HorseRaceRecord> records;
  const HorseInput({
    required this.horseId,
    required this.horseName,
    required this.horseNumber,
    required this.records,
  });
}

/// ヒートマップの列1つ
class RaceConditionColumn {
  final String key; // surface|distance|direction|venue|class|overall
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
  const HorseConditionRow({
    required this.horseId,
    required this.horseName,
    required this.horseNumber,
    required this.cells,
    required this.overallShowRate,
  });
}

/// ヒートマップ全体
class ConditionRankingTable {
  final List<RaceConditionColumn> columns; // [surface, distance, direction, venue, class, overall]
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

  /// データ列の順序（総合は末尾に付ける）
  static const List<String> dataColumnKeys = [
    kSurface,
    kDistance,
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

  /// 今回レースの各列の今回値を決める
  static RaceConditions conditionsOf(PredictionRaceData raceData) {
    final surface = _surfaceFromTrackType(raceData.trackType);

    String? distanceLabel;
    if ((surface == '芝' || surface == 'ダ') && raceData.distanceValue != null) {
      distanceLabel =
          '$surface${ConditionAptitudeAnalyzer.distanceBandLabel(raceData.distanceValue!)}';
    }

    String? direction = raceData.direction;
    if (direction == null || direction.isEmpty) {
      direction = ConditionAptitudeAnalyzer.directionOf(raceData.venue);
    }

    final venue = _venueName(raceData.venue);

    final classLabel = ConditionAptitudeAnalyzer.gradeClassOf(raceData.raceName);

    return RaceConditions(
      surface: surface,
      distanceLabel: distanceLabel,
      direction: direction,
      venue: venue.isEmpty ? null : venue,
      classLabel: classLabel,
    );
  }

  static String _columnName(String key) {
    switch (key) {
      case kSurface:
        return '芝ダ';
      case kDistance:
        return '距離';
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
  static List<HorseRaceRecord> recordsForColumn(
      String key, String todayValue, List<HorseRaceRecord> records) {
    if (todayValue.isEmpty || todayValue == '—') return const [];
    bool match(HorseRaceRecord r) {
      switch (key) {
        case kSurface:
          return ConditionAptitudeAnalyzer.surfaceOf(r.distance) == todayValue;
        case kDistance:
          return ConditionAptitudeAnalyzer.distanceLabelOf(r) == todayValue;
        case kDirection:
          return ConditionAptitudeAnalyzer.directionOf(r.venue) == todayValue;
        case kVenue:
          return _venueName(r.venue) == todayValue;
        case kClass:
          return ConditionAptitudeAnalyzer.gradeClassOf(r.raceName) == todayValue;
      }
      return false;
    }

    return records.where(match).toList();
  }

  /// 今回レース＋全馬過去走からヒートマップを作る
  static ConditionRankingTable build({
    required PredictionRaceData raceData,
    required Map<String, List<HorseRaceRecord>> allPastRecords,
  }) {
    final conditions = conditionsOf(raceData);
    final horses = raceData.horses
        .map((h) => HorseInput(
              horseId: h.horseId,
              horseName: h.horseName,
              horseNumber: h.horseNumber,
              records: allPastRecords[h.horseId] ?? const [],
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
            : recordsForColumn(key, tv, h.records);
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
            ))
        .toList();

    rows.sort((a, b) {
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
