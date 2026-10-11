// lib/logic/ai_export/ai_race_full_markdown_builder.dart
// [追加] AI分析データエクスポート Step3: 出馬表(PredictionRaceData)と収集バンドル(AiRaceExportBundle)から全部入りのAI分析用Markdownを組み立てる純粋関数。DB/I/Oなし。粒度(要約/標準/全部)で情報量を切り替える。Step1の buildRaceAiMarkdown には手を触れない (v.2026.9.27+26092703)
// [修正] AI分析データ 天気・コース追加 Step4: コース情報・開催中の馬場推移・天気/馬場予測の節、馬柱の賞金列と通算獲得賞金を追加。計算処理の無い総合スコア・期待値を外し、当日の測定が無いときは最新の測定を馬場詳細に出す (v.2026.10.11+26101104)

import 'dart:convert';

import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/models/ai_export/ai_race_export_bundle.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/track_conditions_model.dart';
import 'package:hetaumakeiba_v2/logic/ai_export/ai_prize_summary.dart';
import 'package:hetaumakeiba_v2/logic/earned_prize_calculator.dart';
import 'package:hetaumakeiba_v2/utils/track_constants.dart';

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
// [修正] AIファイル名整理: 出力フォーマットの保存ファイル名を「インポート総評_／インポート予想メモ_…_raceId.txt」にし、予想メモも ```text ブロックで出させる (v.2026.10.10+26101006)
// [修正] AI分析データ 文章・ラベル除外: 資料の読み方に「脚質の内訳」と「予測含水率の根拠」の説明を追加 (v.2026.10.12+26101201)
String _aiInstructionHeader() {
  return '''# この資料の使い方（AIへの依頼）

この資料（Markdown）だけを一次情報として、以下のレースを分析してください。ネット検索や資料に無い事実の創作はせず、資料内のデータと、そこから導ける推論だけで判断してください。「-」「未取得」は「不明」として扱います。引用記号（[cite: n] などの角括弧付き出典表記）は一切出力しないでください。

## 資料の読み方（列・用語）
- レース概要: コース（芝/ダ・距離・回り・内外）、馬場、天候、頭数、1着賞金、過去10年統計の有無。
- 出走馬一覧: 馬番・枠・騎手(斤量)・単勝・人気・馬体重。「-」は未発表。
- スピード指数: ベスト/近走平均/トレンド(正=上昇,負=下降)/信頼度(0-1)(サンプル走数)。
- 展開指数: テン加速/末脚/スタミナ(各0-1)/脚質(逃げ・先行・差し・追込・自在 等)。
- 脚質の内訳: 過去走の脚質ごとの割合（逃げ・先行・差し・追込の4つで100%）・着度数(1着-2着-3着-着外)・勝率。マクリは割合に含めず、回数と着度数・勝率を末尾の括弧に別に書く（マクリの無い馬は省略）。
- 馬柱の各列: 日付 / レース(格) / 距離馬場 / 枠-馬番 / 人気-着順 / タイム(着差) / 通過(コーナー順)-上り3F / ペース(前半-後半 と [S/M/H]=スロー/ミドル/ハイ) / 指数(タイム指数, 大きいほど優秀) / 賞金(万円。netkeibaの賞金列で重賞は付加賞込み、外国のレースは空)。
- 調教: 日付 追切場所 時計(6F-5F-4F-3F-2F-1Fの順・空欄は-) 脚色 評価 併せ馬。
- 通算獲得賞金: 過去成績の賞金列の合計（中央＋地方。外国は含まない）。JRAの収得賞金（クラス判定用）とは別の値。
- コース情報: 周長・区間の距離（スタートからのm）・標高。標高はコースデータ上の相対値(m)で、勾配は区間内の平均。
- 開催中の馬場推移: 同じ開催のJRA発表値（クッション値と、含水率 G=ゴール前/4C=4コーナー）を古い順に並べたもの。
- 天気・馬場予測: 取得時刻の時点の天気予報と、それを使ったアプリの推定（予測含水率など）。確定値ではない。風速は m/s（元データの km/h を換算）。粒度「全部」では「予測含水率の根拠」（起点の測定・当日の加水と乾燥・地盤補正の内訳）も出す。

## 出力フォーマット（保存できる2つのテキストファイルを、この順で出力）

### 1) AI総評テキスト（.txtで保存 → アプリの「レース情報タブ」の取り込みボタンで読み込む）
「レース総論・印評価・買い目」を1つのコードブロック（先頭を ```text 、末尾を ``` で囲む）にまとめて出力してください。ブロック内は次の3見出しの順にし、余計な説明やこの資料の引用は入れないこと。
- 【レース総論】想定ペースと隊列、馬場の影響、有利な脚質・枠を3〜5行。
- 【印評価】全馬に印(◎○▲△☆、無印は「消」)。印付き馬は根拠を1〜2行、消の馬も一言。
- 【買い目】軸1〜2頭と相手、券種の考え方を簡潔に。
このブロックだけをコピーして、ファイル名「インポート総評_(レース名)_(日付)_(raceId).txt」で保存できるようにすること（レース名は本資料の見出しのレース名、日付とraceIdはレース概要の値を使う）。アプリはファイル名の先頭「インポート総評_」と末尾のraceIdを照合して取り込むため、この形を崩さないこと。

### 2) 予想メモ（中身はカンマ区切り。.txtで保存 → アプリの馬詳細タブ「メモをインポート」で読み込む）
下記ヘッダーで全馬ぶんを、別の1つのコードブロック（先頭を ```text 、末尾を ``` で囲む）に出力してください。各馬の horseId・馬番・馬名は本資料の値をそのまま使う。predictionMemo は各馬150〜250字、半角カンマと改行は使わない(読点は「、」、文末は「。」)、印と結論を含める。ブロック内はヘッダー行とデータ行だけにする。ファイル名は「インポート予想メモ_(レース名)_(日付)_(raceId).txt」とすること（.csv では保存しない。アプリは .txt だけを取り込む）。

raceId,horseId,horseNumber,horseName,predictionMemo

---

''';
}

