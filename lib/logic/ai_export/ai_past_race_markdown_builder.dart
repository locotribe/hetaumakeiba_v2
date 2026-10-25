// lib/logic/ai_export/ai_past_race_markdown_builder.dart
// [追加] AI分析データ 過去データ分離 Step3: アプリに取り込んだ過去の同じレースの結果から「過去データ」のMarkdownを組み立てる純粋関数。DB/I/Oなし。アプリの集計値は出さず、各年の結果をそのまま出す (v.2026.10.14+26101403)
// [修正] AI分析データ 過去データ馬場・読み方: 各年にレース当日のJRA発表の馬場（クッション値・含水率）を足し、先頭に「この資料の読み方」（列・記号・用語）を出す (v.2026.10.14+26101406)
// [追加] 過去データに血統と前走: 全着順の表に血統6列（父・母・父父・父母・母父・母母）を足し、表のすぐ下に各馬の前走（その年のレースより前に実際に出走した一番新しい走）の表を出す (v.2026.10.18+26101804)
// [追加] 過去データに父・母父別の成績: 全レースのあとに、過去の出走馬を父・母父ごとに数えた表（過去分析「ローテ・血統」タブの血統の表と同じ buildPedigreeLiftTable）を出す (v.2026.10.25+26102502)

import 'package:hetaumakeiba_v2/logic/ai_export/ai_race_full_markdown_builder.dart';
// [追加] 過去データに父・母父別の成績 (v.2026.10.25+26102502)
import 'package:hetaumakeiba_v2/logic/analysis/factor_candidate_selector.dart' show FactorMetric;
// [追加] 過去データに父・母父別の成績 (v.2026.10.25+26102502)
import 'package:hetaumakeiba_v2/logic/analysis/past_race_lift.dart' show PastRaceLiftTable, buildPedigreeLiftTable;
import 'package:hetaumakeiba_v2/logic/combination_calculator.dart';
import 'package:hetaumakeiba_v2/logic/earned_prize_calculator.dart';
import 'package:hetaumakeiba_v2/logic/parse.dart';
import 'package:hetaumakeiba_v2/logic/past_race_horse_data.dart';
import 'package:hetaumakeiba_v2/logic/previous_race.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/horse_profile_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/models/track_conditions_model.dart';
import 'package:hetaumakeiba_v2/utils/speed_index_date_parser.dart';

String _pt(String? v) {
  if (v == null) return '-';
  final s = v.trim();
  return s.isEmpty ? '-' : s;
}

String _pcell(String v) =>
    v.replaceAll('|', '／').replaceAll(RegExp(r'[\r\n]+'), ' ').trim();

String _pd(double? v) {
  if (v == null) return '-';
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(2);
}

