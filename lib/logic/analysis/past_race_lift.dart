// lib/logic/analysis/past_race_lift.dart

// [追加] ローテ・血統タブのリフト化 Step1: 過去レースの全出走馬（取消・除外を除く）を、前走の路線・父・母父ごとに数え、着度数・率・倍率（リフト）を出す部品。DBやネットには触らない (v.2026.10.16+26101611)

import 'package:hetaumakeiba_v2/logic/analysis/factor_candidate_selector.dart';
import 'package:hetaumakeiba_v2/logic/earned_prize_calculator.dart';
import 'package:hetaumakeiba_v2/logic/past_race_horse_data.dart';
import 'package:hetaumakeiba_v2/logic/previous_race.dart';
import 'package:hetaumakeiba_v2/logic/race_route.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/horse_profile_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';

/// そのレースがデビュー戦だった（前走が無い）馬の区分のキー・表示名。
const String kFirstStartLiftKey = '初出走';

/// 表に出す行の最小の頭数。これより少ない行は、3着以内が1頭以上いるときだけ出す。
const int kLiftRowMinTotal = 2;

/// 区分（路線・父・母父）1つの成績。
class PastRaceLiftRow {
  /// 区分のキー（路線のID・父の名前など）
  final String key;

  /// 表示名
  final String label;

  /// 過去の出走（延べ頭数。同じ馬が複数の年に出ていれば、その数だけ数える）
  final int total;

  /// 1着の数
  final int win;

  /// 1〜2着の数
  final int place;

  /// 1〜3着の数
  final int show;

  /// 今回の出走馬のうち、この区分に入る馬の馬ID
  final List<String> currentHorseIds;

  const PastRaceLiftRow({
    required this.key,
    required this.label,
    required this.total,
    required this.win,
    required this.place,
    required this.show,
    required this.currentHorseIds,
  });

  /// 着度数（1着-2着-3着-着外）
  String get recordText =>
      '$win-${place - win}-${show - place}-${total - show}';

  /// 指標別の率(%)。出走が0なら全部0。
  Map<String, double> get rates {
    if (total <= 0) {
      return {
        FactorMetric.win: 0.0,
        FactorMetric.place: 0.0,
        FactorMetric.show: 0.0,
      };
    }
    return {
      FactorMetric.win: win / total * 100.0,
      FactorMetric.place: place / total * 100.0,
      FactorMetric.show: show / total * 100.0,
    };
  }

  double rateFor(String metric) => rates[metric] ?? 0.0;
}

/// 過去の出走馬を区分ごとに数えた表。
class PastRaceLiftTable {
  /// 区分の一覧。過去の出走の多い順（同数は3着以内の多い順、次に表示名の順）。
  /// 今回の出走馬だけがいる区分（過去の出走0）も、最後に入る。
  final List<PastRaceLiftRow> rows;

  /// 過去の出走全体の率（倍率の基準線）
  final FactorBaseline baseline;

  /// データが無く数えなかった過去の出走（延べ頭数）
  final int missingStarts;

  /// 今回の出走馬の馬ID → 区分のキー（区分が決まらない馬は入らない）
  final Map<String, String> rowKeyOfCurrentHorse;

  /// 今回の出走馬の馬ID → 区分を決めた元の文字（前走のレース名・父の名前など。前走が無ければ空）
  final Map<String, String> currentDetailOfHorse;

  final Map<String, PastRaceLiftRow> _rowByKey;

  PastRaceLiftTable({
    required this.rows,
    required this.baseline,
    required this.missingStarts,
    required this.rowKeyOfCurrentHorse,
    required this.currentDetailOfHorse,
  }) : _rowByKey = {for (final row in rows) row.key: row};

  /// 数えた過去の出走（延べ頭数）
  int get countedStarts => baseline.totalCount;

  /// 今回の出走馬の区分。区分が決まらない馬は null。
  PastRaceLiftRow? rowOf(String horseId) {
    final key = rowKeyOfCurrentHorse[horseId];
    return key == null ? null : _rowByKey[key];
  }

  /// 区分の率を、過去の出走全体の率で割った倍率。基準の率が0なら0。
  Map<String, double> liftsOf(PastRaceLiftRow row) {
    final rates = row.rates;
    return {
      for (final metric in FactorMetric.all)
        metric: baseline.rate(metric) > 0
            ? (rates[metric] ?? 0.0) / baseline.rate(metric)
            : 0.0,
    };
  }

  /// 表に出す行。過去の出走が [kLiftRowMinTotal] 以上か、3着以内が1頭以上いる行（並びは [rows] のまま）。
  List<PastRaceLiftRow> get shownRows => [
        for (final row in rows)
          if (row.total >= kLiftRowMinTotal || row.show > 0) row,
      ];

