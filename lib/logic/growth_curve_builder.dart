// lib/logic/growth_curve_builder.dart

// [追加] 馬体重成長曲線 Step1: 馬詳細タブ「情報・血統」の成長曲線（馬体重の推移＋人気・着順）を描くための純粋ロジック。
// 過去走（horse_performance）から点の列を作り、表示期間の絞り込み・縦軸の窓・見出しの集計を行う。
// DB / I/O / UI には一切触れない (v.2026.10.1+26100101)

import 'package:hetaumakeiba_v2/logic/analysis/horse_record_asof_filter.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';

/// 横軸の表示期間（同じ枠の中でスイッチで切り替える）
enum GrowthRange { oneYear, threeYears, all }

/// 着順の種類（数字の着順が無いレースを見分ける）
enum GrowthFinishKind {
  /// 数字の着順あり
  numeric,

  /// 競走中止（netkeiba の着順「中」）
  stopped,

  /// 競走除外（「除」）
  excluded,

  /// 出走取消（「取」）
  scratched,

  /// 不明（空など）
  unknown,
}

/// グラフの1点（1レース、または今回の当日体重）
class GrowthPoint {
  final DateTime date;

  /// レース名（netkeiba の表記のまま。今回の点は '今回'）
  final String raceName;

  /// 馬体重(kg)。計不などで不明なら null
  final int? weight;

  /// 前走からの増減(kg)。デビュー戦・不明なら null
  final int? weightChange;

  /// 人気。不明なら null
  final int? popularity;

  /// 着順（数字のときだけ）。それ以外は null
  final int? rank;

  final GrowthFinishKind finishKind;

  /// 頭数。不明なら null
  final int? fieldSize;

  /// 今回レースの当日体重の点なら true
  final bool isCurrent;

  const GrowthPoint({
    required this.date,
    required this.raceName,
    required this.weight,
    required this.weightChange,
    required this.popularity,
    required this.rank,
    required this.finishKind,
    required this.fieldSize,
    required this.isCurrent,
  });

  /// 着順が人気より上位なら 1、下位なら -1、同じなら 0。比べられなければ null。
  int? get rankVsPopularity {
    final r = rank;
    final p = popularity;
    if (r == null || p == null) return null;
    if (r < p) return 1;
    if (r > p) return -1;
    return 0;
  }
}

/// 縦軸（馬体重）の表示範囲。min と max は10kg単位
class GrowthWeightWindow {
  final int min;
  final int max;

  const GrowthWeightWindow({required this.min, required this.max});

  bool contains(int kg) => kg >= min && kg <= max;
}

/// 見出しの1行に出す集計（全期間）
class GrowthSummary {
  /// 体重の分かる最初の走（ふつうはデビュー戦）の体重
  final int? debutWeight;

  /// 体重の分かる最後の点（今回の当日体重があればそれ）
  final int? latestWeight;
  final int? maxWeight;
  final int? minWeight;

  /// 走数（今回の点は数えない）
  final int runCount;

  const GrowthSummary({
    required this.debutWeight,
    required this.latestWeight,
    required this.maxWeight,
    required this.minWeight,
    required this.runCount,
  });

  /// デビューからの増減。どちらかが不明なら null
  int? get diffFromDebut {
    final d = debutWeight;
    final l = latestWeight;
    if (d == null || l == null) return null;
    return l - d;
  }
}

class GrowthCurveBuilder {
  GrowthCurveBuilder._();

  /// 水準線の体重
  static const int referenceWeight = 450;

  /// 縦軸の窓: データの最小・最大の外側に足す余白(kg)
  static const int windowMargin = 10;

  /// 縦軸の窓の最低の高さ(kg)
  static const int minWindowHeight = 60;

  /// 縦軸の目盛りの間隔(kg)。窓の上下端もこの単位にそろえる
  static const int gridStep = 10;

  /// 体重がまったく無いときの窓
  static const GrowthWeightWindow emptyWindow =
      GrowthWeightWindow(min: 420, max: 480);

  /// '478(+6)' → 478、'480' → 480、'計不' → null
  static int? parseWeightKg(String text) {
    final m = RegExp(r'^\s*(\d{3,4})').firstMatch(text);
    if (m == null) return null;
    return int.parse(m.group(1)!);
  }

  /// '478(+6)' → 6、'476(-8)' → -8、'472(0)' → 0、括弧が無ければ null
  static int? parseWeightChange(String text) {
    final m = RegExp(r'\(\s*([+-]?\d+)\s*\)').firstMatch(text);
    if (m == null) return null;
    return int.parse(m.group(1)!);
  }

  /// 1以上の整数ならその値、それ以外は null（人気・頭数用）
  static int? parsePositiveInt(String text) {
    final v = int.tryParse(text.trim());
    if (v == null || v <= 0) return null;
    return v;
  }

  /// 着順の文字列から数字の着順を取り出す（'4(降)' → 4）。数字で始まらなければ null
  static int? parseRank(String text) {
    final m = RegExp(r'^\s*(\d+)').firstMatch(text);
    if (m == null) return null;
    final v = int.parse(m.group(1)!);
    return v > 0 ? v : null;
  }

  /// 着順の文字列から種類を決める
  static GrowthFinishKind finishKindOf(String rankText) {
    if (parseRank(rankText) != null) return GrowthFinishKind.numeric;
    if (rankText.contains('中')) return GrowthFinishKind.stopped;
    if (rankText.contains('除')) return GrowthFinishKind.excluded;
    if (rankText.contains('取')) return GrowthFinishKind.scratched;
    return GrowthFinishKind.unknown;
  }