// [修正] 血統の名前の表記ゆれ: 父別・母父別の説明に、末尾の生産国の括弧を外して数えることを足した (v.2026.10.25+26102503)
/// 過去データの先頭に置く「この資料の読み方」（固定文言）。AI が列・記号・用語を取り違えないようにする。
String _pastReadingGuide() {
  return '''## この資料の読み方（列・記号・用語）
- この資料は、今回と同じレースの過去の結果（アプリに取り込んだ年だけ。新しい順）。アプリの集計は末尾の「父別・母父別の成績」だけで、ほかは各年の結果をそのまま載せている。「-」は不明・該当なし。
- raceId は12桁で「年4桁・競馬場2桁・開催回2桁・開催日目2桁・レース番号2桁」。競馬場は 01札幌 02函館 03福島 04新潟 05東京 06中山 07中京 08京都 09阪神 10小倉。
- 各年の見出しは「日付 競馬場 レース名」。レース名と違う条件があるときだけ見出しの下に条件の行を出す。
- コース・天候・馬場: 例「芝右 外1400m」＝芝・右回り・外回り・1400m（ダ＝ダート、障＝障害）。馬場状態は 良＜稍重＜重＜不良 の順に水分が多い。発走は発走時刻。
- JRA発表の馬場（当日）: そのレースの日にJRAが発表したクッション値と含水率。クッション値は芝の反発の強さで、JRAの目安は 7未満=軟らかめ、7〜8=やや軟らかめ、8〜10=標準、10〜12=やや硬め、12以上=硬め。含水率(%)はゴール前と4コーナーの2か所の値で、高いほど湿っている（芝とダートで値の幅が違う）。古い年は公表前などのため「測定データなし」。
- ラップ: 先頭の馬の200mごとの区間タイム（秒）。ペース: その累計タイム（秒）で、末尾の括弧は「前半3F-後半3F」（最初の600mと最後の600mの時計）。
- コーナー通過順（例「3コーナー: (*10,11)(1,15,17)-8=14」）: 数字は馬番で、左ほど前。( )=1馬身未満の差で併走している馬群（内側の馬から順）、( )の中の * =その馬群の先頭の馬、「,」=前の馬と1馬身以上2馬身未満の差、「-」=2馬身以上5馬身未満の差、「=」=5馬身以上の差。短い距離では1・2コーナーが無い。
- 全着順の列: 着順（数字以外は 取=取消、除=除外、中=競走中止、失=失格。「(降)」は降着）/ 枠 / 馬番 / 馬名 / 性齢（牡・牝・セ=せん馬）/ 斤量(kg) / 騎手 / タイム / 着差（前の馬との差。1着は-。ハナ＜アタマ＜クビ＜1/2＜3/4＜1＜1.1/4（1と1/4馬身）… 大=10馬身以上、同着あり）/ 通過（各コーナーの順位を-で区切ったもの。左が最初のコーナー）/ 上り（最後の600mの時計・秒）/ 単勝（オッズ・倍）/ 人気 / 馬体重(kg。括弧は前走からの増減)/ 調教師（頭に所属が付くことがある）。
- 払戻: 券種・組み合わせ・払戻(100円あたりの円)・人気。組み合わせの「→」は着順どおり（馬単・3連単）、「-」は順不同。枠連は枠番、ほかは馬番。
- 血統の列（全着順の表の右端）: 父 / 母 / 父父 / 父母 / 母父 / 母母（2代までの血統。アプリに血統を取り込んでいない馬は「-」）。
- 各馬の前走（全着順の表のすぐ下）: その年のこのレースより前に、その馬が実際に出走した一番新しい走（取消・除外の走は飛ばす）。この年に取消・除外だった馬は載せない。戦績をアプリに取り込んでいない馬は「（戦績未取得）」、それより前に走っていない馬は「（初出走）」。
  列: この年の着順 / この年の馬番 / 馬名 / 日付 / 開催（例「2福島7」＝2回福島7日目）/ 天気 / R / レース名 / 頭数 / 枠 / 馬番 / 単勝（オッズ・倍）/ 人気 / 着順 / 騎手 / 斤量(kg) / 距離（例「芝1800」）/ 馬場 / タイム / 着差（秒。勝った走はマイナスで2着との差）/ 通過 / ペース（そのレースの前半3F-後半3F）/ 上り / 馬体重(kg。括弧は前走からの増減)/ 勝ち馬(2着馬)（その走で1着なら2着の馬、それ以外は勝ち馬）/ 賞金（万円）。
- 父別・母父別の成績（末尾）: この資料の全レースの出走馬（取消・除外を除く。中止・失格は着外）を、父・母父ごとに数えたもの（アプリの過去分析「ローテ・血統」タブの血統の表と同じ数え方）。同じ馬が複数の年に出ていれば、その数だけ数える（延べ）。血統を取り込んでいない馬は数えない。着度数は 1着-2着-3着-着外。倍率(勝/連/複)は、その行の勝率・連対率・複勝率を全体の率で割ったもの（1より大きいほど全体より好走）。単回・複回は、その行の馬を毎回100円ずつ買ったときの単勝・複勝の回収率（単勝はオッズ、複勝は払戻しから。払戻しの無いレースは除く）。行は3着以内の多い順で、過去に1頭だけの行は、その馬が3着以内のときだけ出す。出走の少ない行の率は偶然の影響が大きい。「今回の該当馬」は、今回の出走馬（取消を除く）のうち同じ父（母父）の馬（馬番 馬名）。系統（サンデーサイレンス系など）では数えていない。名前の末尾の生産国の括弧（例「(米)」「(独)」）は外して数え、表の名前も外した形で出す（同じ馬でも付くときと付かないときがあるため。全着順の表の血統の列は取り込んだままの形）。
''';
}