  /// 今回の出走馬のうち、過去に同じ区分の出走が無い馬の馬ID（今回の出走馬の並び）。
  List<String> get currentHorsesWithoutPast => [
        for (final entry in rowKeyOfCurrentHorse.entries)
          if ((_rowByKey[entry.value]?.total ?? 0) == 0) entry.key,
      ];

  /// 要約に出す行。過去の出走が [kLiftRowMinTotal] 以上で率が0より大きい行を、
  /// 率の高い順（同じなら出走の多い順、次に表示名の順）に [take] 個まで。
  List<PastRaceLiftRow> topRows({
    String metric = FactorMetric.show,
    int take = 3,
  }) {
    final candidates = [
      for (final row in rows)
        if (row.total >= kLiftRowMinTotal && row.rateFor(metric) > 0) row,
    ];
    candidates.sort((a, b) {
      final byRate = b.rateFor(metric).compareTo(a.rateFor(metric));
      if (byRate != 0) return byRate;
      final byTotal = b.total.compareTo(a.total);
      if (byTotal != 0) return byTotal;
      return a.label.compareTo(b.label);
    });
    return candidates.take(take).toList();
  }
}

/// 過去の出走1つ（区分と着順）。
class _PastStart {
  final String key;
  final String label;
  final String rank;

  const _PastStart(this.key, this.label, this.rank);
}

/// 今回の出走馬1頭（区分と元の文字）。
class _CurrentEntry {
  final String key;
  final String label;
  final String detail;

  const _CurrentEntry(this.key, this.label, this.detail);
}

class _Counter {
  final String key;
  String label;
  int total = 0;
  int win = 0;
  int place = 0;
  int show = 0;
  final List<String> currentHorseIds = [];

  _Counter(this.key, this.label);
}

PastRaceLiftTable _buildTable({
  required List<_PastStart> pastStarts,
  required Map<String, _CurrentEntry> currentEntries,
  required int missingStarts,
}) {
  final counters = <String, _Counter>{};
  int total = 0, win = 0, place = 0, show = 0;
  for (final start in pastStarts) {
    final counter =
        counters.putIfAbsent(start.key, () => _Counter(start.key, start.label));
    final rank = int.tryParse(start.rank.trim());
    counter.total++;
    total++;
    if (rank != null && rank >= 1 && rank <= 3) {
      counter.show++;
      show++;
      if (rank <= 2) {
        counter.place++;
        place++;
      }
      if (rank == 1) {
        counter.win++;
        win++;
      }
    }
  }
  final keyOfHorse = <String, String>{};
  final detailOfHorse = <String, String>{};
  for (final entry in currentEntries.entries) {
    final current = entry.value;
    counters
        .putIfAbsent(current.key, () => _Counter(current.key, current.label))
        .currentHorseIds
        .add(entry.key);
    keyOfHorse[entry.key] = current.key;
    detailOfHorse[entry.key] = current.detail;
  }

  final rows = [
    for (final c in counters.values)
      PastRaceLiftRow(
        key: c.key,
        label: c.label,
        total: c.total,
        win: c.win,
        place: c.place,
        show: c.show,
        currentHorseIds: List.unmodifiable(c.currentHorseIds),
      ),
  ];
  rows.sort((a, b) {
    final byTotal = b.total.compareTo(a.total);
    if (byTotal != 0) return byTotal;
    final byShow = b.show.compareTo(a.show);
    if (byShow != 0) return byShow;
    return a.label.compareTo(b.label);
  });

  final baseline = total <= 0
      ? const FactorBaseline(
          totalCount: 0,
          rates: {
            FactorMetric.win: 0.0,
            FactorMetric.place: 0.0,
            FactorMetric.show: 0.0,
          },
          raceCount: 0,
        )
      : FactorBaseline(
          totalCount: total,
          rates: {
            FactorMetric.win: win / total * 100.0,
            FactorMetric.place: place / total * 100.0,
            FactorMetric.show: show / total * 100.0,
          },
          // 1レースにつき1着は1頭なので、勝利数の合計＝対象レース数とみなせる（factor_candidate_selector と同じ）
          raceCount: win,
        );

  return PastRaceLiftTable(
    rows: List.unmodifiable(rows),
    baseline: baseline,
    missingStarts: missingStarts,
    rowKeyOfCurrentHorse: keyOfHorse,
    currentDetailOfHorse: detailOfHorse,
  );
}

/// 路線の表示名。距離が分かる路線は「（芝1800）」のように芝ダ・距離を付ける。
String pastRaceRouteLabel(RaceRoute route) {
  if (route.meters == null) return route.displayName;
  return '${route.displayName}（${route.surface}${route.meters}）';
}

