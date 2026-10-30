// lib/logic/analysis/horse_strength_summary.dart

// [追加] 得意条件まとめ Step1: 好走条件タブの「まとめ」カード（個体差・得意条件）を作る純粋ロジック。DB・画面には触れない (v.2026.10.31+26103101)

import 'package:hetaumakeiba_v2/logic/analysis/condition_aptitude_analyzer.dart';
import 'package:hetaumakeiba_v2/logic/analysis/horse_record_asof_filter.dart';
import 'package:hetaumakeiba_v2/logic/analysis/horse_record_stats.dart';
import 'package:hetaumakeiba_v2/logic/growth_curve_builder.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/track_conditions_model.dart';

/// 個体差の1行（例: 見出し「誕生」・本文「3月21日生まれ・今回 満3歳7か月」）
class TraitLine {
  final String label;
  final String text;
  const TraitLine(this.label, this.text);
}

/// 得意条件の1件（例: 軸「コース」・値「京都 芝1600m」）
class StrengthItem {
  final String axis;
  final String label;
  final RankTally tally;

  /// 今回のレースの条件に当たるなら true
  final bool isCurrent;
  const StrengthItem({
    required this.axis,
    required this.label,
    required this.tally,
    this.isCurrent = false,
  });
}

/// 得意条件の結果
class StrengthSummary {
  /// 数えた走数（取消・除外・空欄を除く）
  final int starts;

  /// 得意条件（軸の順、軸の中は複勝率→勝率→走数の大きい順）。走数が足りないときは空
  final List<StrengthItem> items;
  const StrengthSummary({required this.starts, required this.items});

  /// 得意条件を出すだけの走数があるか
  bool get hasEnoughStarts => starts >= HorseStrengthSummary.minStarts;
}

/// 今回のレースの条件（分からない項目は null）
class StrengthCurrent {
  final String? venue; // 例「京都」
  final String? distanceLabel; // 例「芝1600」
  final String? trackCondition; // 例「良」「稍重」
  final String? direction; // 左/右
  final double? cushionValue;
  final double? moistureDirtGoal;
  const StrengthCurrent({
    this.venue,
    this.distanceLabel,
    this.trackCondition,
    this.direction,
    this.cushionValue,
    this.moistureDirtGoal,
  });
}

class HorseStrengthSummary {
  HorseStrengthSummary._();

  /// 得意条件を出す最低の走数（1年分の検証で決めた。memory/馬詳細_得意条件まとめ_設計書.md）
  static const int minStarts = 4;

  /// 1つの条件の最低の走数
  static const int minRuns = 2;

  /// 得意とする複勝率の下限
  static const double minShowRate = 0.5;

  /// 得意とする、通算の複勝率からの上積みの下限
  static const double minLift = 0.15;

  /// 軸の並び
  static const List<String> axisOrder = ['コース', '距離', '馬場', 'クッション値', '含水率', '回り', '脚質'];

  /// 得意の判定（同じ条件で2走以上・複勝率50%以上・通算より15pt以上高い）
  static bool isStrong(RankTally t, double overallShowRate) {
    if (t.total < minRuns) return false;
    const eps = 1e-9;
    return t.showRate >= minShowRate - eps && t.showRate >= overallShowRate + minLift - eps;
  }

  // ---- 個体差 ----

  /// '2022年3月21日' → 2022-03-21。'2022/3/21'・'2022-03-21' も読む。読めなければ null
  static DateTime? parseBirthday(String? text) {
    if (text == null) return null;
    final m = RegExp(r'(\d{4})\D+(\d{1,2})\D+(\d{1,2})').firstMatch(text);
    if (m == null) return null;
    final y = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    final d = int.parse(m.group(3)!);
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
    return DateTime(y, mo, d);
  }

  /// 誕生日から [on] までの満の月数。[on] が誕生日より前なら null
  static int? ageInMonths(DateTime birthday, DateTime on) {
    var months = (on.year - birthday.year) * 12 + (on.month - birthday.month);
    if (on.day < birthday.day) months--;
    return months < 0 ? null : months;
  }

