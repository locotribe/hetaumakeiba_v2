// lib/logic/ai_export/ai_past_race_markdown_builder.dart
// [追加] AI分析データ 過去データ分離 Step3: アプリに取り込んだ過去の同じレースの結果から「過去データ」のMarkdownを組み立てる純粋関数。DB/I/Oなし。アプリの集計値は出さず、各年の結果をそのまま出す (v.2026.10.14+26101403)

import 'package:hetaumakeiba_v2/logic/ai_export/ai_race_full_markdown_builder.dart';
import 'package:hetaumakeiba_v2/logic/combination_calculator.dart';
import 'package:hetaumakeiba_v2/logic/parse.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';

String _pt(String? v) {
  if (v == null) return '-';
  final s = v.trim();
  return s.isEmpty ? '-' : s;
}

String _pcell(String v) =>
    v.replaceAll('|', '／').replaceAll(RegExp(r'[\r\n]+'), ' ').trim();

/// 過去データ（過去の同じレースの結果）のMarkdownを組み立てる。
/// [pastResults] はレースIDの大きい順（新しい年が先）に並べ替えて出す。
/// 各年について、コース・天候・馬場、ラップ、コーナー通過順、全着順、払戻を出す。
String buildPastRaceMarkdown({
  required String raceId,
  required String raceName,
  required String raceDate,
  required List<RaceResult> pastResults,
  required DateTime exportedAt,
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

  if (sorted.isEmpty) {
    buf.writeln('（過去のレース結果なし）');
    return buf.toString();
  }

  for (final r in sorted) {
    _renderPastRace(buf, r);
  }
  return buf.toString();
}

void _renderPastRace(StringBuffer buf, RaceResult r) {
  final venueCode = r.raceId.length >= 6 ? r.raceId.substring(4, 6) : '';
  final venue = racecourseDict[venueCode] ?? '-';
  buf.writeln(
      '## ${_pcell(_pt(r.raceDate))} ${_pcell(venue)} ${_pcell(_pt(r.raceTitle))}');
  buf.writeln('- raceId: ${_pt(r.raceId)}');
  buf.writeln('- コース・天候・馬場: ${_pcell(_pt(r.raceInfo))}');
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
      '| 着順 | 枠 | 馬番 | 馬名 | 性齢 | 斤量 | 騎手 | タイム | 着差 | 通過 | 上り | 単勝 | 人気 | 馬体重 | 調教師 |');
  buf.writeln(
      '|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|');
  for (final h in r.horseResults) {
    final trainer = '${h.trainerAffiliation.trim()}${h.trainerName.trim()}';
    buf.writeln(
        '| ${_pcell(_pt(h.rank))} | ${_pcell(_pt(h.frameNumber))} | ${_pcell(_pt(h.horseNumber))} | ${_pcell(_pt(h.horseName))} | ${_pcell(_pt(h.sexAndAge))} | ${_pcell(_pt(h.weightCarried))} | ${_pcell(_pt(h.jockeyName))} | ${_pcell(_pt(h.time))} | ${_pcell(_pt(h.margin))} | ${_pcell(_pt(h.cornerRanking))} | ${_pcell(_pt(h.agari))} | ${_pcell(_pt(h.odds))} | ${_pcell(_pt(h.popularity))} | ${_pcell(_pt(h.horseWeight))} | ${_pcell(_pt(trainer))} |');
  }

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
