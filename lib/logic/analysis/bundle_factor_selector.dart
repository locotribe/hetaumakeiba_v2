// lib/logic/analysis/bundle_factor_selector.dart

import 'package:hetaumakeiba_v2/logic/analysis/factor_candidate_selector.dart';
import 'package:hetaumakeiba_v2/models/race_analysis_bundle.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/models/relative_evaluation_model.dart';

// [追加] RaceAnalysisBundle から、ペース・馬場・血統・ローテ・人気妙味の該当馬を選出する (v.2026.9.5+26090506)
///
/// 配当〜調教師タブ（statisticsJson由来）は全出走馬を母集団にした「リフト」で評価できるが、
/// ここで扱う5ファクターは HistoricalMatchEngine が出す 0〜100 のスコアが元になっている。
/// そのため 50点=1.00倍 として擬似的な倍率に換算し、表示上は「適合」と明示して区別する。
/// 例外はペースで、シミュレーション勝率という実際の率を持つため本物のリフトを算出できる。
class BundleFactorSelector {
  static const int maxCandidates = FactorCandidateSelector.maxCandidates;

  /// 表示順を固定するためのファクターキー一覧
  static const List<String> factorKeys = [
    'pace',
    'trackCondition',
    'pedigree',
    'rotation',
    'popularityValue',
  ];

  /// ファクターキーと画面表示名の対応
  static const Map<String, String> factorLabels = {
    'pace': 'ペース',
    'trackCondition': '馬場状態',
    'pedigree': '血統',
    'rotation': 'ローテーション',
    'popularityValue': '人気妙味',
  };

  static const String _disclaimer =
      'ここに出ている馬は「過去データの傾向に当てはまる」というだけで、'
      '今回の結果を予想したものではありません。あくまで判断材料のひとつとしてご覧ください。';

  // ---------------------------------------------------------------------------
  // 内部ヘルパー
  // ---------------------------------------------------------------------------

  /// 0〜100のスコアを擬似的な倍率へ換算する（50点=1.00倍、100点=2.00倍）
  static double _scoreToLift(double score) {
    final clamped = score.clamp(0.0, 100.0);
    return clamped / 50.0;
  }

  static Map<String, double> _uniformLifts(double lift) {
    return {for (final metric in FactorMetric.all) metric: lift};
  }

  /// horseId から今回の馬番・枠番を引く
  static PredictionHorseDetail? _findHorse(
      List<PredictionHorseDetail> horses, String horseId) {
    for (final horse in horses) {
      if (horse.horseId == horseId) return horse;
    }
    return null;
  }

  /// 指標ごとにリフト降順で上位を切り出す
  static Map<String, List<FactorCandidate>> _buildByMetric(
      List<FactorCandidate> all) {
    final Map<String, List<FactorCandidate>> byMetric = {};
    for (final metric in FactorMetric.all) {
      final sorted = List<FactorCandidate>.from(all)
        ..sort((a, b) {
          final cmp = b.liftFor(metric).compareTo(a.liftFor(metric));
          if (cmp != 0) return cmp;
          return a.horseNumber.compareTo(b.horseNumber);
        });
      final filtered = sorted.where((c) => c.liftFor(metric) > 0).toList();
      byMetric[metric] = filtered.length <= maxCandidates
          ? filtered
          : filtered.sublist(0, maxCandidates);
    }
    return byMetric;
  }

  // ---------------------------------------------------------------------------
  // 1. ペース : シミュレーション勝率が高い馬を、想定ペース別に抽出
  // ---------------------------------------------------------------------------