/// 過去データ（過去の同じレースの結果）のMarkdownを組み立てる。
/// [pastResults] はレースIDの大きい順（新しい年が先）に並べ替えて出す。
/// 各年について、コース・天候・馬場、ラップ、コーナー通過順、全着順、払戻を出す。
String buildPastRaceMarkdown({
  required String raceId,
  required String raceName,
  required String raceDate,
  required List<RaceResult> pastResults,
  required DateTime exportedAt,
  Map<String, TrackConditionRecord?> trackByRaceId = const {},
  // [追加] 過去データに血統と前走: 馬ID → プロフィール（血統）、馬ID → 戦績。無い馬は「-」・「（戦績未取得）」 (v.2026.10.18+26101804)
  Map<String, HorseProfile> profileByHorseId = const {},
  Map<String, List<HorseRaceRecord>> recordsByHorseId = const {},
  // [追加] 過去データに父・母父別の成績: 今回の出走馬（取消を除く）の馬ID → 「馬番 馬名」。表の「今回の該当馬」に使う。血統は profileByHorseId から読む (v.2026.10.25+26102502)
  Map<String, String> currentHorseLabelById = const {},
}) {
  final sorted = [...pastResults]
    ..sort((a, b) => b.raceId.compareTo(a.raceId));

  final buf = StringBuffer();
  buf.writeln('# ${_pcell(_pt(raceName))} 過去データ（過去の同じレースの結果）');
  buf.writeln();
  buf.writeln('- raceId: ${_pt(raceId)}');
  buf.writeln('- 開催日: ${_pt(raceDate)}');
  buf.writeln('- 出力日時: ${formatAiExportedAt(exportedAt)}');
  buf.writeln('- 収録: ${sorted.length}レース（アプリに取り込んだ過去のレース。新しい順）');
  buf.writeln();
  buf.write(_pastReadingGuide());
  buf.writeln();

  if (sorted.isEmpty) {
    buf.writeln('（過去のレース結果なし）');
    return buf.toString();
  }

  for (final r in sorted) {
    _renderPastRace(buf, r, trackByRaceId[r.raceId],
        profileByHorseId: profileByHorseId,
        recordsByHorseId: recordsByHorseId);
  }
  // [追加] 過去データに父・母父別の成績: 全レースのあとに父別・母父別の表を出す (v.2026.10.25+26102502)
  _renderPedigreeLiftSection(
      buf, sorted, profileByHorseId, currentHorseLabelById);
  return buf.toString();
}

