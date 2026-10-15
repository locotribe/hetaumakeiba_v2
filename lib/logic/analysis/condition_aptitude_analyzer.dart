// lib/logic/analysis/condition_aptitude_analyzer.dart

import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/logic/analysis/leg_style_analyzer.dart';
// [追加] 好走条件 馬詳細移植 StepA-3: 馬場データ（芝クッション値/ダ含水率）の集計 (v.2026.9.25+26092507)
import 'package:hetaumakeiba_v2/models/track_conditions_model.dart';
// [追加] 馬詳細タブ 表示項目変更 Step1: デビュー戦と騎手の最新騎乗を日付で決める (v.2026.10.14+26101407)
import 'package:hetaumakeiba_v2/logic/analysis/horse_record_asof_filter.dart';
import 'package:hetaumakeiba_v2/logic/race_class_grade.dart';

// [追加] 好走条件 馬詳細移植 StepA-1: 各馬の好走条件（得意条件）を条件カテゴリ主軸で集計する純粋ロジック (v.2026.9.25+26092505)

/// 着度数（1着/2着/3着/着外）と各種率
class RankTally {
  final int first;
  final int second;
  final int third;
  final int out;
  const RankTally({this.first = 0, this.second = 0, this.third = 0, this.out = 0});

  int get total => first + second + third + out;
  double get winRate => total == 0 ? 0.0 : first / total;
  double get placeRate => total == 0 ? 0.0 : (first + second) / total;
  double get showRate => total == 0 ? 0.0 : (first + second + third) / total;

  RankTally addRank(int? rank) {
    if (rank == 1) return RankTally(first: first + 1, second: second, third: third, out: out);
    if (rank == 2) return RankTally(first: first, second: second + 1, third: third, out: out);
    if (rank == 3) return RankTally(first: first, second: second, third: third + 1, out: out);
    return RankTally(first: first, second: second, third: third, out: out + 1);
  }
}

/// カテゴリ内の1つの値（例: 「芝1600」）
class AptitudeValue {
  final String label;
  final RankTally tally;
  final bool isReference; // 総走数 < MIN_RACES（参考表示）
  final bool isBest;      // カテゴリ内の得意（本走最上位・勝率>0）
  // [追加] 馬詳細タブ 表示項目変更 Step1: 今回レースの条件に当たる値（クッション値・含水率の段、今回の騎手） (v.2026.10.14+26101407)
  final bool isCurrent;
  const AptitudeValue({
    required this.label,
    required this.tally,
    this.isReference = false,
    this.isBest = false,
    this.isCurrent = false,
  });
}

/// 条件カテゴリ（例: 「距離」）
class AptitudeCategory {
  final String name;
  final List<AptitudeValue> values;
  const AptitudeCategory({required this.name, required this.values});
}

/// 1頭の好走条件（得意条件）分析結果
class ConditionAptitude {
  final RankTally overall;
  final List<AptitudeCategory> categories;
  const ConditionAptitude({required this.overall, required this.categories});
}

// [追加] 馬詳細タブ 表示項目変更 Step1: 並び順を決めた値の1件（キー・表示名・着度数） (v.2026.10.14+26101407)
class _OrderedEntry {
  final String key;
  final String label;
  final RankTally tally;
  const _OrderedEntry(this.key, this.label, this.tally);
}

class ConditionAptitudeAnalyzer {
  ConditionAptitudeAnalyzer._();

  /// 得意判定・上位並べの対象にする最低走数
  static const int MIN_RACES = 2;

  // ---- 値ラベル関数（対象外は null を返す） ----

  static String _venueName(String venue) => venue.replaceAll(RegExp(r'[0-9]'), '');

  /// 馬場種別（芝/ダ/障）。distance 先頭の非数字から。
  static String? surfaceOf(String distance) {
    final m = RegExp(r'^[^0-9]+').firstMatch(distance);
    if (m == null) return null;
    final s = m.group(0)!;
    if (s.contains('芝')) return '芝';
    if (s.contains('ダ')) return 'ダ';
    if (s.contains('障')) return '障';
    return null;
  }

  /// 距離(m)。distance 中の数字。
  static int? distanceMetersOf(String distance) {
    final m = RegExp(r'[0-9]+').firstMatch(distance);
    if (m == null) return null;
    return int.tryParse(m.group(0)!);
  }

  static String distanceBandLabel(int meters) {
    if (meters <= 1300) return '〜1300';
    if (meters <= 1600) return '1400-1600';
    if (meters <= 2000) return '1700-2000';
    if (meters <= 2400) return '2100-2400';
    return '2500〜';
  }