  static FactorCandidateResult selectByPace(
    RaceAnalysisBundle bundle,
    List<PredictionHorseDetail> horses,
  ) {
    const label = 'ペース';
    const criteria = '想定ペースごとのシミュレーション勝率が高い馬を上位$maxCandidates頭まで選出';

    // 出走頭数から「全馬が互角なら何%か」を求め、これを1.00倍の基準線にする
    final int fieldSize = horses.where((h) => !h.isScratched).length;
    final double baseRate = fieldSize > 0 ? 100.0 / fieldSize : 0.0;

    const Map<String, RacePace> slotToPace = {
      FactorMetric.win: RacePace.slow,
      FactorMetric.place: RacePace.middle,
      FactorMetric.show: RacePace.high,
    };

    final List<FactorCandidate> list = [];
    for (final horse in horses) {
      if (horse.isScratched || horse.horseNumber <= 0) continue;
      final rel = bundle.relativeBattleResults[horse.horseId];
      if (rel == null) continue;

      final Map<String, double> rates = {};
      final Map<String, double> lifts = {};
      for (final entry in slotToPace.entries) {
        final rate = (rel.scenarioWinRates[entry.value] ?? 0.0) * 100.0;
        rates[entry.key] = rate;
        lifts[entry.key] = baseRate > 0 ? rate / baseRate : 0.0;
      }

      // 表示にはペース別の想定順位を使う
      final int slowRank = rel.scenarioRanks[RacePace.slow] ?? 0;
      final int midRank = rel.scenarioRanks[RacePace.middle] ?? 0;
      final int highRank = rel.scenarioRanks[RacePace.high] ?? 0;

      list.add(FactorCandidate(
        horseId: horse.horseId,
        horseNumber: horse.horseNumber,
        gateNumber: horse.gateNumber,
        horseName: horse.horseName,
        reason: '想定順位  スロー$slowRank位 / ミドル$midRank位 / ハイ$highRank位',
        rates: rates,
        lifts: lifts,
      ));
    }

    final summary = fieldSize > 0
        ? '$fieldSize頭立て。全馬が互角なら勝率${baseRate.toStringAsFixed(1)}% が基準（1.00倍）です'
        : 'シミュレーションに必要な出馬表データがありません。';

    final notes = <String>[
      'ペースは「レースが速く流れるか、遅く流れるか」で有利な馬が入れ替わることを見るファクターです。'
      'ここでは展開シミュレーションを想定ペースごとに走らせ、勝つ確率が高く出た馬を並べています。'
      '上の切替ボタンで想定ペースを変えると顔ぶれが変わります。'
      '倍率は「全馬が互角だった場合の勝率」を1.00倍とした比較値です。'
      'スローで上位に来る馬は前に行ける馬、ハイで上位に来る馬は末脚が使える馬、'
      'どのペースでも上位に残る馬は展開に左右されにくい馬、という読み方ができます。'
      '今回のメンバーに逃げたい馬が何頭いるかを「脚質」タブで確認し、'
      '多ければハイ寄り、少なければスロー寄りで見ると精度が上がります。',
      'このシミュレーションは過去の走破内容から組み立てた推定です。'
      '実際のペースは当日の各馬の出方で決まるため、'
      '3つのシナリオを見比べて「どのペースでも残る馬」と「特定のペースでだけ浮上する馬」を'
      '区別する使い方をおすすめします。',
      _disclaimer,
    ];

    return FactorCandidateResult(
      factorKey: 'pace',
      factorLabel: label,
      trendSummary: summary,
      criteria: criteria,
      candidatesByMetric: _buildByMetric(list),
      emptyMessage: list.isEmpty ? '展開シミュレーションの結果が取得できませんでした。' : null,
      notes: notes,
      isRateBased: true,
      metricLabels: const {
        FactorMetric.win: 'スロー',
        FactorMetric.place: 'ミドル',
        FactorMetric.show: 'ハイ',
      },
      // 横断集計ではミドルペースを基準にする
      neutralMetric: FactorMetric.place,
    );
  }

  // ---------------------------------------------------------------------------
  // 2. 馬場状態 : クッション値・含水率のシナリオ別に適性が高い馬を抽出
  // ---------------------------------------------------------------------------

