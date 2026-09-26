// lib/logic/ai_export/ai_race_markdown_builder.dart
// [追加] AI分析データエクスポート Step1: 出馬表データ(PredictionRaceData)だけからAI分析用のMarkdownを組み立てる純粋関数。DBアクセス・ファイルI/Oは持たない。馬柱/調教/血統など実データの描画はStep3で拡張する (v.2026.9.27+26092701)

import 'package:hetaumakeiba_v2/models/race_data.dart';

/// null / 空文字を '-' に正規化して返す。
String _t(String? v) {
  if (v == null) return '-';
  final s = v.trim();
  return s.isEmpty ? '-' : s;
}

/// int? を文字列化（null は '-'）。
String _i(int? v) => v == null ? '-' : v.toString();

/// double? を読みやすく文字列化（整数値は小数を省く。null は '-'）。
String _d(double? v) {
  if (v == null) return '-';
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(2);
}

/// Markdown表のセル内で崩れる文字（縦棒・改行）を置換する。
String _cell(String v) =>
    v.replaceAll('|', '／').replaceAll(RegExp(r'[\r\n]+'), ' ').trim();

/// PredictionRaceData から AI分析用の Markdown 文字列を組み立てる（純粋関数・副作用なし）。
///
/// Step1 では「レース概要 + 出走馬一覧表 + 各馬の基本情報 + 既存の予想メモ」を出力する。
/// 実データ(馬柱/過去走詳細/調教/血統/各種指数/過去10年統計)の描画と粒度オプションは
/// 後続Step(Step2:収集サービス, Step3:ビルダー拡張)で追加する。
String buildRaceAiMarkdown(PredictionRaceData raceData) {
  final buf = StringBuffer();

  // 見出し
  final grade = raceData.raceGrade.trim();
  buf.writeln(
      '# ${_cell(raceData.raceName)}${grade.isEmpty ? '' : '（$grade）'} AI分析資料');
  buf.writeln();

  // レース概要
  buf.writeln('## レース概要');
  buf.writeln('- raceId: ${_t(raceData.raceId)}');
  buf.writeln(
      '- 開催: ${_t(raceData.raceDate)} / ${_t(raceData.venue)} / ${_t(raceData.raceNumber)}R');

  final course = StringBuffer();
  if (raceData.trackType != null) course.write(raceData.trackType!);
  if (raceData.distanceValue != null) course.write('${raceData.distanceValue!}m');
  if (raceData.direction != null) course.write(' ${raceData.direction!}');
  if (raceData.courseInOut != null) course.write(' ${raceData.courseInOut!}');
  buf.writeln('- コース: ${course.isEmpty ? '-' : course.toString().trim()}');

  buf.writeln('- 天候: ${_t(raceData.weather)} / 馬場: ${_t(raceData.trackCondition)}');
  buf.writeln(
      '- 開催回/日目: ${_i(raceData.holdingTimes)}回 ${_i(raceData.holdingDays)}日目 / カテゴリ: ${_t(raceData.raceCategory)}');
  buf.writeln(
      '- 頭数: ${_i(raceData.horseCount)} / 発走: ${_t(raceData.startTime)} / 1着賞金: ${_i(raceData.basePrize1st)}');
  buf.writeln();

  // 出走馬一覧
  buf.writeln('## 出走馬一覧');
  buf.writeln(
      '| 馬番 | 枠 | 馬名 | 性齢 | 騎手(斤量) | 単勝 | 人気 | 馬体重 | 総合スコア | 期待値 | 出否 |');
  buf.writeln('|---|---|---|---|---|---|---|---|---|---|---|');
  for (final h in raceData.horses) {
    final jockey = '${_cell(_t(h.jockey))}(${_d(h.carriedWeight)})';
    buf.writeln(
        '| ${h.horseNumber} | ${h.gateNumber} | ${_cell(_t(h.horseName))} | ${_cell(_t(h.sexAndAge))} | $jockey | ${_d(h.odds)} | ${_i(h.popularity)} | ${_cell(_t(h.horseWeight))} | ${_d(h.overallScore)} | ${_d(h.expectedValue)} | ${h.isScratched ? '取消' : '出走'} |');
  }
  buf.writeln();

  // 各馬詳細
  buf.writeln('## 各馬詳細');
  for (final h in raceData.horses) {
    buf.writeln();
    buf.writeln(
        '### ${h.horseNumber} ${_cell(_t(h.horseName))}（horseId: ${_t(h.horseId)}）');
    if (h.isScratched) buf.writeln('- **出走取消**');
    buf.writeln('- 枠番: ${h.gateNumber} / 性齢: ${_t(h.sexAndAge)}');
    buf.writeln(
        '- 騎手: ${_t(h.jockey)}（${_d(h.carriedWeight)}kg）/ 調教師: ${_t(h.trainerName)}（${_t(h.trainerAffiliation)}）');
    buf.writeln(
        '- 馬主: ${_t(h.ownerName)} / 父: ${_t(h.fatherName)} / 母: ${_t(h.motherName)} / 母父: ${_t(h.mfName)}');
    buf.writeln('- 単勝/人気: ${_d(h.odds)} / ${_i(h.popularity)}');
    buf.writeln(
        '- 馬体重: ${_t(h.horseWeight)}（前走: ${_t(h.previousHorseWeight)}）/ 前走騎手: ${_t(h.previousJockey)}');
    buf.writeln(
        '- アプリ評価: 総合スコア ${_d(h.overallScore)} / 期待値 ${_d(h.expectedValue)} / 馬場適性 ${_t(h.trackAptitudeLabel)}');

    final marks = <String>[];
    if (h.isBlinker) marks.add('ブリンカー');
    if (h.isFirstBlinker) marks.add('初ブリンカー');
    if (h.isMaruGai) marks.add('丸外');
    if (h.isMaruChi) marks.add('丸地');
    buf.writeln('- 新聞マーク: ${marks.isEmpty ? 'なし' : marks.join('・')}');

    final memo = h.userMemo?.predictionMemo?.trim() ?? '';
    buf.writeln(
        '- 予想メモ: ${memo.isEmpty ? '（未記入）' : memo.replaceAll(RegExp(r'[\r\n]+'), ' ')}');
  }
  buf.writeln();

  return buf.toString();
}
