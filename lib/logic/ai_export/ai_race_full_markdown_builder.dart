// lib/logic/ai_export/ai_race_full_markdown_builder.dart
// [追加] AI分析データエクスポート Step3: 出馬表(PredictionRaceData)と収集バンドル(AiRaceExportBundle)から全部入りのAI分析用Markdownを組み立てる純粋関数。DB/I/Oなし。粒度(要約/標準/全部)で情報量を切り替える。Step1の buildRaceAiMarkdown には手を触れない (v.2026.9.27+26092703)

import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/models/ai_export/ai_race_export_bundle.dart';

/// 出力の粒度。要約=直近5走/最終追切1本、標準=直近10走/直近5本、全部=全走/全本＋個別ラップ・旧調教・統計JSON。
enum AiExportGrain { summary, standard, full }

String _t(String? v) {
  if (v == null) return '-';
  final s = v.trim();
  return s.isEmpty ? '-' : s;
}

String _i(int? v) => v == null ? '-' : v.toString();

String _d(double? v) {
  if (v == null) return '-';
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(2);
}

String _cell(String v) =>
    v.replaceAll('|', '／').replaceAll(RegExp(r'[\r\n]+'), ' ').trim();

List<T> _take<T>(List<T> xs, int n) =>
    n < 0 ? xs : (xs.length <= n ? xs : xs.sublist(0, n));

String _grainLabel(AiExportGrain g) {
  switch (g) {
    case AiExportGrain.summary:
      return '要約';
    case AiExportGrain.standard:
      return '標準';
    case AiExportGrain.full:
      return '全部';
  }
}

/// [追加] T1: AI分析資料の先頭に置く「AIへの依頼・用語・出力フォーマット」ブロック（純粋・固定文言）。ユーザーが「添付データで分析して」だけで所定のCSVまで返せるようにする。粒度に依らず常に付与する (v.2026.9.27+26092706)
String _aiInstructionHeader() {
  return '''# この資料の使い方（AIへの依頼）

この資料（Markdown）だけを一次情報として、以下のレースを分析してください。ネット検索や資料に無い事実の創作はせず、資料内のデータと、そこから導ける推論だけで判断してください。「-」「未取得」は「不明」として扱います。引用記号（[cite: n] などの角括弧付き出典表記）は一切出力しないでください。

## 資料の読み方（列・用語）
- レース概要: コース（芝/ダ・距離・回り・内外）、馬場、天候、頭数、1着賞金、過去10年統計の有無。
- 出走馬一覧: 馬番・枠・騎手(斤量)・単勝・人気・馬体重・総合スコア・期待値。「-」は未算出/未発表。
- スピード指数: ベスト/近走平均/トレンド(正=上昇,負=下降)/信頼度(0-1)(サンプル走数)。
- 展開指数: テン加速/末脚/スタミナ(各0-1)/脚質(逃げ・先行・差し・追込・自在 等)。
- 馬柱の各列: 日付 / レース(格) / 距離馬場 / 枠-馬番 / 人気-着順 / タイム(着差) / 通過(コーナー順)-上り3F / ペース(前半-後半 と [S/M/H]=スロー/ミドル/ハイ) / 指数(タイム指数, 大きいほど優秀)。
- 調教: 日付 追切場所 時計(6F-5F-4F-3F-2F-1Fの順・空欄は-) 脚色 評価 併せ馬。

## 出力フォーマット（この順で）
1. レース総論: 想定ペースと隊列、馬場の影響、有利な脚質・枠を3〜5行。
2. 印評価: 全馬に印(◎○▲△☆、無印は「消」)。印付き馬は根拠を1〜2行、消の馬も一言。
3. 買い目: 軸1〜2頭と相手、券種の考え方を簡潔に。
4. 予想メモCSV: 下記ヘッダーで全馬ぶん。各馬の horseId・馬番・馬名は本資料の値をそのまま使う。predictionMemo は各馬150〜250字、半角カンマと改行は使わない(読点は「、」、文末は「。」)、印と結論を含める。コードブロックにして余計な説明は挟まない。

raceId,horseId,horseNumber,horseName,predictionMemo

---

''';
}