  /// 出走馬の中で、生まれが早い順の順位（1始まり。同じ日は同じ順位）。対象が無ければ null
  static int? birthOrder(DateTime target, Iterable<DateTime> entrants) {
    var earlier = 0;
    var found = false;
    for (final d in entrants) {
      if (d.isBefore(target)) earlier++;
      if (d == target) found = true;
    }
    return found ? earlier + 1 : null;
  }

  /// 「芝1600」→「芝1600m」。読めなければ null
  static String? _courseText(String distance) {
    final s = ConditionAptitudeAnalyzer.surfaceOf(distance);
    final m = ConditionAptitudeAnalyzer.distanceMetersOf(distance);
    if (s == null || m == null) return null;
    return '$s${m}m';
  }

  static String _signed(int v) => v > 0 ? '+$v' : '$v';

  /// 個体差の行（誕生・馬体重・距離・血統の順。分からない行は出さない）
  /// [records] はこの馬の過去走（レース日より前）。[entrantBirthdays] は今回の出走馬（取消を除く。この馬を含む）の誕生日。
  static List<TraitLine> traitsOf({
    required List<HorseRaceRecord> records,
    required DateTime? raceDate,
    String? birthdayText,
    List<DateTime> entrantBirthdays = const [],
    String? currentHorseWeight,
    String? currentDistanceLabel,
    String? sireName,
    String? damSireName,
    String? damDamName,
  }) {
    final lines = <TraitLine>[];

    // 誕生
    final birthday = parseBirthday(birthdayText);
    if (birthday != null) {
      var text = '${birthday.month}月${birthday.day}日生まれ';
      final months = raceDate == null ? null : ageInMonths(birthday, raceDate);
      if (months != null) text += '・今回 満${months ~/ 12}歳${months % 12}か月';
      final order = birthOrder(birthday, entrantBirthdays);
      if (order != null && entrantBirthdays.length >= 2) {
        text += '（出走馬${entrantBirthdays.length}頭中 早い方から$order番目）';
      }
      lines.add(TraitLine('誕生', text));
    }

    // 馬体重（デビュー → 前走 → 今回）
    final debut = ConditionAptitudeAnalyzer.debutRecordOf(records);
    HorseRaceRecord? latest;
    DateTime? latestDate;
    for (final r in records) {
      final d = parseHorseRecordDate(r.date);
      if (d == null) continue;
      if (latestDate == null || d.isAfter(latestDate)) {
        latest = r;
        latestDate = d;
      }
    }
    final debutW = debut == null ? null : GrowthCurveBuilder.parseWeightKg(debut.horseWeight);
    final latestW = (latest == null || identical(latest, debut))
        ? null
        : GrowthCurveBuilder.parseWeightKg(latest.horseWeight);
    final currentW = currentHorseWeight == null ? null : GrowthCurveBuilder.parseWeightKg(currentHorseWeight);
    final parts = <String>[
      if (debutW != null) 'デビュー ${debutW}kg',
      if (latestW != null) '前走 ${latestW}kg',
      if (currentW != null) '今回 ${currentW}kg',
    ];
    if (parts.isNotEmpty) {
      var text = parts.join(' → ');
      final last = currentW ?? latestW;
      if (debutW != null && last != null) text += '（デビューから${_signed(last - debutW)}kg）';
      lines.add(TraitLine('馬体重', text));
    }

    // 距離（デビュー → 今回）
    final debutCourse = debut == null ? null : _courseText(debut.distance);
    final currentCourse = currentDistanceLabel == null ? null : _courseText(currentDistanceLabel);
    if (debutCourse != null) {
      var text = 'デビュー $debutCourse';
      if (currentCourse != null) {
        text += ' → 今回 $currentCourse';
        final dm = ConditionAptitudeAnalyzer.distanceMetersOf(debut!.distance)!;
        final cm = ConditionAptitudeAnalyzer.distanceMetersOf(currentDistanceLabel!)!;
        final notes = <String>[
          cm == dm ? '同じ距離' : '${_signed(cm - dm)}m',
          if (ConditionAptitudeAnalyzer.surfaceOf(debut.distance) !=
              ConditionAptitudeAnalyzer.surfaceOf(currentDistanceLabel))
            '${ConditionAptitudeAnalyzer.surfaceOf(debut.distance)}→${ConditionAptitudeAnalyzer.surfaceOf(currentDistanceLabel)}',
        ];
        text += '（${notes.join('・')}）';
      }
      lines.add(TraitLine('距離', text));
    } else if (debut == null && currentCourse != null) {
      lines.add(TraitLine('距離', '今回 $currentCourse（初出走）'));
    }

    // 血統（馬名だけ）
    String? clean(String? s) {
      final t = s?.trim() ?? '';
      return t.isEmpty ? null : t;
    }

    final pedigree = <String>[
      if (clean(sireName) != null) '父 ${clean(sireName)}',
      if (clean(damSireName) != null) '母父 ${clean(damSireName)}',
      if (clean(damDamName) != null) '母母 ${clean(damDamName)}',
    ];
    if (pedigree.isNotEmpty) lines.add(TraitLine('血統', pedigree.join(' / ')));

    return lines;
  }