  /// 距離カテゴリの値ラベル（芝/ダのみ。障・不明は null）
  static String? distanceLabelOf(HorseRaceRecord r) {
    final s = surfaceOf(r.distance);
    if (s == null || s == '障') return null;
    final m = distanceMetersOf(r.distance);
    if (m == null) return null;
    return '$s${distanceBandLabel(m)}';
  }

  // [追加] 馬詳細タブ 表示項目変更 Step1: 経験距離ごとの値ラベル（例「芝1600」。障・不明は null）。
  // 距離帯の distanceLabelOf はヒートマップ（condition_ranking_builder）が使うため変えない (v.2026.10.14+26101407)
  static String? distanceExactLabelOf(HorseRaceRecord r) {
    final s = surfaceOf(r.distance);
    if (s == null || s == '障') return null;
    final m = distanceMetersOf(r.distance);
    if (m == null) return null;
    return '$s$m';
  }

  static String? directionOf(String venue) {
    final name = _venueName(venue);
    if (name.isEmpty) return null;
    if (name == '東京' || name == '中京' || name == '新潟') return '左';
    return '右';
  }

  // [修正] クラス判定の共通化 Step3: レース名だけの判定を共通の区分（raceClassGradeOfName）からの表示に替えた。Jpn交流重賞は G1〜G3 になる (v.2026.10.16+26101603)
  static String gradeClassOf(String raceName) {
    return _gradeLabelOf(raceClassGradeOfName(raceName));
  }

  // [追加] クラス判定の共通化 Step3: 過去走用。主催も見るので、地方の重賞以外（地方のOP・地方の条件戦）は「条件」、Jpn交流重賞は G1〜G3 になる (v.2026.10.16+26101603)
  static String gradeClassOfRecord(HorseRaceRecord r) {
    return _gradeLabelOf(raceClassGradeOfRecord(r));
  }

  static String _gradeLabelOf(RaceClassGrade grade) {
    switch (grade) {
      case RaceClassGrade.g1:
        return 'G1';
      case RaceClassGrade.g2:
        return 'G2';
      case RaceClassGrade.g3:
        return 'G3';
      case RaceClassGrade.listed:
      case RaceClassGrade.open:
        return 'OP';
      case RaceClassGrade.win3:
      case RaceClassGrade.win2:
      case RaceClassGrade.win1:
      case RaceClassGrade.newcomer:
      case RaceClassGrade.maiden:
      case RaceClassGrade.local:
      case RaceClassGrade.unknown:
        return '条件';
    }
  }

  static String? legStyleOf(HorseRaceRecord r) {
    final s = LegStyleAnalyzer.analyzeSingleRaceStyle(r);
    return s == '不明' ? null : s;
  }

  static String? venueLabelOf(HorseRaceRecord r) {
    final name = _venueName(r.venue);
    return name.isEmpty ? null : name;
  }

  static String? popularityBand(String popularity) {
    final p = int.tryParse(popularity);
    if (p == null) return null;
    if (p <= 3) return '1-3番人気';
    if (p <= 6) return '4-6番人気';
    return '7番人気〜';
  }

  /// 馬体重増減（例 "438(-6)" → -6）。括弧が無ければ null。
  static int? weightDeltaOf(String horseWeight) {
    final m = RegExp(r'\(([-+]?[0-9]+)\)').firstMatch(horseWeight);
    if (m == null) return null;
    return int.tryParse(m.group(1)!);
  }

  static String? weightDeltaBand(String horseWeight) {
    final d = weightDeltaOf(horseWeight);
    if (d == null) return null;
    if (d <= -8) return '大幅減';
    if (d <= -2) return 'やや減';
    if (d <= 1) return '±';
    if (d <= 7) return 'やや増';
    return '大幅増';
  }

  // [修正] 馬詳細タブ 表示項目変更 Step1: 芝クッション値の帯を6段に。値を10倍して四捨五入した整数で判定する (v.2026.10.14+26101407)
  static const List<String> cushionBandOrder = [
    '10以上',
    '9.9-9.5',
    '9.4-9',
    '8.9-8.5',
    '8.4-8',
    '7.9以下',
  ];

  static String cushionBand(double v) {
    final t = (v * 10).round();
    if (t >= 100) return '10以上';
    if (t >= 95) return '9.9-9.5';
    if (t >= 90) return '9.4-9';
    if (t >= 85) return '8.9-8.5';
    if (t >= 80) return '8.4-8';
    return '7.9以下';
  }