/// PredictionRaceData と AiRaceExportBundle から全部入りのAI分析用Markdownを組み立てる（純粋関数・副作用なし）。
String buildRaceFullAiMarkdown({
  required PredictionRaceData raceData,
  required AiRaceExportBundle bundle,
  AiExportGrain grain = AiExportGrain.standard,
}) {
  final int pastLimit = grain == AiExportGrain.summary
      ? 5
      : (grain == AiExportGrain.standard ? 10 : -1);
  final int trainingLimit = grain == AiExportGrain.summary
      ? 1
      : (grain == AiExportGrain.standard ? 5 : -1);
  final bool includeLaps = grain == AiExportGrain.full;
  final bool includeOldTraining = grain == AiExportGrain.full;
  final bool includeStatsJson = grain == AiExportGrain.full;

  final Map<String, AiHorseData> byId = {
    for (final h in bundle.horses) h.horseId: h,
  };

  final buf = StringBuffer();
  // [追加] T1: AIへの依頼・用語・出力フォーマットのフロントマターを先頭に出力 (v.2026.9.27+26092706)
  buf.write(_aiInstructionHeader());
  final grade = raceData.raceGrade.trim();
  buf.writeln(
      '# ${_cell(raceData.raceName)}${grade.isEmpty ? '' : '（$grade）'} AI分析資料（${_grainLabel(grain)}）');
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

  final tc = bundle.trackCondition;
  if (tc != null) {
    buf.writeln(
        '- 馬場詳細: クッション値 ${_d(tc.cushionValue)} / 芝含水率(ゴール前/4角) ${_d(tc.moistureTurfGoal)}/${_d(tc.moistureTurf4c)} / ダート含水率(ゴール前/4角) ${_d(tc.moistureDirtGoal)}/${_d(tc.moistureDirt4c)}');
  }
  final rs = bundle.raceStatistics;
  buf.writeln(
      '- 過去10年統計: ${rs != null ? '登録あり（${_cell(rs.raceName)}）' : '未取得'}');
  final memo = bundle.raceMemoText;
  buf.writeln(
      '- レースメモ: ${(memo == null || memo.trim().isEmpty) ? '（未記入）' : _cell(memo)}');
  buf.writeln();

  if (includeStatsJson && rs != null) {
    buf.writeln('### 過去10年統計データ（JSON）');
    buf.writeln('~~~json');
    buf.writeln(rs.statisticsJson);
    buf.writeln('~~~');
    buf.writeln();
  }

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
    _renderHorse(
      buf,
      h,
      byId[h.horseId],
      pastLimit: pastLimit,
      trainingLimit: trainingLimit,
      includeLaps: includeLaps,
      includeOldTraining: includeOldTraining,
    );
  }

  return buf.toString();
}