  /// レース名のクラス表記を短くする（グラフ下のラベル用）
  static String shortRaceName(String name) {
    const replacements = <String, String>{
      '(GIII)': 'G3',
      '(GII)': 'G2',
      '(GI)': 'G1',
      '(JpnIII)': 'Jpn3',
      '(JpnII)': 'Jpn2',
      '(JpnI)': 'Jpn1',
      '(L)': 'L',
      '(OP)': 'OP',
      '(1勝クラス)': '1勝',
      '(2勝クラス)': '2勝',
      '(3勝クラス)': '3勝',
    };
    var s = name.trim();
    for (final entry in replacements.entries) {
      s = s.replaceAll(entry.key, entry.value);
    }
    return s;
  }

  /// 過去走から点の列を作る（日付の古い順）。
  /// [raceDate] があれば、その日より前の走だけを使う（その日の走と未来の走は除く）。
  /// [currentHorseWeight] が括弧付き（当日体重の発表済み）で [raceDate] があれば、最後に「今回」の点を足す。
  static List<GrowthPoint> buildPoints({
    required List<HorseRaceRecord> records,
    DateTime? raceDate,
    String? currentHorseWeight,
  }) {
    final dated = <MapEntry<DateTime, HorseRaceRecord>>[];
    for (final r in records) {
      final d = parseHorseRecordDate(r.date);
      if (d == null) continue;
      if (raceDate != null && !d.isBefore(raceDate)) continue;
      dated.add(MapEntry(d, r));
    }
    dated.sort((a, b) => a.key.compareTo(b.key));

    final points = <GrowthPoint>[];
    for (var i = 0; i < dated.length; i++) {
      final d = dated[i].key;
      final r = dated[i].value;
      points.add(GrowthPoint(
        date: d,
        raceName: r.raceName.trim(),
        weight: parseWeightKg(r.horseWeight),
        // デビュー戦の増減は netkeiba では常に (0) で意味を持たないため null
        weightChange: i == 0 ? null : parseWeightChange(r.horseWeight),
        popularity: parsePositiveInt(r.popularity),
        rank: parseRank(r.rank),
        finishKind: finishKindOf(r.rank),
        fieldSize: parsePositiveInt(r.numberOfHorses),
        isCurrent: false,
      ));
    }

    final current = currentHorseWeight ?? '';
    if (raceDate != null && current.contains('(')) {
      final w = parseWeightKg(current);
      if (w != null) {
        points.add(GrowthPoint(
          date: raceDate,
          raceName: '今回',
          weight: w,
          weightChange: points.isEmpty ? null : parseWeightChange(current),
          popularity: null,
          rank: null,
          finishKind: GrowthFinishKind.unknown,
          fieldSize: null,
          isCurrent: true,
        ));
      }
    }
    return points;
  }

  /// 「直近1年」「3年」の基準日。
  /// ふつうは今日（時刻なし）。過去レース（レース日が今日より前）を開いたときはレース日。
  static DateTime baseDate({DateTime? raceDate, required DateTime today}) {
    final t = DateTime(today.year, today.month, today.day);
    if (raceDate != null && raceDate.isBefore(t)) return raceDate;
    return t;
  }

  /// 表示期間で点を絞る。基準日から1年（3年）前の同じ日以降を残す。
  static List<GrowthPoint> pointsInRange(
      List<GrowthPoint> points, GrowthRange range, DateTime base) {
    if (range == GrowthRange.all) return List<GrowthPoint>.of(points);
    final years = range == GrowthRange.oneYear ? 1 : 3;
    final from = DateTime(base.year - years, base.month, base.day);
    return points.where((p) => !p.date.isBefore(from)).toList();
  }

  /// 縦軸の窓。データの最小−10kg〜最大+10kg、高さは最低60kg、上下端は10kg単位に広げる。
  /// 体重が1つも無ければ [emptyWindow]。
  static GrowthWeightWindow weightWindow(List<GrowthPoint> points) {
    int? minW;
    int? maxW;
    for (final p in points) {
      final w = p.weight;
      if (w == null) continue;
      if (minW == null || w < minW) minW = w;
      if (maxW == null || w > maxW) maxW = w;
    }
    if (minW == null || maxW == null) return emptyWindow;

    var lo = minW - windowMargin;
    var hi = maxW + windowMargin;
    if (hi - lo < minWindowHeight) {
      final center = (lo + hi) / 2;
      lo = (center - minWindowHeight / 2).floor();
      hi = (center + minWindowHeight / 2).ceil();
    }
    lo = (lo / gridStep).floor() * gridStep;
    hi = (hi / gridStep).ceil() * gridStep;
    return GrowthWeightWindow(min: lo, max: hi);
  }

  /// 見出し用の集計（渡した点すべてが対象。ふつうは全期間を渡す）
  static GrowthSummary summarize(List<GrowthPoint> points) {
    int? debut;
    int? latest;
    int? maxW;
    int? minW;
    var runs = 0;
    for (final p in points) {
      if (!p.isCurrent) runs++;
      final w = p.weight;
      if (w == null) continue;
      debut ??= w;
      latest = w;
      if (maxW == null || w > maxW) maxW = w;
      if (minW == null || w < minW) minW = w;
    }
    return GrowthSummary(
      debutWeight: debut,
      latestWeight: latest,
      maxWeight: maxW,
      minWeight: minW,
      runCount: runs,
    );
  }
}