void _renderPastRace(
  StringBuffer buf,
  RaceResult r,
  TrackConditionRecord? tc, {
  Map<String, HorseProfile> profileByHorseId = const {},
  Map<String, List<HorseRaceRecord>> recordsByHorseId = const {},
}) {
  final venueCode = r.raceId.length >= 6 ? r.raceId.substring(4, 6) : '';
  final venue = racecourseDict[venueCode] ?? '-';
  buf.writeln(
      '## ${_pcell(_pt(r.raceDate))} ${_pcell(venue)} ${_pcell(_pt(r.raceTitle))}');
  buf.writeln('- raceId: ${_pt(r.raceId)}');
  buf.writeln('- コース・天候・馬場: ${_pcell(_pt(r.raceInfo))}');
  if (tc == null) {
    buf.writeln('- JRA発表の馬場（当日）: 測定データなし');
  } else {
    buf.writeln(
        '- JRA発表の馬場（当日）: クッション値 ${_pd(tc.cushionValue)} / 芝含水率(ゴール前/4角) ${_pd(tc.moistureTurfGoal)}/${_pd(tc.moistureTurf4c)} / ダート含水率(ゴール前/4角) ${_pd(tc.moistureDirtGoal)}/${_pd(tc.moistureDirt4c)}');
  }
  final grade = r.raceGrade.trim();
  if (grade.isNotEmpty && grade != r.raceTitle.trim()) {
    buf.writeln('- 条件: ${_pcell(grade)}');
  }
  for (final lap in r.lapTimes) {
    if (lap.trim().isEmpty) continue;
    buf.writeln('- ${_pcell(lap)}');
  }
  for (final corner in r.cornerPassages) {
    if (corner.trim().isEmpty) continue;
    buf.writeln('- ${_pcell(corner)}');
  }

  buf.writeln();
  buf.writeln('**全着順**');
  buf.writeln(
      '| 着順 | 枠 | 馬番 | 馬名 | 性齢 | 斤量 | 騎手 | タイム | 着差 | 通過 | 上り | 単勝 | 人気 | 馬体重 | 調教師 | 父 | 母 | 父父 | 父母 | 母父 | 母母 |');
  buf.writeln(
      '|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|');
  for (final h in r.horseResults) {
    final trainer = '${h.trainerAffiliation.trim()}${h.trainerName.trim()}';
    // [追加] 過去データに血統と前走: 血統6列。プロフィールが無い馬は「-」 (v.2026.10.18+26101804)
    final p = profileByHorseId[h.horseId];
    final pedigree = [
      p?.fatherName,
      p?.motherName,
      p?.ffName,
      p?.fmName,
      p?.mfName,
      p?.mmName,
    ].map((v) => _pcell(_pt(v))).join(' | ');
    buf.writeln(
        '| ${_pcell(_pt(h.rank))} | ${_pcell(_pt(h.frameNumber))} | ${_pcell(_pt(h.horseNumber))} | ${_pcell(_pt(h.horseName))} | ${_pcell(_pt(h.sexAndAge))} | ${_pcell(_pt(h.weightCarried))} | ${_pcell(_pt(h.jockeyName))} | ${_pcell(_pt(h.time))} | ${_pcell(_pt(h.margin))} | ${_pcell(_pt(h.cornerRanking))} | ${_pcell(_pt(h.agari))} | ${_pcell(_pt(h.odds))} | ${_pcell(_pt(h.popularity))} | ${_pcell(_pt(h.horseWeight))} | ${_pcell(_pt(trainer))} | $pedigree |');
  }

  // [追加] 過去データに血統と前走: 全着順の表のすぐ下に各馬の前走 (v.2026.10.18+26101804)
  _renderPreviousRuns(buf, r, recordsByHorseId);

  if (r.refunds.isNotEmpty) {
    buf.writeln();
    buf.writeln('**払戻**');
    buf.writeln('| 券種 | 組み合わせ | 払戻(円) | 人気 |');
    buf.writeln('|---|---|---|---|');
    for (final refund in r.refunds) {
      final type = bettingDict[refund.ticketTypeId] ?? '-';
      for (final p in refund.payouts) {
        buf.writeln(
            '| ${_pcell(type)} | ${_pcell(_pt(p.combination))} | ${_pcell(_pt(p.amount))} | ${_pcell(_pt(p.popularity))} |');
      }
    }
  }
  buf.writeln();
}