void _renderHorse(
  StringBuffer buf,
  PredictionHorseDetail h,
  AiHorseData? d, {
  required int pastLimit,
  required int trainingLimit,
  required bool includeLaps,
  required bool includeOldTraining,
}) {
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

  final profile = d?.profile;
  if (profile != null) {
    buf.writeln(
        '- 血統詳細: 性別 ${_t(profile.gender)} / 誕生 ${_t(profile.birthday)} / 生産者 ${_t(profile.breederName)} / 父父 ${_t(profile.ffName)} 父母 ${_t(profile.fmName)} 母父 ${_t(profile.mfName)} 母母 ${_t(profile.mmName)}');
  }

  final si = d?.speedIndex;
  if (si != null) {
    buf.writeln(
        '- スピード指数: ベスト ${_d(si.bestIndex)} / 近走平均 ${_d(si.recentAvgIndex)} / トレンド ${_d(si.trend)} / 信頼度 ${_d(si.confidence)}（${si.sampleCount}走）');
  }

  final sim = d?.simulationParams;
  if (sim != null) {
    buf.writeln(
        '- 展開指数: テン加速 ${_d(sim.tenAccelIndex)} / 末脚 ${_d(sim.finishingPower)} / スタミナ ${_d(sim.staminaIndex)} / 脚質 ${_t(sim.legStyle)}');
  }

  final rev = d?.trainingReview;
  if (rev != null) {
    buf.writeln('- 調教評価: 追切ランク ${_t(rev.rank)} / 短評 ${_t(rev.shortReview)}');
    buf.writeln('- 厩舎コメント: ${_t(rev.stableComment)}（${_t(rev.stableSpeaker)}）');
  }

  // 馬柱
  buf.writeln();
  buf.writeln('#### 馬柱（過去成績）');
  final perf = d?.performance ?? const [];
  if (perf.isEmpty) {
    buf.writeln('（過去成績データなし）');
  } else {
    // [修正] T3: 馬柱に過去走の馬体重・騎手・頭数を追加、指数を「タイム指数/馬場指数」に (v.2026.9.27+26092707)
    buf.writeln(
        '| 日付 | レース | 距離馬場 | 頭数 | 枠馬番 | 人気着 | 馬体重 | 騎手 | タイム(着差) | 通過/上り | ペース | 指数/馬場 |');
    buf.writeln('|---|---|---|---|---|---|---|---|---|---|---|---|');
    for (final r in _take(perf, pastLimit)) {
      final ex = d?.extrasByRaceId[r.raceId];
      final pace =
          '${_cell(_t(r.pace))}${ex?.paceMark != null ? '[${ex!.paceMark}]' : ''}';
      final index = '${_i(ex?.timeIndex)}/${_i(ex?.trackIndex)}';
      buf.writeln(
          '| ${_cell(_t(r.date))} | ${_cell(_t(r.raceName))} | ${_cell(_t(r.distance))}${_cell(_t(r.trackCondition))} | ${_cell(_t(r.numberOfHorses))} | ${_cell(_t(r.frameNumber))}-${_cell(_t(r.horseNumber))} | ${_cell(_t(r.popularity))}人${_cell(_t(r.rank))}着 | ${_cell(_t(r.horseWeight))} | ${_cell(_t(r.jockey))} | ${_cell(_t(r.time))}(${_cell(_t(r.margin))}) | ${_cell(_t(r.cornerPassage))}/${_cell(_t(r.agari))} | $pace | $index |');
    }
  }

  // 個別ラップ（全部のみ）
  if (includeLaps && perf.isNotEmpty) {
    final lapLines = <String>[];
    for (final r in _take(perf, pastLimit)) {
      final ex = d?.extrasByRaceId[r.raceId];
      final laps = ex?.individualLaps;
      if (laps != null && laps.isNotEmpty) {
        lapLines.add(
            '- ${_cell(_t(r.date))} ${_cell(_t(r.raceName))}: 個別ラップ ${laps.map((e) => _d(e)).join('-')}${ex?.lapRaceType != null ? '（${ex!.lapRaceType}）' : ''}');
      }
    }
    if (lapLines.isNotEmpty) {
      buf.writeln();
      buf.writeln('#### 個別ラップ');
      for (final l in lapLines) {
        buf.writeln(l);
      }
    }
  }

  // 調教
  buf.writeln();
  buf.writeln('#### 調教');
  final sessions = d?.trainingSessions ?? const [];
  if (sessions.isEmpty) {
    buf.writeln('（調教データなし）');
  } else {
    for (final s in _take(sessions, trainingLimit)) {
      final slots = s.slots.map((e) => _d(e)).join('-');
      final best = (s.isBestTime == true) ? ' 一番時計' : '';
      final partners = (s.partners == null || s.partners!.isEmpty)
          ? ''
          : ' 併せ:${s.partners!.map((p) => '${_t(p.name)}(${_t(p.text)})').join('、')}';
      buf.writeln(
          '- ${_cell(_t(s.trainingDate))} ${_cell(_t(s.courseRaw))} ${_t(s.trainingTime)} ${_t(s.trackCondition)} 時計:$slots 脚色:${_t(s.trainingLoad)} 評価:${_t(s.rank)}$best$partners');
    }
  }

  // 旧・調教タイム（全部のみ）
  if (includeOldTraining) {
    final tt = d?.trainingTimes ?? const [];
    if (tt.isNotEmpty) {
      buf.writeln();
      buf.writeln('#### 調教タイム(pakara)');
      for (final t in tt) {
        buf.writeln(
            '- ${_cell(_t(t.trainingDate))} ${_cell(_t(t.trackType))}@${_cell(_t(t.location))} 6F-1F: ${_d(t.f6)}-${_d(t.f5)}-${_d(t.f4)}-${_d(t.f3)}-${_d(t.f2)}-${_d(t.f1)}');
      }
    }
  }

  // 予想メモ
  final pm = h.userMemo?.predictionMemo?.trim() ?? '';
  buf.writeln(
      '- 予想メモ: ${pm.isEmpty ? '（未記入）' : pm.replaceAll(RegExp(r'[\r\n]+'), ' ')}');
}
