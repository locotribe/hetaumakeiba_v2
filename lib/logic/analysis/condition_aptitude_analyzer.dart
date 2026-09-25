// lib/logic/analysis/condition_aptitude_analyzer.dart

import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/logic/analysis/leg_style_analyzer.dart';
// [追加] 好走条件 馬詳細移植 StepA-3: 馬場データ（芝クッション値/ダ含水率）の集計 (v.2026.9.25+26092507)
import 'package:hetaumakeiba_v2/models/track_conditions_model.dart';

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

/// カテゴリ内の1つの値（例: 「芝1400-1600」）
class AptitudeValue {
  final String label;
  final RankTally tally;
  final bool isReference; // 総走数 < MIN_RACES（参考表示）
  final bool isBest;      // カテゴリ内の得意（本走最上位・勝率>0）
  const AptitudeValue({
    required this.label,
    required this.tally,
    this.isReference = false,
    this.isBest = false,
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

  static String? directionOf(String venue) {
    final name = _venueName(venue);
    if (name.isEmpty) return null;
    if (name == '東京' || name == '中京' || name == '新潟') return '左';
    return '右';
  }

  static String gradeClassOf(String raceName) {
    if (raceName.contains('(GI)')) return 'G1';
    if (raceName.contains('(GII)')) return 'G2';
    if (raceName.contains('(GIII)')) return 'G3';
    if (raceName.contains('OP') || raceName.contains('L)')) return 'OP';
    return '条件';
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

  // [追加] 好走条件 馬詳細移植 StepA-3: 芝クッション値の帯（2段） (v.2026.9.25+26092507)
  static String cushionBand(double v) => v >= 9.5 ? '9.5以上' : '9.4以下';

  // [追加] 好走条件 馬詳細移植 StepA-3: ダート含水率(ゴール前)の帯（下限基準4段） (v.2026.9.25+26092507)
  static String moistureBand(double v) {
    if (v < 7) return '6%以下';
    if (v < 11) return '7〜10%';
    if (v < 14) return '11〜13%';
    return '14%以上';
  }

  // [追加] 好走条件 馬詳細移植 StepA-3: 固定順カテゴリ（勝率順・得意印なし。馬場データ用） (v.2026.9.25+26092507)
  static AptitudeCategory? _buildFixedCategory(
      String name, List<String> order, Map<String, List<HorseRaceRecord>> grouped) {
    if (grouped.isEmpty) return null;
    final List<AptitudeValue> values = [];
    for (final label in order) {
      final recs = grouped[label];
      if (recs == null || recs.isEmpty) continue;
      values.add(AptitudeValue(
        label: label,
        tally: rankTallyOf(recs),
        isReference: false,
        isBest: false,
      ));
    }
    if (values.isEmpty) return null;
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

  // カテゴリ定義（名前と値ラベル関数）。追加はここに1行足すだけ。
  static final List<MapEntry<String, String? Function(HorseRaceRecord)>> categoryDefs = [
    MapEntry('距離', distanceLabelOf),
    MapEntry('芝/ダ', (r) => surfaceOf(r.distance)),
    MapEntry('回り', (r) => directionOf(r.venue)),
    MapEntry('馬場', (r) => r.trackCondition.isEmpty ? null : r.trackCondition),
    MapEntry('クラス', (r) => gradeClassOf(r.raceName)),
    MapEntry('脚質', legStyleOf),
    MapEntry('開催地', venueLabelOf),
    MapEntry('人気', (r) => popularityBand(r.popularity)),
    MapEntry('天候', (r) => r.weather.isEmpty ? null : r.weather),
    MapEntry('馬体重増減', (r) => weightDeltaBand(r.horseWeight)),
  ];

  static ConditionAptitude analyze(List<HorseRaceRecord> records,
      {Map<String, TrackConditionRecord?> trackConditions = const {}}) {
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
      if (grouped.isEmpty) continue;

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

    // [追加] 好走条件 馬詳細移植 StepA-3: 馬場データ（芝→クッション値 / ダ→含水率ゴール前）を馬場カテゴリの直後に挿入 (v.2026.9.25+26092507)
    final Map<String, List<HorseRaceRecord>> cushionGroups = {};
    final Map<String, List<HorseRaceRecord>> moistureGroups = {};
    for (final r in records) {
      final tc = trackConditions[r.raceId];
      if (tc == null) continue;
      final s = surfaceOf(r.distance);
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
    final List<AptitudeCategory> trackExtras = [];
    final cushionCat =
        _buildFixedCategory('クッション値(芝)', ['9.5以上', '9.4以下'], cushionGroups);
    if (cushionCat != null) trackExtras.add(cushionCat);
    final moistureCat = _buildFixedCategory(
        '含水率(ダ・ゴール前)', ['6%以下', '7〜10%', '11〜13%', '14%以上'], moistureGroups);
    if (moistureCat != null) trackExtras.add(moistureCat);
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