  // ---- 得意条件 ----

  static String _rangeText(double lo, double hi, String unit) {
    final a = lo.toStringAsFixed(1);
    final b = hi.toStringAsFixed(1);
    return a == b ? '$a$unit' : '$a〜$b$unit';
  }

  /// 馬場状態の頭の1文字（「稍重」と「稍」をそろえる）。空なら null
  static String? _condKey(String? s) {
    final t = s?.trim() ?? '';
    return t.isEmpty ? null : t.substring(0, 1);
  }

  /// 好走した走の値の幅（最小〜最大）と、その幅に入る全部の走の着度数。好走が2走未満なら null
  static ({double lo, double hi, RankTally tally})? _rangeOf(List<(HorseRaceRecord, double)> runs) {
    final good = [
      for (final e in runs)
        if ((int.tryParse(e.$1.rank) ?? 99) <= 3) e.$2
    ];
    if (good.length < minRuns) return null;
    final lo = good.reduce((a, b) => a < b ? a : b);
    final hi = good.reduce((a, b) => a > b ? a : b);
    final inRange = [
      for (final e in runs)
        if (e.$2 >= lo && e.$2 <= hi) e.$1
    ];
    return (lo: lo, hi: hi, tally: ConditionAptitudeAnalyzer.rankTallyOf(inRange));
  }