  static FactorCandidateResult selectByTrackCondition(
    RaceAnalysisBundle bundle,
    List<PredictionHorseDetail> horses,
  ) {
    const label = '馬場状態';
    const criteria = '想定される馬場状態ごとに、過去の好走時の馬場と近い馬を上位$maxCandidates頭まで選出';

    final trend = bundle.trackConditionTrendResult;
    final bool isDirt = bundle.isDirt;

    const Map<String, String> slotToScenario = {
      FactorMetric.win: 'high',
      FactorMetric.place: 'standard',
      FactorMetric.show: 'low',
    };

    final List<FactorCandidate> list = [];
    for (final match in bundle.matchResults) {
      final horse = _findHorse(horses, match.horseId);
      if (horse == null || horse.isScratched || horse.horseNumber <= 0) continue;

      final Map<String, double> lifts = {};
      for (final entry in slotToScenario.entries) {
        final score = match.trackConditionScores[entry.value] ?? 0.0;
        lifts[entry.key] = _scoreToLift(score);
      }

      final highScore = match.trackConditionScores['high'] ?? 0.0;
      final stdScore = match.trackConditionScores['standard'] ?? 0.0;
      final lowScore = match.trackConditionScores['low'] ?? 0.0;

      list.add(FactorCandidate(
        horseId: match.horseId,
        horseNumber: horse.horseNumber,
        gateNumber: horse.gateNumber,
        horseName: match.horseName,
        reason: '適性スコア  高${highScore.toStringAsFixed(0)} / '
            '標準${stdScore.toStringAsFixed(0)} / 低${lowScore.toStringAsFixed(0)}',
        lifts: lifts,
      ));
    }

    final String trendText = isDirt
        ? '過去の平均含水率 ${trend.avgDirtMoisture.toStringAsFixed(1)}%'
        : '過去の平均クッション値 ${trend.avgCushion.toStringAsFixed(1)}'
            '（最高 ${trend.maxCushion.toStringAsFixed(1)} / 最低 ${trend.minCushion.toStringAsFixed(1)}）';

    final String unitName = isDirt ? '含水率' : 'クッション値';
    final String highLabel = isDirt ? '湿った馬場' : '硬めの高速馬場';
    final String lowLabel = isDirt ? '乾いた馬場' : '軟らかい時計のかかる馬場';

    final notes = <String>[
      '馬場状態は「その日の馬場が硬いか軟らかいか」で、得意な馬が入れ替わることを見るファクターです。'
      '$unitName を指標にして、各馬が過去に1〜3着した時の馬場と、'
      '今回想定される馬場がどれだけ近いかを点数にしています。'
      '上の切替ボタンで「高」を選ぶと$highLabel、「低」を選ぶと$lowLabelを想定した並びになります。'
      '当日の$unitNameが発表されたら、それに近いシナリオを選んで見てください。'
      'まだ発表前なら「標準」が過去の平均に最も近い想定です。',
      'この点数は各馬の過去の好走時の$unitNameの平均と、想定値との差から算出しています。'
      '過去に好走が少ない馬や、$unitNameのデータが取れていないレースしか走っていない馬は'
      '一律50点（＝1.00倍）になるため、上位に来なくても不利という意味ではありません。'
      '「適合」と表示しているのは、他のタブの倍率（実際の複勝率を全体平均で割った値）とは'
      '性質が違う点数だからです。数値の大小だけを他タブと直接比べないようご注意ください。',
      _disclaimer,
    ];

    return FactorCandidateResult(
      factorKey: 'trackCondition',
      factorLabel: label,
      trendSummary: trendText,
      criteria: criteria,
      candidatesByMetric: _buildByMetric(list),
      emptyMessage: list.isEmpty ? '馬場適性を判定できる出走馬データがありません。' : null,
      notes: notes,
      isRateBased: false,
      metricLabels: Map<String, String>.unmodifiable({
        FactorMetric.win: isDirt ? '含水率 高' : 'クッション 高',
        FactorMetric.place: '標準',
        FactorMetric.show: isDirt ? '含水率 低' : 'クッション 低',
      }),
      // 横断集計では標準の馬場を基準にする
      neutralMetric: FactorMetric.place,
    );
  }

  // ---------------------------------------------------------------------------
  // 3. 血統 : 過去にこのレースで好走した父・母父を持つ馬を抽出
  // ---------------------------------------------------------------------------