// [追加] 過去データに血統と前走: 各馬の前走の表 (v.2026.10.18+26101804)
/// [r] の出走馬（取消・除外と馬IDが空の行を除く）ごとに、その年のレースより前に実際に出走した一番新しい走を1行で出す。
/// 基準日は、その馬の戦績にあるこのレースの行の日付。無ければレース結果の開催日。
void _renderPreviousRuns(
  StringBuffer buf,
  RaceResult r,
  Map<String, List<HorseRaceRecord>> recordsByHorseId,
) {
  final starters = [
    for (final h in r.horseResults)
      if (h.horseId.isNotEmpty && !isNonStarterRank(h.rank)) h,
  ];
  if (starters.isEmpty) return;

  buf.writeln();
  buf.writeln('**各馬の前走**');
  buf.writeln(
      '| この年の着順 | この年の馬番 | 馬名 | 日付 | 開催 | 天気 | R | レース名 | 頭数 | 枠 | 馬番 | 単勝 | 人気 | 着順 | 騎手 | 斤量 | 距離 | 馬場 | タイム | 着差 | 通過 | ペース | 上り | 馬体重 | 勝ち馬(2着馬) | 賞金 |');
  buf.writeln(
      '|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|');
  final fallbackDay = parseRaceDateForSpeedIndex(r.raceDate);
  for (final h in starters) {
    final head =
        '| ${_pcell(_pt(h.rank))} | ${_pcell(_pt(h.horseNumber))} | ${_pcell(_pt(h.horseName))}';
    final records = recordsByHorseId[h.horseId] ?? const <HorseRaceRecord>[];
    if (records.isEmpty) {
      buf.writeln('$head | （戦績未取得） |${' - |' * 22}');
      continue;
    }
    DateTime? raceDay;
    for (final record in records) {
      if (record.raceId == r.raceId) {
        raceDay = parseEarnedPrizeDate(record.date);
        break;
      }
    }
    raceDay ??= fallbackDay;
    final prev = previousStartOf(records, raceDay);
    if (prev == null) {
      buf.writeln('$head | （初出走） |${' - |' * 22}');
      continue;
    }
    final cells = [
      prev.date,
      prev.venue,
      prev.weather,
      prev.raceNumber,
      prev.raceName,
      prev.numberOfHorses,
      prev.frameNumber,
      prev.horseNumber,
      prev.odds,
      prev.popularity,
      prev.rank,
      prev.jockey,
      prev.carriedWeight,
      prev.distance,
      prev.trackCondition,
      prev.time,
      prev.margin,
      prev.cornerPassage,
      prev.pace,
      prev.agari,
      prev.horseWeight,
      prev.winnerOrSecondHorse,
      prev.prizeMoney,
    ].map((v) => _pcell(_pt(v))).join(' | ');
    buf.writeln('$head | $cells |');
  }
}

// [追加] 過去データに父・母父別の成績: 節「父別・母父別の成績（アプリの集計）」。表は buildPedigreeLiftTable（血統タブと同じ部品）で作る (v.2026.10.25+26102502)
/// 全レース（[races]）の出走馬を、父・母父ごとに数えた表を出す。
/// 今回の出走馬は [currentHorseLabelById] のキー（馬ID）。血統は [profileByHorseId] から読む。
void _renderPedigreeLiftSection(
  StringBuffer buf,
  List<RaceResult> races,
  Map<String, HorseProfile> profileByHorseId,
  Map<String, String> currentHorseLabelById,
) {
  final currentIds = currentHorseLabelById.keys.toList();
  buf.writeln('## 父別・母父別の成績（アプリの集計）');
  buf.writeln();
  _renderPedigreeLiftTable(
    buf,
    title: '父別',
    rowHeader: '父',
    table: buildPedigreeLiftTable(
      pastRaces: races,
      profiles: profileByHorseId,
      currentHorseIds: currentIds,
      damSire: false,
    ),
    currentHorseLabelById: currentHorseLabelById,
  );
  _renderPedigreeLiftTable(
    buf,
    title: '母父別',
    rowHeader: '母父',
    table: buildPedigreeLiftTable(
      pastRaces: races,
      profiles: profileByHorseId,
      currentHorseIds: currentIds,
      damSire: true,
    ),
    currentHorseLabelById: currentHorseLabelById,
  );
}

/// 率(%)を小数1桁で。例 '33.3%'
String _liftRate(double v) => '${v.toStringAsFixed(1)}%';

/// 倍率を小数2桁で。例 '1.25'。無ければ '-'
String _liftRatio(double? v) => v == null ? '-' : v.toStringAsFixed(2);