  /// 得意条件。[records] はこの馬の過去走（レース日より前）
  static StrengthSummary strengthsOf(
    List<HorseRaceRecord> records, {
    Map<String, TrackConditionRecord?> trackConditions = const {},
    StrengthCurrent current = const StrengthCurrent(),
  }) {
    final counted = records.where((r) => isCountedStart(r.rank)).toList();
    if (counted.length < minStarts) return StrengthSummary(starts: counted.length, items: const []);
    final overall = ConditionAptitudeAnalyzer.rankTallyOf(counted).showRate;

    final items = <StrengthItem>[];

    // 1つのキーでまとめて、得意だけを残す
    void addGrouped(
      String axis,
      String? Function(HorseRaceRecord) keyOf,
      bool Function(String key) isCurrentKey,
    ) {
      final grouped = <String, List<HorseRaceRecord>>{};
      for (final r in counted) {
        final k = keyOf(r);
        if (k == null) continue;
        grouped.putIfAbsent(k, () => <HorseRaceRecord>[]).add(r);
      }
      for (final e in grouped.entries) {
        final t = ConditionAptitudeAnalyzer.rankTallyOf(e.value);
        if (!isStrong(t, overall)) continue;
        items.add(StrengthItem(axis: axis, label: e.key, tally: t, isCurrent: isCurrentKey(e.key)));
      }
    }

    String? flatSurface(HorseRaceRecord r) {
      final s = ConditionAptitudeAnalyzer.surfaceOf(r.distance);
      return (s == '芝' || s == 'ダ') ? s : null;
    }

    final currentCourse = current.distanceLabel == null ? null : _courseText(current.distanceLabel!);
    final currentSurface =
        current.distanceLabel == null ? null : ConditionAptitudeAnalyzer.surfaceOf(current.distanceLabel!);

    // コース（開催地×距離）
    addGrouped('コース', (r) {
      final venue = ConditionAptitudeAnalyzer.venueLabelOf(r);
      final course = flatSurface(r) == null ? null : _courseText(r.distance);
      if (venue == null || course == null) return null;
      return '$venue $course';
    }, (k) => current.venue != null && currentCourse != null && k == '${current.venue} $currentCourse');

    // 距離（コースの得意と走数が同じなら、同じ走なので出さない）
    final courseItems = List<StrengthItem>.of(items);
    addGrouped('距離', (r) => flatSurface(r) == null ? null : _courseText(r.distance), (k) => k == currentCourse);
    items.removeWhere((i) =>
        i.axis == '距離' &&
        courseItems.any((c) => c.label.endsWith(' ${i.label}') && c.tally.total == i.tally.total));

    // 馬場（芝・ダート別の馬場状態）
    addGrouped('馬場', (r) {
      final s = flatSurface(r);
      final c = r.trackCondition.trim();
      if (s == null || c.isEmpty) return null;
      return '$s・$c';
    }, (k) {
      final cur = _condKey(current.trackCondition);
      if (currentSurface == null || cur == null) return false;
      final parts = k.split('・');
      return parts.length == 2 && parts[0] == currentSurface && _condKey(parts[1]) == cur;
    });

    // クッション値（芝）・含水率（ダ。ゴール前）: 好走した走の幅と、その幅に入る全部の走の成績
    final cushionRuns = <(HorseRaceRecord, double)>[];
    final moistureRuns = <(HorseRaceRecord, double)>[];
    for (final r in counted) {
      final tc = trackConditions[r.raceId];
      if (tc == null) continue;
      final s = flatSurface(r);
      if (s == '芝' && tc.cushionValue != null) cushionRuns.add((r, tc.cushionValue!));
      if (s == 'ダ' && tc.moistureDirtGoal != null) moistureRuns.add((r, tc.moistureDirtGoal!));
    }
    final cushion = _rangeOf(cushionRuns);
    if (cushion != null && isStrong(cushion.tally, overall)) {
      final cv = current.cushionValue;
      items.add(StrengthItem(
        axis: 'クッション値',
        label: _rangeText(cushion.lo, cushion.hi, ''),
        tally: cushion.tally,
        isCurrent: currentSurface == '芝' && cv != null && cv >= cushion.lo && cv <= cushion.hi,
      ));
    }
    final moisture = _rangeOf(moistureRuns);
    if (moisture != null && isStrong(moisture.tally, overall)) {
      final mv = current.moistureDirtGoal;
      items.add(StrengthItem(
        axis: '含水率',
        label: _rangeText(moisture.lo, moisture.hi, '%'),
        tally: moisture.tally,
        isCurrent: currentSurface == 'ダ' && mv != null && mv >= moisture.lo && mv <= moisture.hi,
      ));
    }

    // 回り
    addGrouped('回り', (r) {
      if (flatSurface(r) == null) return null;
      final d = ConditionAptitudeAnalyzer.directionOf(r.venue);
      return d == null ? null : '$d回り';
    }, (k) => current.direction != null && k == '${current.direction}回り');

    // 脚質
    addGrouped('脚質', ConditionAptitudeAnalyzer.legStyleOf, (_) => false);

    // 軸の順 → 複勝率 → 勝率 → 走数（大きい順）→ 名前
    items.sort((a, b) {
      final ax = axisOrder.indexOf(a.axis).compareTo(axisOrder.indexOf(b.axis));
      if (ax != 0) return ax;
      final s = b.tally.showRate.compareTo(a.tally.showRate);
      if (s != 0) return s;
      final w = b.tally.winRate.compareTo(a.tally.winRate);
      if (w != 0) return w;
      final n = b.tally.total.compareTo(a.tally.total);
      if (n != 0) return n;
      return a.label.compareTo(b.label);
    });

    return StrengthSummary(starts: counted.length, items: items);
  }
}