/// [追加] T2: 過去10年統計(statisticsJson)を整形テーブルで描画するヘルパー群 (v.2026.9.27+26092708)
int _numAwareCompare(String a, String b) {
  final na = int.tryParse(a);
  final nb = int.tryParse(b);
  if (na != null && nb != null) return na.compareTo(nb);
  return a.compareTo(b);
}

Map<String, dynamic>? _asStatMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return v.map((k, val) => MapEntry(k.toString(), val));
  return null;
}

void _renderStatTable(StringBuffer buf, String title,
    Map<String, dynamic>? stats, List<String> order) {
  if (stats == null || stats.isEmpty) return;
  buf.writeln();
  buf.writeln('**$title**');
  buf.writeln('| 区分 | 該当 | 勝 | 連対 | 複勝 | 勝率 | 複勝率 |');
  buf.writeln('|---|---|---|---|---|---|---|');
  final keys = <String>[];
  for (final k in order) {
    if (stats.containsKey(k)) keys.add(k);
  }
  final rest = stats.keys.where((k) => !order.contains(k)).toList()
    ..sort(_numAwareCompare);
  keys.addAll(rest);
  for (final k in keys) {
    final v = stats[k];
    if (v is! Map) continue;
    final total = (v['total'] as num?)?.toInt() ?? 0;
    final win = (v['win'] as num?)?.toInt() ?? 0;
    final place = (v['place'] as num?)?.toInt() ?? 0;
    final show = (v['show'] as num?)?.toInt() ?? 0;
    final wr = total > 0 ? (win * 100 / total).round().toString() : '-';
    final sr = total > 0 ? (show * 100 / total).round().toString() : '-';
    buf.writeln('| ${_cell(k)} | $total | $win | $place | $show | $wr% | $sr% |');
  }
}