  // [追加] 馬詳細タブ 表示項目変更 Step1: ダート含水率(ゴール前)の帯の表示順 (v.2026.10.14+26101407)
  static const List<String> moistureBandOrder = ['6%以下', '7〜10%', '11〜13%', '14%以上'];

  // [追加] 好走条件 馬詳細移植 StepA-3: ダート含水率(ゴール前)の帯（下限基準4段） (v.2026.9.25+26092507)
  static String moistureBand(double v) {
    if (v < 7) return '6%以下';
    if (v < 11) return '7〜10%';
    if (v < 14) return '11〜13%';
    return '14%以上';
  }

  // [修正] 馬詳細タブ 表示項目変更 Step1: 固定順カテゴリ（馬場データ用）。出走の無い段も着度数0で必ず出す。
  // 得意印・参考なし。[currentLabel] の段に今回印 (v.2026.10.14+26101407)
  static AptitudeCategory _buildFixedCategory(String name, List<String> order,
      Map<String, List<HorseRaceRecord>> grouped, String? currentLabel) {
    final List<AptitudeValue> values = [];
    for (final label in order) {
      final recs = grouped[label] ?? const <HorseRaceRecord>[];
      values.add(AptitudeValue(
        label: label,
        tally: rankTallyOf(recs),
        isReference: false,
        isBest: false,
        isCurrent: label == currentLabel,
      ));
    }
    return AptitudeCategory(name: name, values: values);
  }

  /// レコード群の着度数
  static RankTally rankTallyOf(List<HorseRaceRecord> records) {
    var t = const RankTally();
    for (final r in records) {
      t = t.addRank(int.tryParse(r.rank));
    }
    return t;
  }

  // [追加] 馬詳細タブ 表示項目変更 Step1: デビュー戦（日付がいちばん古い走。日付が読めない走は除く）。無ければ null (v.2026.10.14+26101407)
  static HorseRaceRecord? debutRecordOf(List<HorseRaceRecord> records) {
    HorseRaceRecord? debut;
    DateTime? debutDate;
    for (final r in records) {
      final d = parseHorseRecordDate(r.date);
      if (d == null) continue;
      if (debutDate == null || d.isBefore(debutDate)) {
        debut = r;
        debutDate = d;
      }
    }
    return debut;
  }

  // [追加] 馬詳細タブ 表示項目変更 Step1: 騎手をまとめるキー（騎手IDがあれば ID、無ければ騎手名）。どちらも空なら null (v.2026.10.14+26101407)
  static String? jockeyKeyOf(String jockeyId, String jockeyName) {
    final id = jockeyId.trim();
    if (id.isNotEmpty) return 'id:$id';
    final name = jockeyName.trim();
    if (name.isNotEmpty) return 'name:$name';
    return null;
  }

  // [追加] 馬詳細タブ 表示項目変更 Step1: 成績の比較（勝率→複勝率→走数の降順） (v.2026.10.14+26101407)
  static int _cmpPerfTally(RankTally a, RankTally b) {
    final w = b.winRate.compareTo(a.winRate);
    if (w != 0) return w;
    final s = b.showRate.compareTo(a.showRate);
    if (s != 0) return s;
    return b.total.compareTo(a.total);
  }

  // [追加] 馬詳細タブ 表示項目変更 Step1: 並び順を決めた値の列に印を付ける。
  // 得意＝2走以上の値のうち成績最上位で勝率>0 の1つ、参考＝1走、今回＝キーが [currentKey] と一致 (v.2026.10.14+26101407)
  static List<AptitudeValue> _markInOrder(List<_OrderedEntry> ordered, {String? currentKey}) {
    _OrderedEntry? best;
    for (final e in ordered) {
      if (e.tally.total < MIN_RACES) continue;
      if (best == null || _cmpPerfTally(e.tally, best.tally) < 0) best = e;
    }
    if (best != null && best.tally.winRate <= 0) best = null;
    return [
      for (final e in ordered)
        AptitudeValue(
          label: e.label,
          tally: e.tally,
          isReference: e.tally.total < MIN_RACES,
          isBest: identical(e, best),
          isCurrent: currentKey != null && e.key == currentKey,
        ),
    ];
  }

  // [追加] 馬詳細タブ 表示項目変更 Step1: 距離カテゴリの並び（芝→ダ、それぞれ距離の短い順） (v.2026.10.14+26101407)
  static int _cmpDistanceLabel(String a, String b) {
    int surfaceRank(String label) => label.startsWith('芝') ? 0 : 1;
    final s = surfaceRank(a).compareTo(surfaceRank(b));
    if (s != 0) return s;
    final ma = distanceMetersOf(a) ?? 0;
    final mb = distanceMetersOf(b) ?? 0;
    return ma.compareTo(mb);
  }

