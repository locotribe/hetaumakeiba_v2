// lib/logic/analysis/factor_candidate_selector.dart

import 'package:hetaumakeiba_v2/models/race_data.dart';

// [追加] 指標キー（勝率 / 連対率 / 複勝率） (v.2026.9.5+26090506)
class FactorMetric {
  static const String win = 'win';
  static const String place = 'place';
  static const String show = 'show';

  static const List<String> all = [win, place, show];

  static const Map<String, String> labels = {
    win: '勝率',
    place: '連対率',
    show: '複勝率',
  };

  static const Map<String, String> shortLabels = {
    win: '勝',
    place: '連',
    show: '複',
  };
}

// [追加] 集計データ全体の平均値（リフト算出の基準線） (v.2026.9.5+26090506)
class FactorBaseline {
  /// 集計対象の延べ頭数
  final int totalCount;

  /// 指標別の全体平均率(%)
  final Map<String, double> rates;

  /// 基準線となるレース数の推定値（1レース1勝なので勝利数の合計＝レース数）
  final int raceCount;

  const FactorBaseline({
    required this.totalCount,
    required this.rates,
    required this.raceCount,
  });

  double rate(String metric) => rates[metric] ?? 0.0;

  /// 1レースあたりの平均出走頭数（脚質ゾーンの定員算出などに使用）
  double get avgFieldSize => raceCount > 0 ? totalCount / raceCount : 0.0;
}

// [追加] 1ファクターにおける該当馬1頭分のデータ (v.2026.9.5+26090506)
class FactorCandidate {
  final String horseId;
  final int horseNumber;
  final int gateNumber;
  final String horseName;

  /// 該当した区分の説明（例:「3枠」「先行（自身の先行率 62%）」）
  final String reason;

  /// 区分の度数表示（例:「12/51」）。率ベースでないファクターではnull。
  final String? recordText;

  /// 指標別の率(%)。率ベースでないファクター（配当など）ではnull。
  final Map<String, double>? rates;

  /// 指標別のリフト値（率 ÷ 全体平均）。率ベースでない場合は擬似リフトを格納する。
  final Map<String, double> lifts;

  FactorCandidate({
    required this.horseId,
    required this.horseNumber,
    required this.gateNumber,
    required this.horseName,
    required this.reason,
    required this.lifts,
    this.recordText,
    this.rates,
  });

  double liftFor(String metric) => lifts[metric] ?? 0.0;

  double? rateFor(String metric) => rates?[metric];
}

// [追加] 1ファクター分の該当馬選出結果 (v.2026.9.5+26090506)
class FactorCandidateResult {
  /// 内部識別子（'payout' / 'popularity' / 'frame' / 'legStyle' / 'horseWeight' / 'jockey' / 'trainer'）
  final String factorKey;

  /// 画面表示用のファクター名（'配当' など）
  final String factorLabel;

  /// 過去傾向の要約（カードのサブタイトルに表示）
  final String trendSummary;

  /// 選出基準の説明（カード下部に表示）
  final String criteria;

  /// 指標ごとの該当馬（最大 [FactorCandidateSelector.maxCandidates] 頭）
  final Map<String, List<FactorCandidate>> candidatesByMetric;

  /// 該当馬が0頭のときに表示する理由
  final String? emptyMessage;

  /// データの読み方に関する注意書き（脚質タブなどで使用）
  final List<String> notes;

  /// 率ベースのファクターかどうか。trueなら「◯◯倍」、falseなら「適合 ◯◯」と表示する。
  final bool isRateBased;

  /// リフト算出に使った基準線（カードに「全体平均」として表示）
  final FactorBaseline? baseline;

  // [追加] 3区分の切替ボタンに表示するラベルの上書き (v.2026.9.5+26090506)
  ///
  /// 内部のキーは常に win / place / show の3つだが、ファクターによって意味が変わる。
  /// - 通常（人気・枠番など）… null。勝率 / 連対率 / 複勝率 として扱う
  /// - ペース … スロー / ミドル / ハイ
  /// - 馬場状態 … 高 / 標準 / 低
  final Map<String, String>? metricLabels;

  // [追加] 切替ボタンを表示するかどうか。単一スコアのファクターでは非表示にする (v.2026.9.5+26090506)
  final bool showMetricSelector;

  // [追加] ファクター横断集計で使う「中庸」の区分 (v.2026.9.5+26090506)
  ///
  /// 通常のファクターは総合タブで選ばれた指標をそのまま使うが、
  /// ペース（スロー/ミドル/ハイ）や馬場（高/標準/低）は指標の意味が違うため、
  /// 横断集計では常に中庸のシナリオ（ミドル・標準）で数える。
  final String neutralMetric;

  FactorCandidateResult({
    required this.factorKey,
    required this.factorLabel,
    required this.trendSummary,
    required this.criteria,
    required this.candidatesByMetric,
    this.emptyMessage,
    this.notes = const [],
    this.isRateBased = true,
    this.baseline,
    this.metricLabels,
    this.showMetricSelector = true,
    this.neutralMetric = FactorMetric.show,
  });

  /// 横断集計で実際に参照する区分を返す。
  /// 独自ラベルを持つファクター（ペース・馬場）は常に中庸のシナリオを使う。
  String resolveMetric(String requested) =>
      metricLabels == null ? requested : neutralMetric;

  /// 指定した区分の表示名を返す
  String labelFor(String metric) =>
      metricLabels?[metric] ?? FactorMetric.labels[metric] ?? metric;

  List<FactorCandidate> candidatesFor(String metric) =>
      candidatesByMetric[metric] ?? const [];

  /// いずれかの指標で1頭でも選出されているか
  bool get hasAnyCandidate =>
      candidatesByMetric.values.any((list) => list.isNotEmpty);
}

// [追加] ファクター横断で「どの馬が何個のファクターに該当したか」を保持する (v.2026.9.5+26090506)
class FactorHitSummary {
  final String horseId;
  final int horseNumber;
  final int gateNumber;
  final String horseName;

  /// factorKey -> そのファクター内での該当順位（1が最上位）
  final Map<String, int> factorRanks;