void _renderRaceStatistics(StringBuffer buf, String? statisticsJson) {
  if (statisticsJson == null || statisticsJson.trim().isEmpty) return;
  Map<String, dynamic>? data;
  try {
    final decoded = jsonDecode(statisticsJson);
    if (decoded is Map<String, dynamic>) data = decoded;
  } catch (_) {
    data = null;
  }
  if (data == null) return;
  buf.writeln();
  buf.writeln('## 過去10年傾向（縦の比較）');
  final years = data['analyzedYears'];
  if (years is List && years.isNotEmpty) {
    buf.writeln('- 対象年: ${years.join('、')}（${years.length}年）');
  }
  final avgW = data['avgWinningHorseWeight'];
  if (avgW is num && avgW > 0) {
    buf.writeln('- 勝ち馬の平均馬体重: ${avgW.round()}kg');
  }
  _renderStatTable(buf, '枠番別', _asStatMap(data['frameStats']),
      const ['1', '2', '3', '4', '5', '6', '7', '8']);
  _renderStatTable(buf, '脚質別', _asStatMap(data['legStyleStats']),
      const ['逃げ', '先行', '差し', '追込']);
  _renderStatTable(
      buf, '人気別', _asStatMap(data['popularityStats']), const <String>[]);
  _renderStatTable(
      buf, '性別別', _asStatMap(data['genderStats']), const ['牡', '牝', 'セ']);
  _renderStatTable(buf, '馬体重増減別', _asStatMap(data['horseWeightChangeStats']),
      const ['-10kg以下', '-4~-8kg', '-2~+2kg', '+4~+8kg', '+10kg以上']);
  buf.writeln();
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
  // [修正] AI分析データ 天気・コース追加 Step4: 当日の測定が無いときは、その競馬場の最新の測定を日付付きで出す (v.2026.10.11+26101104)
  final latestTc = bundle.latestVenueTrackCondition;
  if (tc != null) {
    buf.writeln('- 馬場詳細: ${_trackDetailText(tc)}');
  } else if (latestTc != null) {
    buf.writeln(
        '- 馬場詳細（当日の測定なし・最新測定 ${latestTc.date}）: ${_trackDetailText(latestTc)}');
  }
  final rs = bundle.raceStatistics;
  buf.writeln(
      '- 過去10年統計: ${rs != null ? '登録あり（${_cell(rs.raceName)}）' : '未取得'}');
  // [削除] AI分析データ 文章・ラベル除外: 今回のレースのレースメモ（AI予想・買い目）は出さない。予想中の印・メモはデータとして渡さない (v.2026.10.12+26101201)
  buf.writeln();

  // [追加] AI分析データ 天気・コース追加 Step4: コース情報・開催中の馬場推移・天気/馬場予測 (v.2026.10.11+26101104)
  _renderCourseSection(buf, raceData, bundle, grain);
  _renderMeetingTrackSection(buf, raceData, bundle, grain);
  _renderWeatherSection(buf, raceData, bundle, grain);

  // [修正] T2: 過去10年統計(縦の比較)を生JSONではなく整形テーブルで出力。要約粒度では省略 (v.2026.9.27+26092708)
  if (grain != AiExportGrain.summary) {
    _renderRaceStatistics(buf, rs?.statisticsJson);
  }

  // 出走馬一覧
  buf.writeln('## 出走馬一覧');
  // [修正] AI分析データ 天気・コース追加 Step4: 計算処理の無い総合スコア・期待値の列を外した (v.2026.10.11+26101104)
  buf.writeln(
      '| 馬番 | 枠 | 馬名 | 性齢 | 騎手(斤量) | 単勝 | 人気 | 馬体重 | 出否 |');
  buf.writeln('|---|---|---|---|---|---|---|---|---|');
  for (final h in raceData.horses) {
    final jockey = '${_cell(_t(h.jockey))}(${_d(h.carriedWeight)})';
    buf.writeln(
        '| ${h.horseNumber} | ${h.gateNumber} | ${_cell(_t(h.horseName))} | ${_cell(_t(h.sexAndAge))} | $jockey | ${_d(h.odds)} | ${_i(h.popularity)} | ${_cell(_t(h.horseWeight))} | ${h.isScratched ? '取消' : '出走'} |');
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
  // [修正] AI分析データ 天気・コース追加 Step4: 総合スコア・期待値を外し、通算獲得賞金を追加 (v.2026.10.11+26101104)
  // [削除] AI分析データ 文章・ラベル除外: アプリが判定した馬場適性のラベル（アプリ評価）は出さない (v.2026.10.12+26101201)
  buf.writeln(_prizeLine(d?.performance ?? const []));

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

  // [追加] AI分析データ 文章・ラベル除外: 出馬表の「脚質詳細」と同じ数値（4脚質の割合・着度数・勝率、マクリは回数で別記）を出す (v.2026.10.12+26101201)
  final legProfile = h.legStyleProfile;
  if (legProfile != null) {
    const legStylesOrder = ['逃げ', '先行', '差し', '追込'];
    final hasRecords = legProfile.styleRecordCounts.isNotEmpty;
    final legParts = <String>[];
    for (final style in legStylesOrder) {
      final percentage = (legProfile.styleDistribution[style] ?? 0.0) * 100;
      if (!hasRecords) {
        legParts.add('$style ${percentage.toStringAsFixed(1)}%');
        continue;
      }
      final record = legProfile.styleRecordCounts[style] ?? const [0, 0, 0, 0];
      final winRate = (legProfile.styleWinRates[style] ?? 0.0) * 100;
      legParts.add(
          '$style ${percentage.toStringAsFixed(1)}%（${record[0]}-${record[1]}-${record[2]}-${record[3]}, 勝率${winRate.toStringAsFixed(1)}%）');
    }
    var legTail = '';
    if (!hasRecords) {
      legTail = '（着度数・勝率は未計算）';
    } else {
      final makuri = legProfile.styleRecordCounts['マクリ'] ?? const [0, 0, 0, 0];
      final makuriCount = makuri[0] + makuri[1] + makuri[2] + makuri[3];
      if (makuriCount > 0) {
        final makuriWinRate = (legProfile.styleWinRates['マクリ'] ?? 0.0) * 100;
        legTail =
            '（マクリ $makuriCount回: ${makuri[0]}-${makuri[1]}-${makuri[2]}-${makuri[3]}, 勝率${makuriWinRate.toStringAsFixed(1)}%）';
      }
    }
    buf.writeln('- 脚質の内訳: ${legParts.join(' / ')}$legTail');
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
    // [修正] AI分析データ 天気・コース追加 Step4: 末尾に賞金(万円)の列を追加 (v.2026.10.11+26101104)
    buf.writeln(
        '| 日付 | レース | 距離馬場 | 頭数 | 枠馬番 | 人気着 | 馬体重 | 騎手 | タイム(着差) | 通過/上り | ペース | 指数/馬場 | 賞金(万円) |');
    buf.writeln('|---|---|---|---|---|---|---|---|---|---|---|---|---|');
    for (final r in _take(perf, pastLimit)) {
      final ex = d?.extrasByRaceId[r.raceId];
      final pace =
          '${_cell(_t(r.pace))}${ex?.paceMark != null ? '[${ex!.paceMark}]' : ''}';
      final index = '${_i(ex?.timeIndex)}/${_i(ex?.trackIndex)}';
      // [追加] T4a: 過去走の馬場(クッション値/含水率)を距離馬場セルに付記
      final tc = d?.pastTrackByRaceId[r.raceId];
      final moist = tc?.moistureTurfGoal ?? tc?.moistureDirtGoal;
      final trackTag = tc == null
          ? ''
          : (tc.cushionValue != null
              ? '(ク${_d(tc.cushionValue)})'
              : (moist != null ? '(含${_d(moist)}%)' : ''));
      final track =
          '${_cell(_t(r.distance))}${_cell(_t(r.trackCondition))}$trackTag';
      buf.writeln(
          '| ${_cell(_t(r.date))} | ${_cell(_t(r.raceName))} | $track | ${_cell(_t(r.numberOfHorses))} | ${_cell(_t(r.frameNumber))}-${_cell(_t(r.horseNumber))} | ${_cell(_t(r.popularity))}人${_cell(_t(r.rank))}着 | ${_cell(_t(r.horseWeight))} | ${_cell(_t(r.jockey))} | ${_cell(_t(r.time))}(${_cell(_t(r.margin))}) | ${_cell(_t(r.cornerPassage))}/${_cell(_t(r.agari))} | $pace | $index | ${formatAiPrizeMan(parsePrizeInThousandYen(r.prizeMoney))} |');
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
  // [削除] AI分析データ 文章・ラベル除外: 今回のレースの予想メモは出さない。予想中の印・メモはデータとして渡さない (v.2026.10.12+26101201)
}

// [追加] AI分析データ 天気・コース追加 Step4: コース情報・開催中の馬場推移・天気/馬場予測・獲得賞金の描画ヘルパー (v.2026.10.11+26101104)

/// 符号つきの小数（0 は ±）。
String _signed(double v, int digits) {
  final rounded = double.parse(v.toStringAsFixed(digits));
  if (rounded == 0) return '±${0.toStringAsFixed(digits)}';
  return rounded > 0
      ? '+${rounded.toStringAsFixed(digits)}'
      : rounded.toStringAsFixed(digits);
}

/// 小数の固定桁（null は '-'）。
String _f(double? v, int digits) => v == null ? '-' : v.toStringAsFixed(digits);

/// 距離(m)の表記。整数ならそのまま、そうでなければ小数1桁。
String _meters(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

/// 'YYYY年M月D日' などから 'YYYY-MM-DD' を作る（読めなければ null）。
String? _isoDate(String raceDate) {
  final m = RegExp(r'(\d{4})[^\d]*(\d{1,2})[^\d]*(\d{1,2})').firstMatch(raceDate);
  if (m == null) return null;
  return '${m.group(1)}-${m.group(2)!.padLeft(2, '0')}-${m.group(3)!.padLeft(2, '0')}';
}

const Map<String, String> _weekDayLabels = {
  'mo': '月',
  'tu': '火',
  'we': '水',
  'th': '木',
  'fr': '金',
  'sa': '土',
  'su': '日',
};

/// 馬場の測定1件の「クッション値 / 芝含水率 / ダート含水率」の文。
String _trackDetailText(TrackConditionRecord tc) =>
    'クッション値 ${_d(tc.cushionValue)} / 芝含水率(ゴール前/4角) ${_d(tc.moistureTurfGoal)}/${_d(tc.moistureTurf4c)} / ダート含水率(ゴール前/4角) ${_d(tc.moistureDirtGoal)}/${_d(tc.moistureDirt4c)}';

String _courseTypeLabel(String trackType) {
  switch (trackType) {
    case 'shiba':
      return '芝';
    case 'shiba_inner':
      return '芝・内回り';
    case 'shiba_outer':
      return '芝・外回り';
    case 'shiba_straight':
      return '芝・直線';
    case 'dirt':
      return 'ダート';
    default:
      return trackType;
  }
}

void _renderCourseSection(StringBuffer buf, PredictionRaceData raceData,
    AiRaceExportBundle bundle, AiExportGrain grain) {
  buf.writeln('## コース情報');
  final profile = bundle.courseProfile;
  final preset = bundle.coursePreset;

  if (profile == null) {
    buf.writeln('- コースデータ: なし（障害、またはデータの無いコース）');
  } else {
    final direction = profile.isStraightCourse
        ? '直線'
        : (profile.isLeftHanded ? '左回り' : '右回り');
    buf.writeln(
        '- コース: ${_cell(_t(raceData.venue))} ${_courseTypeLabel(profile.trackType)} ${profile.raceDistance}m / $direction / 1周 ${_meters(profile.lapDistance)}m');
  }
  if (preset != null) {
    buf.writeln('- ゴール前直線（プリセット）: ${preset.straightLength}m');
    // [削除] AI分析データ 文章・ラベル除外: プリセットの解説文（コースの特徴・ポイント）は出さない (v.2026.10.12+26101201)
  }
  if (profile == null) {
    buf.writeln();
    return;
  }

  buf.writeln(
      '- 標高: スタート ${_f(profile.startElevation, 2)}m → ゴール ${_f(profile.goalElevation, 2)}m / 最高 ${_f(profile.maxElevation, 2)}m（スタートから${profile.maxElevationFromStart}m）/ 最低 ${_f(profile.minElevation, 2)}m（スタートから${profile.minElevationFromStart}m）/ 高低差 ${_f(profile.elevationRange, 2)}m');
  final straight = profile.finalStraight;
  if (straight != null) {
    final grade = straight.averageGradePercent;
    buf.writeln(
        '- ゴール前直線（コースデータ）: ${_meters(straight.lengthMeters)}m / 標高変化 ${_signed(straight.elevationChange, 2)}m${grade == null ? '' : '（平均勾配 ${_signed(grade, 2)}%）'}');
  }
  buf.writeln('- 標高はコースデータ上の相対値（m）。距離はスタートからのm。');

  buf.writeln();
  buf.writeln('| 区間 | 距離(スタートから) | 長さ | 標高(始→終) | 標高変化 | 平均勾配 | 路面 |');
  buf.writeln('|---|---|---|---|---|---|---|');
  for (final s in profile.sections) {
    final grade = s.averageGradePercent;
    buf.writeln(
        '| ${_cell(s.label)} | ${_meters(s.startMeters)}〜${_meters(s.endMeters)}m | ${_meters(s.lengthMeters)}m | ${_f(s.startElevation, 2)}→${_f(s.endElevation, 2)} | ${_signed(s.elevationChange, 2)} | ${grade == null ? '-' : '${_signed(grade, 2)}%'} | ${s.surface ?? '-'} |');
  }

  if (grain != AiExportGrain.summary) {
    buf.writeln();
    buf.writeln('**100mごとの標高**');
    buf.writeln('| スタートから | 残り | 標高(m) |');
    buf.writeln('|---|---|---|');
    for (final p in profile.samples) {
      buf.writeln(
          '| ${p.fromStartMeters}m | ${p.remainingMeters}m | ${_f(p.elevation, 2)} |');
    }
  }
  buf.writeln();
}

void _renderMeetingTrackSection(StringBuffer buf, PredictionRaceData raceData,
    AiRaceExportBundle bundle, AiExportGrain grain) {
  buf.writeln('## 開催中の馬場推移（JRA発表・同じ開催）');
  final history = bundle.meetingTrackHistory;
  if (history.isEmpty) {
    buf.writeln('- 測定データなし（馬場状態ページで更新）');
    buf.writeln();
    return;
  }

  final rows = grain == AiExportGrain.summary && history.length > 3
      ? history.sublist(history.length - 3)
      : history;
  final raceDay = _isoDate(raceData.raceDate);

  buf.writeln('| 日付 | クッション値 | 芝含水率 G/4C | ダ含水率 G/4C |');
  buf.writeln('|---|---|---|---|');
  for (final r in rows) {
    final week = _weekDayLabels[r.weekDay];
    final dateLabel =
        '${r.date}${week == null ? '' : '($week)'}${r.date == raceDay ? '（レース当日）' : ''}';
    final cushion = r.cushionValue == null
        ? '-'
        : '${_f(r.cushionValue, 1)}（${TrackConstants.getCushionEvaluation(r.cushionValue!)}）';
    buf.writeln(
        '| $dateLabel | $cushion | ${_f(r.moistureTurfGoal, 1)}/${_f(r.moistureTurf4c, 1)} | ${_f(r.moistureDirtGoal, 1)}/${_f(r.moistureDirt4c, 1)} |');
  }

  if (history.length >= 2) {
    final latest = history[history.length - 1];
    final previous = history[history.length - 2];
    final diffs = <String>[];
    if (latest.cushionValue != null && previous.cushionValue != null) {
      diffs.add(
          'クッション値 ${_signed(latest.cushionValue! - previous.cushionValue!, 1)}');
    }
    if (latest.moistureTurfGoal != null && previous.moistureTurfGoal != null) {
      diffs.add(
          '芝含水率(G) ${_signed(latest.moistureTurfGoal! - previous.moistureTurfGoal!, 1)}%');
    }
    if (latest.moistureDirtGoal != null && previous.moistureDirtGoal != null) {
      diffs.add(
          'ダ含水率(G) ${_signed(latest.moistureDirtGoal! - previous.moistureDirtGoal!, 1)}%');
    }
    if (diffs.isNotEmpty) {
      buf.writeln(
          '- 最新(${latest.date})と前回(${previous.date})の差: ${diffs.join('、')}');
    }
  }
  buf.writeln();
}

void _renderWeatherSection(StringBuffer buf, PredictionRaceData raceData,
    AiRaceExportBundle bundle, AiExportGrain grain) {
  buf.writeln('## 天気・馬場予測（予報とアプリの推定）');
  final w = bundle.weatherSnapshot;
  if (w == null) {
    buf.writeln('- 天気: ${bundle.weatherUnavailableReason ?? '未取得'}');
    buf.writeln();
    return;
  }

  final rt = w.raceTime;
  buf.writeln('- 取得時刻: ${_t(w.fetchedAt)}（予報・推定はこの時点のもの）');
  buf.writeln(
      '- 発走時刻(${_t(raceData.startTime)})の予報: ${rt.weatherText} / 気温 ${_f(rt.temperature, 1)}℃ / 湿度 ${_i(rt.humidity)}% / 降水確率 ${_i(rt.precipitationProbability)}% / 降水量 ${_f(rt.precipitation, 1)}mm / 風 ${_t(rt.windDirectionText)} ${_f(rt.windSpeedMs, 1)}m/s（${_f(rt.windSpeedKmh, 1)}km/h）/ 突風 ${_f(rt.gustsMs, 1)}m/s / 体感 ${_f(rt.apparentTemperature, 1)}℃ / 日射 ${_f(rt.radiation, 0)}W/m² / 視程 ${_f(rt.visibilityKm, 1)}km');

  if (w.timeline.isNotEmpty) {
    buf.writeln();
    buf.writeln('**午後の時系列（予報）**');
    buf.writeln('| 時刻 | 天気 | 気温 | 降水確率 | 降水量 | 風速 |');
    buf.writeln('|---|---|---|---|---|---|');
    for (final h in w.timeline) {
      buf.writeln(
          '| ${_cell(h.time)} | ${h.weatherText} | ${_f(h.temperature, 1)}℃ | ${_i(h.precipitationProbability)}% | ${_f(h.precipitation, 1)}mm | ${_f(h.windSpeedMs, 1)}m/s |');
    }
    buf.writeln();
  }

  final isDirt = (raceData.trackType ?? '').contains('ダ');
  final moisture = w.predictedMoisture;
  if (moisture == null) {
    buf.writeln('- 馬場予測: 起点となる馬場の測定が無いため計算できない');
  } else {
    final leaning = (w.jraLeaning == null || w.jraLeaning!.isEmpty)
        ? ''
        : w.jraLeaning!;
    final cushion = !isDirt && w.predictedCushion != null
        ? ' / 予測クッション値 ${_f(w.predictedCushion, 1)}'
        : '';
    final base = w.baseline == null ? '' : '（起点: ${w.baseline!.date} の測定）';
    buf.writeln(
        '- 馬場予測: JRA基準で ${_t(w.jraCondition)}$leaning / 予測含水率 ${_f(moisture, 1)}%（${isDirt ? 'ダート' : '芝'}）$cushion$base');
  }

  // [追加] AI分析データ 文章・ラベル除外: 予測含水率の根拠（計算の内訳）を馬場予測の直後に出す。全部の粒度のみ。根拠が複数あれば全部出し、乖離アラートの文章は出さない (v.2026.10.12+26101201)
  if (grain == AiExportGrain.full) {
    for (final insight in w.insights) {
      if (insight.basis == null) continue;
      final lines = insight.basis!
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty && !l.contains('【乖離アラート】'))
          .toList();
      if (lines.isEmpty) continue;
      buf.writeln('- 予測含水率の根拠: ${_cell(lines.join(' / '))}');
    }
  }

  // [削除] AI分析データ 文章・ラベル除外: 直線の風の文章とインサイト（見出し・説明文）は出さない (v.2026.10.12+26101201)
  if (grain != AiExportGrain.summary) {
    if (w.daily.isNotEmpty) {
      buf.writeln();
      buf.writeln('**開催週の日別（予報・実績）**');
      buf.writeln('| 日付 | 天気 | 最高/最低 | 降水量 |');
      buf.writeln('|---|---|---|---|');
      for (final d in w.daily) {
        buf.writeln(
            '| ${_cell(d.date)} | ${d.weatherText} | ${_f(d.tempMax, 1)}/${_f(d.tempMin, 1)}℃ | ${_f(d.precipitationSum, 1)}mm |');
      }
    }
  }
  buf.writeln();
}

/// 通算獲得賞金の行（過去成績の賞金列の合計）。
String _prizeLine(List<HorseRaceRecord> performance) {
  if (performance.isEmpty) return '- 通算獲得賞金: -（過去成績データなし）';
  final summary = summarizeAiPrize(performance);
  if (summary.totalThousandYen == null) {
    return '- 通算獲得賞金: -（賞金のある走なし／成績${summary.totalRuns}件）';
  }
  return '- 通算獲得賞金: ${formatAiPrizeMan(summary.totalThousandYen)}万円（賞金のある${summary.runsWithPrize}走／成績${summary.totalRuns}件）';
}