  static FactorCandidateResult selectByPedigree(
    RaceAnalysisBundle bundle,
    List<PredictionHorseDetail> horses,
  ) {
    const label = '血統';
    const criteria = '過去にこのレースで好走した父・母父を持つ馬を上位$maxCandidates頭まで選出';

    final cross = bundle.pedigreeCrossResult;
    final topSires = cross.overallSires.take(3).map((e) => '${e.name}(${e.count}回)');
    final summary = topSires.isEmpty
        ? '血統データがまだ取得されていません。「総合」タブから血統情報を取得してください。'
        : '好走が多い父: ${topSires.join(" / ")}';

    final List<FactorCandidate> list = [];
    for (final match in bundle.matchResults) {
      final horse = _findHorse(horses, match.horseId);
      if (horse == null || horse.isScratched || horse.horseNumber <= 0) continue;

      final profile = bundle.horseProfileMap[match.horseId];
      final String pedigreeText = profile == null || profile.fatherName.isEmpty
          ? '血統データ未取得'
          : '父 ${profile.fatherName}'
              '${profile.mfName.isEmpty ? "" : " / 母父 ${profile.mfName}"}';

      list.add(FactorCandidate(
        horseId: match.horseId,
        horseNumber: horse.horseNumber,
        gateNumber: horse.gateNumber,
        horseName: match.horseName,
        reason: '$pedigreeText  【${match.pedigreeDiag}】',
        lifts: _uniformLifts(_scoreToLift(match.pedigreeScore)),
      ));
    }

    final notes = <String>[
      '血統は「このレースで走る血の傾向」を見るファクターです。'
      '過去10年前後で1〜3着に入った馬の父と母父を数え、'
      '同じ父・母父を持つ今回の出走馬に点数を付けています。'
      '父が3回以上好走していれば大きく加点（父特注）、2回なら中程度、1回でも少し加点します。'
      '母父の実績も上乗せされます。'
      'コース形状や距離への適性は血統に出やすいので、'
      '同じ血を引く馬が繰り返し好走しているレースでは有力な手がかりになります。',
      '【他タブとの違いにご注意ください】'
      'この点数は「1〜3着に入った馬」だけを数えて作っています。'
      '配当〜調教師タブの倍率が「全出走馬を分母にした複勝率」なのに対し、'
      'こちらは分母がないため、同じ数字でも意味が違います。'
      '「$maxCandidates頭中3回好走した父」なのか「50頭中3回」なのかは区別できていません。'
      '出走頭数の多い人気種牡馬ほど回数が増えやすい点を差し引いて見てください。'
      '表示を「適合」としているのはこのためです。',
      '血統データが未取得の馬は一律40点（0.80倍）になります。'
      '「総合」タブの血統カードにある取得ボタンを押すと、'
      '過去の1〜3着馬の血統がまとめて取得され、この画面の精度が上がります。',
      _disclaimer,
    ];

    return FactorCandidateResult(
      factorKey: 'pedigree',
      factorLabel: label,
      trendSummary: summary,
      criteria: criteria,
      candidatesByMetric: _buildByMetric(list),
      emptyMessage: list.isEmpty ? '血統を判定できる出走馬データがありません。' : null,
      notes: notes,
      isRateBased: false,
      showMetricSelector: false,
    );
  }

  // ---------------------------------------------------------------------------
  // 4. ローテーション : 過去の好走馬と同じ路線から来た馬を抽出
  // ---------------------------------------------------------------------------

  static FactorCandidateResult selectByRotation(
    RaceAnalysisBundle bundle,
    List<PredictionHorseDetail> horses,
  ) {
    const label = 'ローテーション';
    const criteria = '過去の好走馬と同じ前走レースから来た馬を上位$maxCandidates頭まで選出';

    final summary = bundle.summary == null
        ? 'ローテーションの傾向データがありません。'
        : '王道ローテ: ${bundle.summary!.bestRotation}'
            ' / 好走馬の前走平均人気: ${bundle.summary!.bestPrevPop}';

    final List<FactorCandidate> list = [];
    for (final match in bundle.matchResults) {
      final horse = _findHorse(horses, match.horseId);
      if (horse == null || horse.isScratched || horse.horseNumber <= 0) continue;

      list.add(FactorCandidate(
        horseId: match.horseId,
        horseNumber: horse.horseNumber,
        gateNumber: horse.gateNumber,
        horseName: match.horseName,
        reason: '前走 ${match.prevRaceName}'
            '${match.rotDiagnosis.isEmpty ? "" : "  【${match.rotDiagnosis}】"}',
        lifts: _uniformLifts(_scoreToLift(match.rotationScore)),
      ));
    }

    final notes = <String>[
      'ローテーションは「どのレースを使ってここに来たか」を見るファクターです。'
      '過去にこのレースで1〜3着した馬の前走を数え、最も多かった路線を「王道」としています。'
      '同じ路線から来た馬は95点、王道ではないがG1・G2から来た格上馬は80点、'
      'それ以外は50点、前走が不明な馬は40点です。'
      'ステップレースが決まっているレースでは、'
      '王道ローテを通ってきた馬が繰り返し好走する傾向があります。'
      '逆に「格上」だけが高い馬は、格は足りるがこのレース向きの叩き方ではない可能性があります。',
      '【他タブとの違いにご注意ください】'
      'この点数は「1〜3着に入った馬」の前走だけを数えています。'
      '同じ路線から来て凡走した馬は数えていないため、'
      '「その路線から来れば good」ではなく「好走馬にはこの路線が多かった」という意味です。'
      'また点数が95・80・50・40の4段階しかないため、同点の馬が多く出ます。'
      '同点の場合は馬番順に並んでいるだけなので、順位の上下に意味はありません。',
      _disclaimer,
    ];

    return FactorCandidateResult(
      factorKey: 'rotation',
      factorLabel: label,
      trendSummary: summary,
      criteria: criteria,
      candidatesByMetric: _buildByMetric(list),
      emptyMessage: list.isEmpty ? 'ローテーションを判定できる出走馬データがありません。' : null,
      notes: notes,
      isRateBased: false,
      showMetricSelector: false,
    );
  }