  // [追加] 馬詳細タブ 表示項目変更 Step1: 騎手カテゴリ（騎乗回数→勝率→複勝率の降順。表示名はいちばん新しい騎乗の騎手名） (v.2026.10.14+26101407)
  static AptitudeCategory? _buildJockeyCategory(
      List<HorseRaceRecord> records, String? currentJockeyId, String? currentJockeyName) {
    final Map<String, List<HorseRaceRecord>> grouped = {};
    final Map<String, String> latestName = {};
    final Map<String, DateTime> latestDate = {};
    for (final r in records) {
      final key = jockeyKeyOf(r.jockeyId, r.jockey);
      if (key == null) continue;
      grouped.putIfAbsent(key, () => <HorseRaceRecord>[]).add(r);
      final name = r.jockey.trim();
      if (name.isEmpty) continue;
      final d = parseHorseRecordDate(r.date);
      final prev = latestDate[key];
      if (d != null && (prev == null || d.isAfter(prev))) {
        latestDate[key] = d;
        latestName[key] = name;
      } else if (!latestName.containsKey(key)) {
        latestName[key] = name;
      }
    }
    if (grouped.isEmpty) return null;

    final entries = grouped.entries
        .map((e) => _OrderedEntry(e.key, latestName[e.key] ?? '--', rankTallyOf(e.value)))
        .toList()
      ..sort((a, b) {
        final c = b.tally.total.compareTo(a.tally.total);
        if (c != 0) return c;
        final w = b.tally.winRate.compareTo(a.tally.winRate);
        if (w != 0) return w;
        return b.tally.showRate.compareTo(a.tally.showRate);
      });

    final currentKey = jockeyKeyOf(currentJockeyId ?? '', currentJockeyName ?? '');
    return AptitudeCategory(name: '騎手', values: _markInOrder(entries, currentKey: currentKey));
  }

  // カテゴリ定義（名前と値ラベル関数）。追加はここに1行足すだけ。
  // [修正] 馬詳細タブ 表示項目変更 Step1: 距離を経験距離ごと（distanceExactLabelOf）に。騎手は脚質の直後に analyze() で挿入 (v.2026.10.14+26101407)
  static final List<MapEntry<String, String? Function(HorseRaceRecord)>> categoryDefs = [
    MapEntry('距離', distanceExactLabelOf),
    MapEntry('芝/ダ', (r) => surfaceOf(r.distance)),
    MapEntry('回り', (r) => directionOf(r.venue)),
    MapEntry('馬場', (r) => r.trackCondition.isEmpty ? null : r.trackCondition),
    // [修正] クラス判定の共通化 Step3: 過去走用の判定（主催も見る）に替えた (v.2026.10.16+26101603)
    MapEntry('クラス', gradeClassOfRecord),
    MapEntry('脚質', legStyleOf),
    MapEntry('開催地', venueLabelOf),
    MapEntry('人気', (r) => popularityBand(r.popularity)),
    MapEntry('天候', (r) => r.weather.isEmpty ? null : r.weather),
    MapEntry('馬体重増減', (r) => weightDeltaBand(r.horseWeight)),
  ];