  /// factorKey -> そのファクターでのリフト値
  final Map<String, double> factorLifts;

  FactorHitSummary({
    required this.horseId,
    required this.horseNumber,
    required this.gateNumber,
    required this.horseName,
    required this.factorRanks,
    required this.factorLifts,
  });

  int get hitCount => factorRanks.length;

  /// 該当したファクターのリフト合計。同該当数の並べ替えに使用する。
  double get liftTotal {
    double sum = 0;
    for (final lift in factorLifts.values) {
      sum += lift;
    }
    return sum;
  }
}

// [追加] 過去傾向の集計データと今回の出走メンバーを突き合わせ、該当馬を選出する (v.2026.9.5+26090506)
///
/// 予想の正解を出すためのものではなく、「このファクターならこの馬」という
/// 候補の洗い出しを行い、どのファクターを重視するかの判断材料を提供する。
///
/// 並べ替えは生の率ではなく「リフト値（率 ÷ そのファクター全体の平均率）」で行う。
/// 生の複勝率で並べると、母数の大きい区分（例: 差し）が平均並みでも上位に見えてしまうため。
class FactorCandidateSelector {
  /// 1ファクター・1指標あたりの選出上限頭数
  static const int maxCandidates = 5;

  /// 表示順を固定するためのファクターキー一覧
  static const List<String> factorKeys = [
    'payout',
    'popularity',
    'frame',
    'legStyle',
    'horseWeight',
    'jockey',
    'trainer',
  ];

  /// ファクターキーと画面表示名の対応
  static const Map<String, String> factorLabels = {
    'payout': '配当',
    'popularity': '人気',
    'frame': '枠番',
    'legStyle': '脚質',
    'horseWeight': '馬体重',
    'jockey': '騎手',
    'trainer': '調教師',
  };

  // ---------------------------------------------------------------------------
  // 内部ヘルパー
  // ---------------------------------------------------------------------------

  static List<PredictionHorseDetail> _activeHorses(
      List<PredictionHorseDetail> horses) {
    return horses.where((h) => !h.isScratched && h.horseNumber > 0).toList();
  }