/// 回収率(%)を整数で。計算できないときは '-'。例 '132%'
String _liftReturn(double? v) => v == null ? '-' : '${v.toStringAsFixed(0)}%';

/// 父別または母父別の表1つ（見出し・数えた頭数・全体の率・表・表に無い今回の出走馬）。
void _renderPedigreeLiftTable(
  StringBuffer buf, {
  required String title,
  required String rowHeader,
  required PastRaceLiftTable table,
  required Map<String, String> currentHorseLabelById,
}) {
  buf.writeln('### $title');
  if (table.countedStarts == 0) {
    buf.writeln(
        '（過去の出走馬の血統がアプリにありません。過去分析「ローテ・血統」タブの取得カードで取得すると出ます）');
    buf.writeln();
    return;
  }
  final baseline = table.baseline;
  final overall = table.overallReturns;
  buf.writeln(
      '- 数えた過去の出走: 延べ${table.countedStarts}頭${table.missingStarts > 0 ? '（血統が無く数えていない 延べ${table.missingStarts}頭）' : ''}');
  buf.writeln(
      '- 全体: 勝率 ${_liftRate(baseline.rate(FactorMetric.win))} / 連対率 ${_liftRate(baseline.rate(FactorMetric.place))} / 複勝率 ${_liftRate(baseline.rate(FactorMetric.show))} / 単回 ${_liftReturn(overall.winReturn)} / 複回 ${_liftReturn(overall.showReturn)}');

  final rows = table.shownRowsByShow;
  final shownKeys = {for (final row in rows) row.key};
  if (rows.isEmpty) {
    buf.writeln('- 表に出せる行がありません（過去の出走が2頭以上、または3着以内が1頭以上の行だけ出す）');
  } else {
    buf.writeln();
    buf.writeln(
        '| $rowHeader | 着度数 | 勝率 | 連対率 | 複勝率 | 倍率(勝/連/複) | 単回 | 複回 | 今回の該当馬 |');
    buf.writeln('|---|---|---|---|---|---|---|---|---|');
    for (final row in rows) {
      final lifts = table.liftsOf(row);
      final current = [
        for (final id in row.currentHorseIds) currentHorseLabelById[id] ?? id,
      ].join('、');
      buf.writeln(
          '| ${_pcell(row.label)} | ${row.recordText} | ${_liftRate(row.rateFor(FactorMetric.win))} | ${_liftRate(row.rateFor(FactorMetric.place))} | ${_liftRate(row.rateFor(FactorMetric.show))} | ${_liftRatio(lifts[FactorMetric.win])}/${_liftRatio(lifts[FactorMetric.place])}/${_liftRatio(lifts[FactorMetric.show])} | ${_liftReturn(row.returns.winReturn)} | ${_liftReturn(row.returns.showReturn)} | ${current.isEmpty ? '-' : _pcell(current)} |');
    }
  }

  // 今回の出走馬のうち、表に行が無い馬（過去に同じ区分の出走が無い、または表に出す基準に届かない）と、血統が無く区分が決まらない馬
  final notShown = <String>[];
  final noPedigree = <String>[];
  for (final entry in currentHorseLabelById.entries) {
    final row = table.rowOf(entry.key);
    if (row == null) {
      noPedigree.add(entry.value);
    } else if (!shownKeys.contains(row.key)) {
      notShown.add(row.total == 0
          ? '${entry.value}（${row.label}・過去の出走なし）'
          : '${entry.value}（${row.label}・過去の出走 ${row.total}頭 ${row.recordText}）');
    }
  }
  if (notShown.isNotEmpty || noPedigree.isNotEmpty) buf.writeln();
  if (notShown.isNotEmpty) {
    buf.writeln('- 表に無い今回の出走馬: ${_pcell(notShown.join('、'))}');
  }
  if (noPedigree.isNotEmpty) {
    buf.writeln('- 血統が無く区分が決まらない今回の出走馬: ${_pcell(noPedigree.join('、'))}');
  }
  buf.writeln();
}