/// ローテ（前走の路線）ごとに数えた表。
///
/// - 過去の出走: [pastRaces] の全出走馬（取消・除外と馬IDが空の行を除く。中止・失格は着外として数える）。
///   その馬の戦績（[pastHorseRecords]）にそのレースの行が無い、またはその行の日付が読めないときは数えない（[PastRaceLiftTable.missingStarts]）。
///   前走は、そのレースの行の日付より前に実際に出走した一番新しい走（previousStartOf）。無ければ「初出走」。
/// - 今回の出走馬: [currentHorseRecords]（馬ID → 今回のレース日より前の戦績。取消の馬は入れない）の前走を
///   [currentRaceDate] を基準に決める。戦績が空の馬は区分を決めない。前走が無ければ「初出走」。
/// - 過去の前走と今回の前走をまとめて RaceRouteIndex で路線にする。
PastRaceLiftTable buildRotationLiftTable({
  required List<RaceResult> pastRaces,
  required Map<String, List<HorseRaceRecord>> pastHorseRecords,
  required Map<String, List<HorseRaceRecord>> currentHorseRecords,
  DateTime? currentRaceDate,
}) {
  final pastPrevious = <HorseRaceRecord?>[];
  final pastRanks = <String>[];
  int missing = 0;
  for (final race in pastRaces) {
    for (final horse in race.horseResults) {
      if (horse.horseId.isEmpty) continue;
      if (isNonStarterRank(horse.rank)) continue;
      final records =
          pastHorseRecords[horse.horseId] ?? const <HorseRaceRecord>[];
      HorseRaceRecord? row;
      for (final record in records) {
        if (record.raceId == race.raceId) {
          row = record;
          break;
        }
      }
      final raceDay = row == null ? null : parseEarnedPrizeDate(row.date);
      if (raceDay == null) {
        missing++;
        continue;
      }
      pastPrevious.add(previousStartOf(records, raceDay));
      pastRanks.add(horse.rank);
    }
  }

  final currentPrevious = <String, HorseRaceRecord?>{};
  for (final entry in currentHorseRecords.entries) {
    if (entry.value.isEmpty) continue;
    currentPrevious[entry.key] = previousStartOf(entry.value, currentRaceDate);
  }

  final index = RaceRouteIndex.build([
    for (final previous in pastPrevious)
      if (previous != null) previous,
    for (final previous in currentPrevious.values)
      if (previous != null) previous,
  ]);

  String keyOf(HorseRaceRecord? previous) {
    if (previous == null) return kFirstStartLiftKey;
    return index.routeOf(previous)?.id ?? raceRouteKeyOf(previous).text;
  }

  String labelOf(HorseRaceRecord? previous) {
    if (previous == null) return kFirstStartLiftKey;
    final route = index.routeOf(previous);
    return route == null
        ? raceRouteKeyOf(previous).name
        : pastRaceRouteLabel(route);
  }

  return _buildTable(
    pastStarts: [
      for (var i = 0; i < pastPrevious.length; i++)
        _PastStart(
          keyOf(pastPrevious[i]),
          labelOf(pastPrevious[i]),
          pastRanks[i],
        ),
    ],
    currentEntries: {
      for (final entry in currentPrevious.entries)
        entry.key: _CurrentEntry(
          keyOf(entry.value),
          labelOf(entry.value),
          entry.value?.raceName ?? '',
        ),
    },
    missingStarts: missing,
  );
}

/// 血統（父、または [damSire] が true なら母父）ごとに数えた表。
///
/// - 過去の出走: [pastRaces] の全出走馬（取消・除外と馬IDが空の行を除く。中止・失格は着外として数える）。
///   プロフィールが無い・父の名前が空（血統が無い）、または母父の名前が空（母父のとき）なら数えない。
/// - 今回の出走馬: [currentHorseIds] の馬（取消の馬は入れない）。名前が分からない馬は区分を決めない。
/// - 名前は前後の空白を除いて、そのまま比べる。
PastRaceLiftTable buildPedigreeLiftTable({
  required List<RaceResult> pastRaces,
  required Map<String, HorseProfile> profiles,
  required List<String> currentHorseIds,
  required bool damSire,
}) {
  String? nameOf(String horseId) {
    final profile = profiles[horseId];
    if (profile == null || profile.fatherName.trim().isEmpty) return null;
    final name = (damSire ? profile.mfName : profile.fatherName).trim();
    return name.isEmpty ? null : name;
  }

  final pastStarts = <_PastStart>[];
  int missing = 0;
  for (final race in pastRaces) {
    for (final horse in race.horseResults) {
      if (horse.horseId.isEmpty) continue;
      if (isNonStarterRank(horse.rank)) continue;
      final name = nameOf(horse.horseId);
      if (name == null) {
        missing++;
        continue;
      }
      pastStarts.add(_PastStart(name, name, horse.rank));
    }
  }

  final currentEntries = <String, _CurrentEntry>{};
  for (final horseId in currentHorseIds) {
    final name = nameOf(horseId);
    if (name == null) continue;
    currentEntries[horseId] = _CurrentEntry(name, name, name);
  }

  return _buildTable(
    pastStarts: pastStarts,
    currentEntries: currentEntries,
    missingStarts: missing,
  );
}