  static int _statInt(Map<String, dynamic>? data, String key) {
    if (data == null) return 0;
    final value = data[key];
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  /// {total, win, place, show} から指標別の率(%)を返す
  static Map<String, double> _ratesOf(Map<String, dynamic> data) {
    final total = _statInt(data, 'total');
    if (total <= 0) {
      return {FactorMetric.win: 0.0, FactorMetric.place: 0.0, FactorMetric.show: 0.0};
    }
    return {
      FactorMetric.win: _statInt(data, 'win') / total * 100.0,
      FactorMetric.place: _statInt(data, 'place') / total * 100.0,
      FactorMetric.show: _statInt(data, 'show') / total * 100.0,
    };
  }

  /// 集計マップ全体を合算して基準線（全体平均）を算出する
  static FactorBaseline _baselineOf(Map<String, dynamic> stats) {
    int total = 0, win = 0, place = 0, show = 0;
    for (final entry in stats.entries) {
      if (entry.value is! Map) continue;
      final map = Map<String, dynamic>.from(entry.value as Map);
      total += _statInt(map, 'total');
      win += _statInt(map, 'win');
      place += _statInt(map, 'place');
      show += _statInt(map, 'show');
    }
    if (total <= 0) {
      return const FactorBaseline(
        totalCount: 0,
        rates: {FactorMetric.win: 0.0, FactorMetric.place: 0.0, FactorMetric.show: 0.0},
        raceCount: 0,
      );
    }
    return FactorBaseline(
      totalCount: total,
      rates: {
        FactorMetric.win: win / total * 100.0,
        FactorMetric.place: place / total * 100.0,
        FactorMetric.show: show / total * 100.0,
      },
      // 1レースにつき1着は1頭なので、勝利数の合計＝対象レース数とみなせる
      raceCount: win,
    );
  }

  /// 率とベースラインからリフト値を算出する
  static Map<String, double> _liftsOf(
      Map<String, double> rates, FactorBaseline baseline) {
    final Map<String, double> lifts = {};
    for (final metric in FactorMetric.all) {
      final base = baseline.rate(metric);
      final rate = rates[metric] ?? 0.0;
      lifts[metric] = base > 0 ? rate / base : 0.0;
    }
    return lifts;
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

  /// 傾向要約用に、指標別リフトの高い区分を並べた文字列を作る
  static String _topCategoriesText(
    Map<String, dynamic> stats,
    FactorBaseline baseline, {
    required String suffix,
    String metric = FactorMetric.show,
    int take = 3,
    int minTotal = 1,
  }) {
    final List<MapEntry<String, double>> entries = [];
    for (final entry in stats.entries) {
      if (entry.value is! Map) continue;
      final map = Map<String, dynamic>.from(entry.value as Map);
      if (_statInt(map, 'total') < minTotal) continue;
      final rates = _ratesOf(map);
      entries.add(MapEntry(entry.key, rates[metric] ?? 0.0));
    }
    entries.sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty) return 'データなし';

    final base = baseline.rate(metric);
    final picked = entries.take(take).map((e) {
      final liftText =
          base > 0 ? '(${(e.value / base).toStringAsFixed(1)}倍)' : '';
      return '${e.key}$suffix ${e.value.toStringAsFixed(0)}%$liftText';
    });
    return picked.join(' / ');
  }

  /// 馬体重文字列から体重(kg)を取り出す。'480' と '480(+4)' の双方に対応。
  static int? _parseWeight(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final match = RegExp(r'(\d{3})').firstMatch(raw);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  /// 馬体重文字列から増減(kg)を取り出す。括弧表記がない場合はnull。
  static int? _parseWeightChange(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final match = RegExp(r'\(([\+\-]?\d+)\)').firstMatch(raw);
    if (match == null) return null;
    return int.tryParse(match.group(1)!.replaceAll('+', ''));
  }

  /// 増減(kg)を statistics_service.dart と同一区分のカテゴリ名へ変換する。
  static String _weightChangeCategory(int change) {
    if (change <= -10) return '-10kg以下';
    if (change <= -4) return '-4~-8kg';
    if (change <= 2) return '-2~+2kg';
    if (change <= 8) return '+4~+8kg';
    return '+10kg以上';
  }

  static const List<String> _commonNotes = [
    'ここに出ている馬は「過去データの傾向に当てはまる」というだけで、'
        '今回の結果を予想したものではありません。'
        'あくまで判断材料のひとつとしてご覧ください。',
  ];

  // ---------------------------------------------------------------------------
  // 1. 配当 : 過去の平均単勝配当に近いオッズ帯の馬を抽出
  // ---------------------------------------------------------------------------

  static FactorCandidateResult selectByPayout(
    Map<String, dynamic> payoutStats,
    List<PredictionHorseDetail> horses,
  ) {
    const label = '配当';
    const criteria = '過去の平均単勝配当から想定される決着オッズに近い馬を上位$maxCandidates頭まで選出';

    final winData = payoutStats['単勝'];
    if (winData is! Map) {
      return FactorCandidateResult(
        factorKey: 'payout',
        factorLabel: label,
        trendSummary: '単勝配当の集計データがありません。',
        criteria: criteria,
        candidatesByMetric: const {},
        emptyMessage: '単勝配当の集計データがないため選出できません。',
        isRateBased: false,
        showMetricSelector: false,
      );
    }

    final map = Map<String, dynamic>.from(winData);
    final int average = _statInt(map, 'average');
    final int max = _statInt(map, 'max');
    final int min = _statInt(map, 'min');
    final double targetOdds = average / 100.0;

    final String volatility = average >= 2000
        ? '波乱傾向'
        : (average >= 800 ? 'やや波乱' : '堅め');

    final summary =
        '平均単勝配当 $average円 (約${targetOdds.toStringAsFixed(1)}倍) / 最高 $max円 · 最低 $min円 → $volatility';

    final List<String> notes = [
      '配当は「勝ち馬のオッズがどのあたりに落ち着いたか」を見るファクターです。'
          '過去10レース前後の平均単勝配当が約${targetOdds.toStringAsFixed(1)}倍なので、'
          'そこに近いオッズの馬を並べています。'
          'これは「このくらいの人気の馬が勝ってきた」という意味であって、'
          'オッズが近いこと自体が強さを示すわけではありません。'
          '$volatilityのレースだという前提を頭に置いたうえで、'
          '他のタブの候補と重なる馬を優先するのが分かりやすい使い方です。',
      ...(_commonNotes),
    ];

    if (average <= 0) {
      return FactorCandidateResult(
        factorKey: 'payout',
        factorLabel: label,
        trendSummary: summary,
        criteria: criteria,
        candidatesByMetric: const {},
        emptyMessage: '平均単勝配当が算出できないため選出できません。',
        notes: notes,
        isRateBased: false,
        showMetricSelector: false,
      );
    }

    final List<FactorCandidate> list = [];
    for (final horse in _activeHorses(horses)) {
      final odds = horse.odds;
      if (odds == null || odds <= 0) continue;
      final diff = (odds - targetOdds).abs();
      // 想定オッズちょうどで2.0、想定オッズと同じ幅だけ離れると1.0になる擬似リフト
      final pseudoLift = 2.0 / (1.0 + diff / targetOdds);
      list.add(FactorCandidate(
        horseId: horse.horseId,
        horseNumber: horse.horseNumber,
        gateNumber: horse.gateNumber,
        horseName: horse.horseName,
        reason:
            '単勝 ${odds.toStringAsFixed(1)}倍 / 想定 ${targetOdds.toStringAsFixed(1)}倍との差 ${diff.toStringAsFixed(1)}',
        lifts: {
          FactorMetric.win: pseudoLift,
          FactorMetric.place: pseudoLift,
          FactorMetric.show: pseudoLift,
        },
      ));
    }

    return FactorCandidateResult(
      factorKey: 'payout',
      factorLabel: label,
      trendSummary: summary,
      criteria: criteria,
      candidatesByMetric: _buildByMetric(list),
      emptyMessage: list.isEmpty ? 'オッズが未確定のため選出できません。' : null,
      notes: notes,
      isRateBased: false,
      showMetricSelector: false,
    );
  }

  // ---------------------------------------------------------------------------
  // 2. 人気 : 過去に好走した人気帯に今回入っている馬を抽出
  // ---------------------------------------------------------------------------

  static FactorCandidateResult selectByPopularity(
    Map<String, dynamic> popularityStats,
    List<PredictionHorseDetail> horses,
  ) {
    const label = '人気';
    const criteria = '過去の人気別成績が全体平均を上回る人気帯に今回該当する馬を上位$maxCandidates頭まで選出';

    final baseline = _baselineOf(popularityStats);
    final summary = popularityStats.isEmpty
        ? '人気別成績の集計データがありません。'
        : '好走した人気帯: ${_topCategoriesText(popularityStats, baseline, suffix: '番人気')}';

    final List<FactorCandidate> list = [];
    for (final horse in _activeHorses(horses)) {
      final pop = horse.popularity;
      if (pop == null || pop <= 0) continue;
      final data = popularityStats['$pop'];
      if (data is! Map) continue;
      final map = Map<String, dynamic>.from(data);
      if (_statInt(map, 'total') <= 0) continue;
      final rates = _ratesOf(map);
      list.add(FactorCandidate(
        horseId: horse.horseId,
        horseNumber: horse.horseNumber,
        gateNumber: horse.gateNumber,
        horseName: horse.horseName,
        reason: '$pop番人気',
        recordText: '${_statInt(map, 'show')}/${_statInt(map, 'total')}',
        rates: rates,
        lifts: _liftsOf(rates, baseline),
      ));
    }

    final notes = <String>[
      '人気は「オッズがその馬をどう評価しているか」を示すファクターです。'
          'ここでは過去の同レースで、その人気帯の馬が実際にどれだけ走ったかを見ています。'
          'リフトが1.0倍を超えていれば「その人気帯は過去このレースで期待以上に走っていた」、'
          '1.0倍を下回っていれば「人気ほどには走れていなかった」と読めます。'
          '上位人気の馬は元々勝ちやすいので数字も高く出ますが、'
          'リフトで見ると人気薄の帯のほうが妙味がある場合もあります。',
      ..._commonNotes,
    ];

    return FactorCandidateResult(
      factorKey: 'popularity',
      factorLabel: label,
      trendSummary: summary,
      criteria: criteria,
      candidatesByMetric: _buildByMetric(list),
      emptyMessage: list.isEmpty ? '人気が未確定、または該当する人気帯に好走実績がありません。' : null,
      notes: notes,
      baseline: baseline,
    );
  }

  // ---------------------------------------------------------------------------
  // 3. 枠番 : 過去に好走した枠に今回入っている馬を抽出
  // ---------------------------------------------------------------------------

  static FactorCandidateResult selectByFrame(
    Map<String, dynamic> frameStats,
    List<PredictionHorseDetail> horses,
  ) {
    const label = '枠番';
    const criteria = '過去の枠番別成績が全体平均を上回る枠に今回入った馬を上位$maxCandidates頭まで選出';

    final baseline = _baselineOf(frameStats);
    final summary = frameStats.isEmpty
        ? '枠番別成績の集計データがありません。'
        : '好走した枠: ${_topCategoriesText(frameStats, baseline, suffix: '枠')}';

    final List<FactorCandidate> list = [];
    for (final horse in _activeHorses(horses)) {
      final gate = horse.gateNumber;
      if (gate <= 0) continue;
      final data = frameStats['$gate'];
      if (data is! Map) continue;
      final map = Map<String, dynamic>.from(data);
      if (_statInt(map, 'total') <= 0) continue;
      final rates = _ratesOf(map);
      list.add(FactorCandidate(
        horseId: horse.horseId,
        horseNumber: horse.horseNumber,
        gateNumber: gate,
        horseName: horse.horseName,
        reason: '$gate枠',
        recordText: '${_statInt(map, 'show')}/${_statInt(map, 'total')}',
        rates: rates,
        lifts: _liftsOf(rates, baseline),
      ));
    }

    final notes = <String>[
      '枠番は「内・外どちらが有利だったか」を見るファクターです。'
          'コース形状によって有利不利がはっきり出る場合と、ほとんど差がない場合があります。'
          'リフトが1.3倍を超える枠が複数あるなら枠の影響が大きいレース、'
          'どの枠も1.0倍前後に収まっているなら枠はあまり気にしなくてよいレース、と判断できます。'
          '枠順が確定していない段階では、この欄には何も表示されません。',
      ..._commonNotes,
    ];

    return FactorCandidateResult(
      factorKey: 'frame',
      factorLabel: label,
      trendSummary: summary,
      criteria: criteria,
      candidatesByMetric: _buildByMetric(list),
      emptyMessage: list.isEmpty ? '枠順が未確定、または該当する枠に好走実績がありません。' : null,
      notes: notes,
      baseline: baseline,
    );
  }

  // ---------------------------------------------------------------------------
  // 4. 脚質 : 過去に好走した脚質を主戦法とする馬を抽出
  // ---------------------------------------------------------------------------

  static FactorCandidateResult selectByLegStyle(
    Map<String, dynamic> legStyleStats,
    List<PredictionHorseDetail> horses,
  ) {
    const label = '脚質';
    const criteria = '過去の脚質別成績が全体平均を上回る脚質を主戦法とする馬を上位$maxCandidates頭まで選出';

    final baseline = _baselineOf(legStyleStats);
    final summary = legStyleStats.isEmpty
        ? '脚質別成績の集計データがありません。'
        : '好走した脚質: ${_topCategoriesText(legStyleStats, baseline, suffix: '')}';

    final List<FactorCandidate> list = [];
    bool hasProfile = false;
    for (final horse in _activeHorses(horses)) {
      final profile = horse.legStyleProfile;
      if (profile == null) continue;
      final style = profile.primaryStyle;
      if (style.isEmpty) continue;
      hasProfile = true;
      final data = legStyleStats[style];
      if (data is! Map) continue;
      final map = Map<String, dynamic>.from(data);
      if (_statInt(map, 'total') <= 0) continue;
      final rates = _ratesOf(map);

      // styleDistribution は 0.0〜1.0 の比率で保持されているため100倍して%表示にする
      final ratio = profile.styleDistribution[style];
      final ratioText = ratio == null
          ? ''
          : '（自身の$style率 ${(ratio * 100).toStringAsFixed(0)}%）';

      list.add(FactorCandidate(
        horseId: horse.horseId,
        horseNumber: horse.horseNumber,
        gateNumber: horse.gateNumber,
        horseName: horse.horseName,
        reason: '$style$ratioText',
        recordText: '${_statInt(map, 'show')}/${_statInt(map, 'total')}',
        rates: rates,
        lifts: _liftsOf(rates, baseline),
      ));
    }

    final candidatesByMetric = _buildByMetric(list);

    // 選出された馬が属する脚質について、データの読み方の注意書きを生成する
    final Set<String> shownStyles = {};
    for (final metricList in candidatesByMetric.values) {
      for (final candidate in metricList) {
        final head = candidate.reason.split('（').first;
        if (head.isNotEmpty) shownStyles.add(head);
      }
    }

    final notes = LegStyleNoteBuilder.build(
      legStyleStats: legStyleStats,
      baseline: baseline,
      focusStyles: shownStyles,
    );

    return FactorCandidateResult(
      factorKey: 'legStyle',
      factorLabel: label,
      trendSummary: summary,
      criteria: criteria,
      candidatesByMetric: candidatesByMetric,
      emptyMessage: list.isEmpty
          ? (hasProfile
              ? '該当する脚質に好走実績がありません。'
              : '出走馬の脚質データが未取得のため選出できません。')
          : null,
      notes: notes,
      baseline: baseline,
    );
  }

  // ---------------------------------------------------------------------------
  // 5. 馬体重 : 勝ち馬の平均体重に近く、かつ好走増減帯に入る馬を抽出
  // ---------------------------------------------------------------------------

  static FactorCandidateResult selectByHorseWeight(
    Map<String, dynamic> horseWeightChangeStats,
    double avgWinningHorseWeight,
    List<PredictionHorseDetail> horses,
  ) {
    const label = '馬体重';
    const criteria =
        '勝ち馬の平均馬体重に近く、かつ好走している増減帯に入る馬を上位$maxCandidates頭まで選出';

    final baseline = _baselineOf(horseWeightChangeStats);

    final String weightPart = avgWinningHorseWeight > 0
        ? '勝ち馬の平均馬体重 ${avgWinningHorseWeight.toStringAsFixed(1)}kg'
        : '勝ち馬の平均馬体重は集計なし';
    final String changePart = horseWeightChangeStats.isEmpty
        ? ''
        : ' / 好走した増減帯: ${_topCategoriesText(horseWeightChangeStats, baseline, suffix: '')}';
    final summary = '$weightPart$changePart';

    final List<FactorCandidate> list = [];
    int announcedCount = 0;
    int previousCount = 0;

    for (final horse in _activeHorses(horses)) {
      // [追加] 当日発表前は前走馬体重を使う（weight_factor.dart と同じ挙動） (v.2026.9.5+26090506)
      int? weight = _parseWeight(horse.horseWeight);
      bool isCurrent = weight != null;
      if (weight == null) {
        weight = _parseWeight(horse.previousHorseWeight);
      }
      if (weight == null) continue;

      if (isCurrent) {
        announcedCount++;
      } else {
        previousCount++;
      }

      // 体重の近さを擬似リフト化（平均ちょうどで2.0、25kg差で1.0）
      double proximityLift = 1.0;
      String weightText = isCurrent ? '${weight}kg（当日発表）' : '${weight}kg（前走）';
      if (avgWinningHorseWeight > 0) {
        final diff = weight - avgWinningHorseWeight;
        final absDiff = diff.abs();
        proximityLift = ((100.0 - absDiff * 2.0).clamp(0.0, 100.0)) / 50.0;
        final sign = diff >= 0 ? '+' : '-';
        final suffix = isCurrent ? '（当日発表）' : '（前走）';
        weightText =
            '${weight}kg$suffix 平均比 $sign${absDiff.toStringAsFixed(0)}kg';
      }

      // 当日発表済みのときのみ増減帯を評価する（前走体重では今回の増減が不明なため）
      Map<String, double>? rates;
      Map<String, double> lifts = {
        for (final metric in FactorMetric.all) metric: proximityLift
      };
      String? recordText;
      String changeText = '';

      if (isCurrent) {
        int? change = _parseWeightChange(horse.horseWeight);
        if (change == null) {
          final prev = _parseWeight(horse.previousHorseWeight);
          if (prev != null) change = weight - prev;
        }
        if (change != null) {
          final category = _weightChangeCategory(change);
          final data = horseWeightChangeStats[category];
          if (data is Map) {
            final map = Map<String, dynamic>.from(data);
            if (_statInt(map, 'total') > 0) {
              rates = _ratesOf(map);
              final changeLifts = _liftsOf(rates, baseline);
              lifts = {
                for (final metric in FactorMetric.all)
                  metric: (proximityLift + (changeLifts[metric] ?? 0.0)) / 2.0
              };
              recordText =
                  '${_statInt(map, 'show')}/${_statInt(map, 'total')}';
              final sign = change >= 0 ? '+' : '';
              changeText = ' / 増減 $sign${change}kg（$category帯）';
            }
          }
        }
      }

      list.add(FactorCandidate(
        horseId: horse.horseId,
        horseNumber: horse.horseNumber,
        gateNumber: horse.gateNumber,
        horseName: horse.horseName,
        reason: '$weightText$changeText',
        recordText: recordText,
        rates: rates,
        lifts: lifts,
      ));
    }

    final notes = <String>[];
    if (previousCount > 0 && announcedCount == 0) {
      notes.add(
        '当日の馬体重はまだ発表されていないため、全頭とも前走の馬体重で計算しています。'
            '馬体重の発表はレースの30分前ごろになることが多く、'
            '発表後にこの画面を開き直すと当日の実測値と増減帯を使った計算に自動で切り替わります。'
            '現時点の並び順は「勝ち馬の平均体重に近い馬」を示しているだけで、'
            '当日の増減（絞れているか、太めか）は反映されていない点にご注意ください。',
      );
    } else if (previousCount > 0) {
      notes.add(
        '当日の馬体重が発表済みの馬は実測値と増減帯の成績を使い、'
            '未発表の馬（$previousCount頭）は前走の馬体重で暫定計算しています。'
            '「（前走）」と表示されている馬は増減が未反映のため、'
            '発表後に順位が入れ替わる可能性があります。',
      );
    }
    notes.add(
      '馬体重は「勝ち馬の平均体重にどれだけ近いか」と「当日の増減がどの帯に入るか」の'
          '2つを組み合わせて評価しています。'
          '体重そのものは馬格の目安で、大型馬が有利なコースと小回りで軽い馬が動けるコースがあります。'
          '増減は仕上がりの目安で、大幅増減が続く馬は状態が読みにくいと考えられます。'
          'ただし適正体重は馬ごとに違うため、平均から離れているだけで消すのは早計です。',
    );
    notes.addAll(_commonNotes);

    return FactorCandidateResult(
      factorKey: 'horseWeight',
      factorLabel: label,
      trendSummary: summary,
      criteria: criteria,
      candidatesByMetric: _buildByMetric(list),
      emptyMessage:
          list.isEmpty ? '当日・前走とも馬体重が取得できないため選出できません。' : null,
      notes: notes,
      baseline: baseline,
    );
  }

  // ---------------------------------------------------------------------------
  // 6. 騎手 : 過去にこのレースで好成績の騎手が騎乗する馬を抽出
  // ---------------------------------------------------------------------------

  static FactorCandidateResult selectByJockey(
    Map<String, dynamic> jockeyStats,
    List<PredictionHorseDetail> horses,
  ) {
    const label = '騎手';
    const criteria = '過去にこのレースで全体平均を上回る成績の騎手が騎乗する馬を上位$maxCandidates頭まで選出';

    final baseline = _baselineOf(jockeyStats);
    final summary = jockeyStats.isEmpty
        ? '騎手別成績の集計データがありません。'
        : '好成績の騎手: ${_topCategoriesText(jockeyStats, baseline, suffix: '', minTotal: 2)}';

    final List<FactorCandidate> list = [];
    for (final horse in _activeHorses(horses)) {
      final matched = _findByName(jockeyStats, horse.jockey);
      if (matched == null) continue;
      final rates = _ratesOf(matched);
      list.add(FactorCandidate(
        horseId: horse.horseId,
        horseNumber: horse.horseNumber,
        gateNumber: horse.gateNumber,
        horseName: horse.horseName,
        reason: horse.jockey,
        recordText: '${_statInt(matched, 'show')}/${_statInt(matched, 'total')}',
        rates: rates,
        lifts: _liftsOf(rates, baseline),
      ));
    }

    final notes = <String>[
      '騎手は「このレース・このコースを知っているか」を見るファクターです。'
          '騎乗回数が1〜2回しかない騎手は数字が極端に振れやすく、'
          '複勝率100%でも実質的な裏付けは弱いので、'
          '各候補の右側にある度数（何回中何回か）も必ず確認してください。'
          'また、強い馬に乗る機会が多い騎手は自然に成績が良くなるため、'
          '騎手の数字だけで馬の力を判断しないほうが安全です。',
      ..._commonNotes,
    ];

    return FactorCandidateResult(
      factorKey: 'jockey',
      factorLabel: label,
      trendSummary: summary,
      criteria: criteria,
      candidatesByMetric: _buildByMetric(list),
      emptyMessage: list.isEmpty ? '過去に好走実績のある騎手が今回は騎乗していません。' : null,
      notes: notes,
      baseline: baseline,
    );
  }

  // ---------------------------------------------------------------------------
  // 7. 調教師 : 過去にこのレースで好成績の厩舎の馬を抽出
  // ---------------------------------------------------------------------------

  static FactorCandidateResult selectByTrainer(
    Map<String, dynamic> trainerStats,
    List<PredictionHorseDetail> horses,
  ) {
    const label = '調教師';
    const criteria = '過去にこのレースで全体平均を上回る成績の厩舎に所属する馬を上位$maxCandidates頭まで選出';

    final baseline = _baselineOf(trainerStats);
    final summary = trainerStats.isEmpty
        ? '調教師別成績の集計データがありません。'
        : '好成績の厩舎: ${_topCategoriesText(trainerStats, baseline, suffix: '', minTotal: 2)}';

    final List<FactorCandidate> list = [];
    for (final horse in _activeHorses(horses)) {
      final matched = _findByName(trainerStats, horse.trainerName);
      if (matched == null) continue;
      final rates = _ratesOf(matched);
      list.add(FactorCandidate(
        horseId: horse.horseId,
        horseNumber: horse.horseNumber,
        gateNumber: horse.gateNumber,
        horseName: horse.horseName,
        reason: horse.trainerName,
        recordText: '${_statInt(matched, 'show')}/${_statInt(matched, 'total')}',
        rates: rates,
        lifts: _liftsOf(rates, baseline),
      ));
    }

    final notes = <String>[
      '調教師は「この時期・このレースに向けて仕上げるのが上手いか」を見るファクターです。'
          '毎年のように同じレースに管理馬を送り込んでくる厩舎は、'
          'コース適性や仕上げのノウハウを持っている可能性があります。'
          'ただし騎手と同じく出走回数が少ないと数字が振れやすいので、'
          '度数（何回中何回か）を合わせて確認してください。',
      ..._commonNotes,
    ];

    return FactorCandidateResult(
      factorKey: 'trainer',
      factorLabel: label,
      trendSummary: summary,
      criteria: criteria,
      candidatesByMetric: _buildByMetric(list),
      emptyMessage: list.isEmpty ? '過去に好走実績のある厩舎の馬が今回は出走していません。' : null,
      notes: notes,
      baseline: baseline,
    );
  }

  /// 空白を無視して名前一致する集計エントリを探す
  static Map<String, dynamic>? _findByName(
      Map<String, dynamic> stats, String rawName) {
    final name = rawName.replaceAll(RegExp(r'\s+'), '');
    if (name.isEmpty) return null;
    for (final entry in stats.entries) {
      if (entry.value is! Map) continue;
      if (entry.key.replaceAll(RegExp(r'\s+'), '') != name) continue;
      final map = Map<String, dynamic>.from(entry.value as Map);
      if (_statInt(map, 'total') <= 0) return null;
      return map;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // 全ファクターの一括選出とファクター横断集計
  // ---------------------------------------------------------------------------

  /// 統計JSONをデコードしたMapと今回の出走メンバーから、全ファクターの該当馬を選出する。
  static Map<String, FactorCandidateResult> selectAll({
    required Map<String, dynamic> data,
    required List<PredictionHorseDetail> horses,
  }) {
    Map<String, dynamic> pick(String key) {
      final value = data[key];
      if (value is Map) return Map<String, dynamic>.from(value);
      return <String, dynamic>{};
    }

    final double avgWeight =
        (data['avgWinningHorseWeight'] as num?)?.toDouble() ?? 0.0;

    return {
      'payout': selectByPayout(pick('payoutStats'), horses),
      'popularity': selectByPopularity(pick('popularityStats'), horses),
      'frame': selectByFrame(pick('frameStats'), horses),
      'legStyle': selectByLegStyle(pick('legStyleStats'), horses),
      'horseWeight': selectByHorseWeight(
          pick('horseWeightChangeStats'), avgWeight, horses),
      'jockey': selectByJockey(pick('jockeyStats'), horses),
      'trainer': selectByTrainer(pick('trainerStats'), horses),
    };
  }

  /// 各ファクターの選出結果を横断集計し、該当数の多い順に並べて返す。
  static List<FactorHitSummary> aggregate(
    Map<String, FactorCandidateResult> results, {
    String metric = FactorMetric.show,
    List<String>? factorOrder,
  }) {
    final Map<String, FactorHitSummary> summaryMap = {};

    for (final key in (factorOrder ?? factorKeys)) {
      final result = results[key];
      if (result == null) continue;
      final candidates = result.candidatesFor(result.resolveMetric(metric));
      for (int i = 0; i < candidates.length; i++) {
        final candidate = candidates[i];
        final summary = summaryMap.putIfAbsent(
          candidate.horseId,
          () => FactorHitSummary(
            horseId: candidate.horseId,
            horseNumber: candidate.horseNumber,
            gateNumber: candidate.gateNumber,
            horseName: candidate.horseName,
            factorRanks: {},
            factorLifts: {},
          ),
        );
        summary.factorRanks[key] = i + 1;
        summary.factorLifts[key] = candidate.liftFor(result.resolveMetric(metric));
      }
    }

    final list = summaryMap.values.toList()
      ..sort((a, b) {
        final cmp = b.hitCount.compareTo(a.hitCount);
        if (cmp != 0) return cmp;
        final liftCmp = b.liftTotal.compareTo(a.liftTotal);
        if (liftCmp != 0) return liftCmp;
        return a.horseNumber.compareTo(b.horseNumber);
      });

    return list;
  }
}

// [追加] 脚質データの読み方を説明する注意書きを、実データに合わせて選択・生成する (v.2026.9.5+26090506)
///
/// 脚質は「最終コーナーでの位置率」で機械的に区分されるため、
/// 母数（頭数）はレースの傾向ではなく区分の定員に近い。
/// この事実を知らないと「1着が最も多い脚質＝最も勝率が高い脚質」と誤読してしまうため、
/// 脚質ごとにリフト水準に応じた注意書きを出し分ける。
class LegStyleNoteBuilder {
  static const List<String> styleOrder = ['逃げ', '先行', '差し', '追込'];

  /// リフト水準の判定閾値
  static const double _outstanding = 2.0;
  static const double _favorable = 1.3;
  static const double _neutral = 0.85;

  static int _statInt(Map<String, dynamic>? data, String key) {
    if (data == null) return 0;
    final value = data[key];
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  static String _levelOf(double lift) {
    if (lift >= _outstanding) return 'outstanding';
    if (lift >= _favorable) return 'favorable';
    if (lift >= _neutral) return 'neutral';
    return 'weak';
  }

  static String _levelLabel(String level) {
    switch (level) {
      case 'outstanding':
        return '突出して有利';
      case 'favorable':
        return 'やや有利';
      case 'neutral':
        return '平均並み';
      default:
        return '平均を下回る';
    }
  }

  /// 脚質タブに表示する注意書きの一覧を生成する。
  ///
  /// [focusStyles] に含まれる脚質（＝実際に候補として選出された脚質）についてのみ
  /// 個別の注意書きを出し、それ以外は共通の読み方説明のみとする。
  static List<String> build({
    required Map<String, dynamic> legStyleStats,
    required FactorBaseline baseline,
    required Set<String> focusStyles,
  }) {
    if (legStyleStats.isEmpty || baseline.raceCount <= 0) {
      return [
        '脚質別の集計データがまだ揃っていないため、読み方の説明を表示できません。'
            '「分析対象」タブから過去レースを取得すると表示されます。',
      ];
    }

    final int raceCount = baseline.raceCount;

    // 各脚質の1レースあたり該当頭数（＝区分の定員）を算出する
    final Map<String, double> perRace = {};
    final Map<String, double> winRates = {};
    final Map<String, double> winLifts = {};
    final Map<String, int> totals = {};

    for (final style in styleOrder) {
      final data = legStyleStats[style];
      if (data is! Map) continue;
      final map = Map<String, dynamic>.from(data);
      final total = _statInt(map, 'total');
      if (total <= 0) continue;
      totals[style] = total;
      perRace[style] = total / raceCount;
      final rate = _statInt(map, 'win') / total * 100.0;
      winRates[style] = rate;
      final base = baseline.rate(FactorMetric.win);
      winLifts[style] = base > 0 ? rate / base : 0.0;
    }

    final notes = <String>[];

    // 1. 母数の意味に関する共通注記
    final distribution = styleOrder
        .where((s) => perRace.containsKey(s))
        .map((s) => '$s 約${perRace[s]!.toStringAsFixed(1)}頭')
        .join(' / ');

    notes.add(
      '【この表の読み方】脚質は「最終コーナーで前から何番目にいたか」を出走頭数で割った位置率で'
      '機械的に区分しています（上位15%までが逃げ、40%までが先行、80%までが差し、それ以降が追込）。'
      'そのため各脚質の頭数（母数）は区分の定員のようなもので、'
      '「このレースは先行馬が多い」という意味ではありません。'
      '$raceCount レース分の集計で、1レースあたりの該当頭数は $distribution です。'
      'なお上の入線分布グラフとこの表では脚質の判定方法が異なるため、頭数が一致しないことがあります。',
    );

    // 2. 勝ち馬の数と勝率が食い違う理由
    notes.add(
      '【勝ち馬の数と勝率が食い違う理由】1着が最も多い脚質と、勝率が最も高い脚質は一致しないことがあります。'
      'たとえばある脚質から6勝出ていても、その脚質に1レース平均5頭が該当するなら、1頭あたりの勝率は下がります。'
      '逆に該当が1レース2頭しかない脚質は、勝ち星が少なくても勝率は高く出ます。'
      '「どの脚質から勝ち馬が出やすいか」を知りたいなら頭数（グラフ）を、'
      '「1頭選ぶならどの脚質が効率的か」を知りたいなら勝率とリフトを見てください。'
      '下の候補はリフト（全体平均の何倍か）の高い順に並んでいます。',
    );

    // 3. 実際に候補が出ている脚質について、リフト水準に応じた個別の注意書き
    for (final style in styleOrder) {
      if (!focusStyles.contains(style)) continue;
      if (!winLifts.containsKey(style)) continue;

      final lift = winLifts[style]!;
      final level = _levelOf(lift);
      final body = _bodyFor(style, level, perRace[style] ?? 0.0);

      notes.add(
        '【$style】${_levelLabel(level)}'
        '（勝率 ${winRates[style]!.toStringAsFixed(1)}% ／ '
        '全体平均 ${baseline.rate(FactorMetric.win).toStringAsFixed(1)}% の ${lift.toStringAsFixed(2)}倍 ／ '
        '1レース平均 ${(perRace[style] ?? 0.0).toStringAsFixed(1)}頭が該当）\n'
        '$body',
      );
    }

    // 4. 全体に共通する免責
    notes.add(
      'ここに出ている馬は「過去データの傾向に当てはまる」というだけで、'
      '今回の結果を予想したものではありません。あくまで判断材料のひとつとしてご覧ください。',
    );

    return notes;
  }

  /// 脚質 × リフト水準の16パターンから本文を選ぶ
  static String _bodyFor(String style, String level, double perRace) {
    final n = perRace.toStringAsFixed(1);

    switch (style) {
      case '逃げ':
        switch (level) {
          case 'outstanding':
            return 'データ上、このレースで最も勝ち切りやすい位置取りです。'
                'ただし最終コーナーで先頭付近にいられるのは1レースあたり約$n頭で、'
                '実際に主導権を握れるのは基本的に1頭だけです。'
                '下の候補に逃げ馬が複数並んでいても、恩恵を受けられるのはそのうち1頭です。'
                '枠順や過去のテンの速さを見て「今回どの馬が前に行けそうか」を1頭に絞ってから使うと、この数字が活きます。';
          case 'favorable':
            return 'データ上は前に行った馬が有利なレースです。'
                'ただし該当できるのは1レース約$n頭と限られ、実際に逃げられるのは1頭だけです。'
                '候補が複数いる場合は、そのうち1頭しか恩恵を受けられない前提で見てください。'
                '逃げ争いが激しくなると共倒れになることもあります。';
          case 'neutral':
            return '逃げの成績は全体平均とほぼ同じで、データ上「逃げれば有利」とは言えないレースです。'
                '逃げ馬というだけで買う根拠にはなりません。'
                'この候補を使うなら、人気や馬体重など他のタブでも名前が挙がっているかを確認してから判断するのが安全です。';
          default:
            return 'データ上、このレースで前に行った馬は苦戦しています。'
                '逃げ候補は割り引いて見るのが無難で、むしろ差し・追込側の候補を重視したほうが過去の傾向には沿います。'
                'ただし今回のメンバーに逃げたい馬が1頭しかいない場合は、'
                '競り合いが起きず楽に運べるぶん過去と条件が変わる可能性もあります。';
        }
      case '先行':
        switch (level) {
          case 'outstanding':
            return 'データ上、最も信頼できる位置取りです。'
                'しかも1レース約$n頭が該当する幅の広いゾーンなので、逃げと違って複数の馬が同時に恩恵を受けられます。'
                '候補を1頭に絞りきれないときは、この脚質から手広く拾う戦略が取りやすいレースです。';
          case 'favorable':
            return 'データ上は有利な位置取りです。'
                '1レース約$n頭が該当するため、複数の馬が同時に恩恵を受けられます。'
                'ただし該当頭数が多いぶん「先行だから買う」では絞り込めないので、'
                'この中から他のタブでも名前が挙がっている馬を選ぶとよさそうです。';
          case 'neutral':
            return '先行の成績は全体平均とほぼ同じです。'
                '1着の数だけを見ると先行が最多に見えることがありますが、'
                'それは該当する馬が1レース約$n頭と多いためで、1頭あたりの優位性はありません。'
                'この候補は先行であること以外の材料で裏付けを取ってください。';
          default:
            return '前めの位置取りは、データ上このレースでは結果に結びついていません。'
                '該当頭数が1レース約$n頭と多いため1着の数は出ていても、1頭あたりで見ると平均を下回ります。'
                '先行候補を軸にするのは慎重に判断したほうがよさそうです。';
        }
      case '差し':
        switch (level) {
          case 'outstanding':
            return 'データ上、中団から差してくる馬が恵まれるレースです。'
                '1レース約$n頭が該当する広いゾーンなので複数頭を候補にでき、'
                '前が競り合って崩れる展開になればさらに後押しになります。';
          case 'favorable':
            return 'データ上はやや有利な位置取りです。'
                'ただし1レース約$n頭が該当するため、差しというだけでは絞り込めません。'
                'この中から上がりタイムの速い馬や、他のタブでも名前が挙がる馬を選ぶと精度が上がります。';
          case 'neutral':
            return '差しの成績は全体平均とほぼ同じです。'
                '複勝率が高めに出ていても、それは該当頭数が1レース約$n頭と多いためで、'
                '差しであること自体は有利材料になりません。数字の見た目に引きずられないようご注意ください。';
          default:
            return 'データ上、このレースで中団から差して勝ち切った馬はほとんどいません。'
                '3着以内に食い込む可能性は残りますが、勝ち馬として選ぶ根拠としては弱いです。'
                '複勝狙いなら候補になりますが、単勝や馬単の1着付けには向きません。';
        }
      case '追込':
        switch (level) {
          case 'outstanding':
            return 'データ上は後方一気が決まりやすいレースです。'
                'ただし該当するのは1レース約$n頭と少なく、サンプル数が限られるぶん数字の振れ幅も大きくなります。'
                '過去に何度も同じ形で決まっているのか、たまたま1回だけなのかを'
                '「分析対象」タブで確認すると判断しやすくなります。';
          case 'favorable':
            return 'データ上は有利ですが、該当するのが1レース約$n頭とサンプルが少ないため、'
                '数字は参考程度に見てください。展開が向いたときに大きく浮上するタイプと考えると分かりやすいです。';
          case 'neutral':
            return '追込の成績は全体平均とほぼ同じで、後方待機が特に有利とも不利とも言えません。'
                '展開次第で結果が変わる位置取りなので、今回のペースが速くなりそうかどうかと合わせて判断してください。';
          default:
            return 'データ上、このレースで最後方から届いた馬はほとんどいません。'
                '追込候補は割り引いて見るのが無難です。'
                'ただし過去にハイペースのレースが少なかっただけの可能性もあるため、'
                '今回の想定ペースが速いなら評価を上げる余地はあります。';
        }
      default:
        return 'この脚質については過去データが少なく、傾向を読み取れる段階にありません。';
    }
  }
}