  // ---------------------------------------------------------------------------
  // 5. 人気妙味 : 実力に対して人気が低い（妙味のある）馬を抽出
  // ---------------------------------------------------------------------------

  static FactorCandidateResult selectByPopularityValue(
    RaceAnalysisBundle bundle,
    List<PredictionHorseDetail> horses,
  ) {
    const label = '人気妙味';
    const criteria = '直近6走の実力に対して今回の人気が低い馬を上位$maxCandidates頭まで選出';

    final double avgPop = bundle.volatilityResult.averagePopularity;
    final String volatility = avgPop >= 4.5
        ? '波乱傾向（穴馬の激走が多い）'
        : (avgPop <= 3.0 ? '堅い傾向（人気馬が順当に走る）' : '標準');
    final summary =
        '過去の1〜3着馬の平均人気 ${avgPop.toStringAsFixed(1)}番人気 → $volatility';

    final List<FactorCandidate> list = [];
    for (final match in bundle.matchResults) {
      final horse = _findHorse(horses, match.horseId);
      if (horse == null || horse.isScratched || horse.horseNumber <= 0) continue;

      final String sign = match.valueIndex >= 0 ? '+' : '';
      list.add(FactorCandidate(
        horseId: match.horseId,
        horseNumber: horse.horseNumber,
        gateNumber: horse.gateNumber,
        horseName: match.horseName,
        reason: '${match.currentPopStr}  実力指数 $sign${match.valueIndex.toStringAsFixed(1)}'
            '  【${match.popDiagnosis}】',
        lifts: _uniformLifts(_scoreToLift(match.popularityScore)),
      ));
    }

    final notes = <String>[
      '人気妙味は「実力に対してオッズが安いか高いか」を見るファクターです。'
      '直近6走の着順と、その時の人気とのギャップから実力指数を出し、'
      '今回の人気と突き合わせています。'
      '実力があるのに人気がない馬ほど高い点数になります。'
      '【ここが「人気」タブと逆向きである点にご注意ください。】'
      '「人気」タブは過去に好走した人気帯にいる馬を高く評価するため上位人気が並びやすく、'
      'こちらは人気薄を高く評価するため下位人気が並びやすくなります。'
      '2つのタブで同じ馬が挙がったなら、実力も人気の裏付けもある堅実な馬。'
      'こちらだけに挙がった馬は、当たれば配当妙味の大きい穴候補という読み方ができます。',
      '過去の1〜3着馬の平均人気が4.5番人気以上のレースでは荒れやすいと判断し、'
      '6番人気以下の実力馬への加点を1.5倍にブーストしています。'
      '逆に3.0番人気以下の堅いレースでは加点を半分に抑えます。'
      'このレースは「$volatility」と判定されています。'
      'また、今回と同格以上のクラスで6着以下に大敗している馬は'
      '「クラスの壁」とみなして実力指数を大きく割り引いています。',
      '実力指数は着順そのものではなく「人気より上の着順に来たか」を積み上げた値です。'
      '数字が高い馬は市場の評価より走っている馬、'
      'マイナスの馬は人気ほど走れていない馬を意味します。'
      '上位人気なのに指数がマイナスの馬は「危険な人気馬」として下位に並びます。',
      _disclaimer,
    ];

    return FactorCandidateResult(
      factorKey: 'popularityValue',
      factorLabel: label,
      trendSummary: summary,
      criteria: criteria,
      candidatesByMetric: _buildByMetric(list),
      emptyMessage: list.isEmpty ? '人気妙味を判定できる出走馬データがありません。' : null,
      notes: notes,
      isRateBased: false,
      showMetricSelector: false,
    );
  }

  // ---------------------------------------------------------------------------
  // 一括選出
  // ---------------------------------------------------------------------------

  static Map<String, FactorCandidateResult> selectAll({
    required RaceAnalysisBundle bundle,
    required List<PredictionHorseDetail> horses,
  }) {
    return {
      'pace': selectByPace(bundle, horses),
      'trackCondition': selectByTrackCondition(bundle, horses),
      'pedigree': selectByPedigree(bundle, horses),
      'rotation': selectByRotation(bundle, horses),
      'popularityValue': selectByPopularityValue(bundle, horses),
    };
  }
}