  // [修正] 馬詳細タブ 表示項目変更 Step1: 今回レースの条件（芝/ダ・クッション値・含水率・騎手）を任意引数で受け取り「今回」印に使う。
  // 省略時は印なし（従来の呼び出しはそのまま動く） (v.2026.10.14+26101407)
  static ConditionAptitude analyze(
    List<HorseRaceRecord> records, {
    Map<String, TrackConditionRecord?> trackConditions = const {},
    String? currentSurface,
    double? currentCushionValue,
    double? currentMoistureDirtGoal,
    String? currentJockeyId,
    String? currentJockeyName,
  }) {
    final overall = rankTallyOf(records);
    final List<AptitudeCategory> categories = [];

    for (final def in categoryDefs) {
      final name = def.key;
      final labelFn = def.value;

      final Map<String, List<HorseRaceRecord>> grouped = {};
      for (final r in records) {
        final label = labelFn(r);
        if (label == null) continue;
        grouped.putIfAbsent(label, () => <HorseRaceRecord>[]).add(r);
      }

      if (grouped.isNotEmpty) {
        if (name == '距離') {
          // [追加] 馬詳細タブ 表示項目変更 Step1: 距離は勝率順ではなく 芝→ダ・距離の短い順。1走の値も同じ並びのまま参考にする (v.2026.10.14+26101407)
          final ordered = grouped.entries
              .map((e) => _OrderedEntry(e.key, e.key, rankTallyOf(e.value)))
              .toList()
            ..sort((a, b) => _cmpDistanceLabel(a.key, b.key));
          categories.add(AptitudeCategory(name: name, values: _markInOrder(ordered)));
        } else {
          final entries = grouped.entries
              .map((e) => MapEntry(e.key, rankTallyOf(e.value)))
              .toList();

          final main = entries.where((e) => e.value.total >= MIN_RACES).toList();
          final ref = entries.where((e) => e.value.total < MIN_RACES).toList();

          int cmpPerf(MapEntry<String, RankTally> a, MapEntry<String, RankTally> b) {
            final w = b.value.winRate.compareTo(a.value.winRate);
            if (w != 0) return w;
            final s = b.value.showRate.compareTo(a.value.showRate);
            if (s != 0) return s;
            return b.value.total.compareTo(a.value.total);
          }

          main.sort(cmpPerf);
          ref.sort(cmpPerf);

          final List<AptitudeValue> values = [];
          for (int i = 0; i < main.length; i++) {
            final e = main[i];
            final isBest = i == 0 && e.value.winRate > 0;
            values.add(AptitudeValue(
              label: e.key,
              tally: e.value,
              isReference: false,
              isBest: isBest,
            ));
          }
          for (final e in ref) {
            values.add(AptitudeValue(
              label: e.key,
              tally: e.value,
              isReference: true,
              isBest: false,
            ));
          }

          categories.add(AptitudeCategory(name: name, values: values));
        }
      }

      // [追加] 馬詳細タブ 表示項目変更 Step1: 騎手カテゴリは脚質の直後（脚質が判定できない馬でも同じ位置） (v.2026.10.14+26101407)
      if (name == '脚質') {
        final jockeyCat = _buildJockeyCategory(records, currentJockeyId, currentJockeyName);
        if (jockeyCat != null) categories.add(jockeyCat);
      }
    }

    // [追加] 好走条件 馬詳細移植 StepA-3: 馬場データ（芝→クッション値 / ダ→含水率ゴール前）を馬場カテゴリの直後に挿入 (v.2026.9.25+26092507)
    // [修正] 馬詳細タブ 表示項目変更 Step1: 芝の出走が1走以上あればクッション値6段、ダートの出走が1走以上あれば含水率4段を、
    // 出走の無い段も含めて必ず出す。今回レースの値の段に今回印 (v.2026.10.14+26101407)
    final Map<String, List<HorseRaceRecord>> cushionGroups = {};
    final Map<String, List<HorseRaceRecord>> moistureGroups = {};
    bool hasTurf = false;
    bool hasDirt = false;
    for (final r in records) {
      final s = surfaceOf(r.distance);
      if (s == '芝') hasTurf = true;
      if (s == 'ダ') hasDirt = true;
      final tc = trackConditions[r.raceId];
      if (tc == null) continue;
      if (s == '芝') {
        final cv = tc.cushionValue;
        if (cv != null) {
          cushionGroups.putIfAbsent(cushionBand(cv), () => <HorseRaceRecord>[]).add(r);
        }
      } else if (s == 'ダ') {
        final mg = tc.moistureDirtGoal;
        if (mg != null) {
          moistureGroups.putIfAbsent(moistureBand(mg), () => <HorseRaceRecord>[]).add(r);
        }
      }
    }
    final String? currentCushionLabel =
        (currentSurface == '芝' && currentCushionValue != null) ? cushionBand(currentCushionValue) : null;
    final String? currentMoistureLabel =
        (currentSurface == 'ダ' && currentMoistureDirtGoal != null) ? moistureBand(currentMoistureDirtGoal) : null;

    final List<AptitudeCategory> trackExtras = [];
    if (hasTurf) {
      trackExtras.add(
          _buildFixedCategory('クッション値(芝)', cushionBandOrder, cushionGroups, currentCushionLabel));
    }
    if (hasDirt) {
      trackExtras.add(
          _buildFixedCategory('含水率(ダ・ゴール前)', moistureBandOrder, moistureGroups, currentMoistureLabel));
    }
    if (trackExtras.isNotEmpty) {
      final idx = categories.indexWhere((c) => c.name == '馬場');
      if (idx >= 0) {
        categories.insertAll(idx + 1, trackExtras);
      } else {
        categories.addAll(trackExtras);
      }
    }

    return ConditionAptitude(overall: overall, categories: categories);
  }
}
