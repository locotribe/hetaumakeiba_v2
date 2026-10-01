// lib/logic/earned_prize_calculator.dart

// [追加] 陣営の本気度指数 実施順3: 馬の過去走（horse_performance）から、あるレース日時点の
// 収得賞金・クラス・春の3歳GⅠ用の賞金・古馬の出走馬決定賞金を計算する純粋関数。
// DB・画面・通信には触れない。規則の根拠は memory/収得賞金_設計書.md の2章 (v.2026.10.2+26100207)

import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';

/// 金額の単位は、この計算ではすべて「千円」の整数（1万円 = 10）。
/// netkeiba の賞金列（万円・小数1桁）を誤差なく扱うため。
const int kThousandYenPerMan = 10;

/// 走った競走の主催。
enum EarnedPrizeSource {
  /// 中央競馬（開催が「回＋JRAの競馬場＋日」の形）
  jra,

  /// 地方競馬（JRA以外で、レースIDがある）
  local,

  /// 外国（JRA以外で、レースIDが空）
  foreign,
}

/// 中央競馬の競走の区分（レース名から判定）。
enum EarnedPrizeRaceClass {
  newcomer, // 新馬
  maiden, // 未勝利
  win1, // 1勝クラス（旧 500万下）
  win2, // 2勝クラス（旧 1000万下）
  win3, // 3勝クラス（旧 1600万下）
  open, // オープン特別（(OP)・「オープン」）
  listed, // リステッド（(L)）
  g3, // (GIII)
  g2, // (GII)
  g1, // (GI)
  unknown, // 判定できない（地方・外国の競走もこれ）
}

/// 年齢による競走の区分。
enum EarnedPrizeAgeGroup {
  /// 2歳
  two,

  /// 3歳（1月1日〜6月1日。ダービーは5月26日〜6月1日の日曜で、翌週から3歳以上の区分になる）
  threeSpring,

  /// 3歳（6月2日以降）と4歳以上。3(4)歳以上の区分
  threeUp,
}

/// 収得賞金で決まるクラス。
enum EarnedPrizeClass {
  /// 収得賞金 0
  maiden,

  /// 500万円以下
  win1,

  /// 500万円超〜1,000万円以下
  win2,

  /// 1,000万円超〜1,600万円以下
  win3,

  /// 1,600万円超
  open,
}

/// 加算額の求め方。
enum EarnedPrizeBasis {
  /// 区分ごとの固定額
  fixed,

  /// 本賞金（引数で渡された値）の半額
  halfOfBasePrize,

  /// 賞金列（付加賞込み）の半額で推定
  halfOfPrizeEstimated,

  /// 地方の競走の表（半額／一律400万・160万／そのまま）
  localTable,

  /// 金額が分からない（外国、または賞金列が空）
  unknown,
}

/// 収得賞金に算入した1走。
class EarnedPrizeEntry {
  final DateTime date;
  final String raceId;
  final String raceName;
  final String venue;

  /// 着順（1 または 2）
  final int rank;
  final EarnedPrizeSource source;
  final EarnedPrizeRaceClass raceClass;
  final EarnedPrizeAgeGroup ageGroup;

  /// 芝の競走か（距離が「芝」で始まる）
  final bool isTurf;

  /// GⅠか（中央の(GI)・地方の(JpnI)・外国の(GI)/(G1)）。出走馬決定賞金の期間(2)に使う
  final bool isGradeOne;

  /// 加算額（千円）。分からないときは null
  final int? amountInThousandYen;
  final EarnedPrizeBasis basis;

  const EarnedPrizeEntry({
    required this.date,
    required this.raceId,
    required this.raceName,
    required this.venue,
    required this.rank,
    required this.source,
    required this.raceClass,
    required this.ageGroup,
    required this.isTurf,
    required this.isGradeOne,
    required this.amountInThousandYen,
    required this.basis,
  });

  /// 金額が分からない走か
  bool get isUnknown => amountInThousandYen == null;

  /// 付加賞込みの賞金から推定した走か
  bool get isEstimated => basis == EarnedPrizeBasis.halfOfPrizeEstimated;

  /// 春の3歳GⅠ（2025年以降）の賞金に入る走か。
  /// 芝の「中央のオープン競走（OP・L・重賞）・1勝クラス」と芝の外国の競走だけ。
  /// 新馬・未勝利・2勝・3勝クラス・ダート・地方（地方主催の芝を含む）は入らない。
  bool get countsForSpringClassic {
    if (!isTurf) return false;
    if (source == EarnedPrizeSource.foreign) return true;
    if (source != EarnedPrizeSource.jra) return false;
    switch (raceClass) {
      case EarnedPrizeRaceClass.win1:
      case EarnedPrizeRaceClass.open:
      case EarnedPrizeRaceClass.listed:
      case EarnedPrizeRaceClass.g3:
      case EarnedPrizeRaceClass.g2:
      case EarnedPrizeRaceClass.g1:
        return true;
      default:
        return false;
    }
  }
}

/// 計算結果。
class EarnedPrizeResult {
  /// 基準日（この日より前の走だけを数えた）
  final DateTime asOf;

  /// 基準日時点の年齢の区分
  final EarnedPrizeAgeGroup ageGroupAtAsOf;

  /// 算入した走（日付の古い順）。金額が分からない走も含む
  final List<EarnedPrizeEntry> entries;

  /// 出走馬決定賞金の期間(1)・(2)の始まり（この日を含む）
  final DateTime decisionPeriod1Start;
  final DateTime decisionPeriod2Start;

  const EarnedPrizeResult({
    required this.asOf,
    required this.ageGroupAtAsOf,
    required this.entries,
    required this.decisionPeriod1Start,
    required this.decisionPeriod2Start,
  });

  static int _sum(Iterable<EarnedPrizeEntry> list) {
    var total = 0;
    for (final e in list) {
      total += e.amountInThousandYen ?? 0;
    }
    return total;
  }

  /// 平地の収得賞金（千円）。金額が分からない走は0として足す
  int get totalInThousandYen => _sum(entries);

  /// 金額だけで決まるクラス
  EarnedPrizeClass get amountClass => earnedPrizeClassOf(totalInThousandYen);

  /// 年齢の区分を考えたクラス。2歳と3歳の6月1日までは
  /// 「未勝利・1勝・オープン」の3区分（500万円を超えればオープン）
  EarnedPrizeClass get classAtAsOf {
    final byAmount = amountClass;
    if (ageGroupAtAsOf == EarnedPrizeAgeGroup.threeUp) return byAmount;
    if (byAmount == EarnedPrizeClass.maiden ||
        byAmount == EarnedPrizeClass.win1) {
      return byAmount;
    }
    return EarnedPrizeClass.open;
  }

  /// 春の3歳GⅠ用の賞金（千円）。基準日が2025年以降なら芝の規定の合計
  /// （[EarnedPrizeEntry.countsForSpringClassic]）、2024年以前なら収得賞金の合計
  int get springClassicInThousandYen {
    if (asOf.year >= 2025) {
      return _sum(entries.where((e) => e.countsForSpringClassic));
    }
    return totalInThousandYen;
  }

  /// 古馬の出走馬決定賞金（千円）。
  /// 収得賞金＋期間(1)の全競走の加算額＋期間(2)のGⅠの加算額
  int get decisionPrizeInThousandYen {
    final period1 = entries.where((e) => !e.date.isBefore(decisionPeriod1Start));
    final period2 = entries
        .where((e) => e.isGradeOne && !e.date.isBefore(decisionPeriod2Start));
    return totalInThousandYen + _sum(period1) + _sum(period2);
  }

  /// 金額が分からない外国の走の数
  int get unknownForeignCount => entries
      .where((e) => e.isUnknown && e.source == EarnedPrizeSource.foreign)
      .length;

  /// 春の3歳GⅠ用の賞金に入るはずの、金額が分からない外国の走の数（基準日が2025年以降のとき）
  int get springClassicUnknownForeignCount {
    if (asOf.year < 2025) return unknownForeignCount;
    return entries
        .where((e) =>
            e.isUnknown &&
            e.source == EarnedPrizeSource.foreign &&
            e.countsForSpringClassic)
        .length;
  }

  /// 外国以外で金額が分からない走の数（賞金列が空）
  int get unknownOtherCount => entries
      .where((e) => e.isUnknown && e.source != EarnedPrizeSource.foreign)
      .length;

  /// 付加賞込みの賞金から推定した走があるか
  bool get hasEstimated => entries.any((e) => e.isEstimated);
}

/// 収得賞金（千円）からクラスを決める。
EarnedPrizeClass earnedPrizeClassOf(int totalInThousandYen) {
  if (totalInThousandYen <= 0) return EarnedPrizeClass.maiden;
  if (totalInThousandYen <= 5000) return EarnedPrizeClass.win1;
  if (totalInThousandYen <= 10000) return EarnedPrizeClass.win2;
  if (totalInThousandYen <= 16000) return EarnedPrizeClass.win3;
  return EarnedPrizeClass.open;
}

/// あるレース日時点の収得賞金などを計算する。
///
/// [records] その馬の過去走（horse_performance の行）。並び順は問わない。
/// [asOf] 基準日。この日より前（同じ日は含まない）の走だけを数える。時刻は無視する。
/// [birthYear] 生まれ年。省略すると馬IDの先頭4桁から取る（取れなければ年齢の区分は3歳以上扱い）。
/// [basePrizeManByRaceId] レースID → [1着の本賞金, 2着の本賞金]（万円）。
///   渡されたレースは、重賞の半額を賞金列ではなくこの値から求める（推定の印が付かない）。
/// [decisionPeriod1Start] / [decisionPeriod2Start] 出走馬決定賞金の期間の始まり（この日を含む）。
///   省略すると、基準日の1年前・2年前の翌週（358日前・723日前）。前年・前々年の同じ節を外す近似。
EarnedPrizeResult calculateEarnedPrize({
  required List<HorseRaceRecord> records,
  required DateTime asOf,
  int? birthYear,
  Map<String, List<int>> basePrizeManByRaceId = const {},
  DateTime? decisionPeriod1Start,
  DateTime? decisionPeriod2Start,
}) {
  final asOfDay = DateTime(asOf.year, asOf.month, asOf.day);
  int? resolvedBirthYear = birthYear;
  if (resolvedBirthYear == null) {
    for (final r in records) {
      if (r.horseId.length >= 4) {
        resolvedBirthYear = int.tryParse(r.horseId.substring(0, 4));
        if (resolvedBirthYear != null) break;
      }
    }
  }

  final entries = <EarnedPrizeEntry>[];
  for (final record in records) {
    final date = parseEarnedPrizeDate(record.date);
    if (date == null || !date.isBefore(asOfDay)) continue;
    final entry = earnedPrizeEntryOf(
      record,
      date: date,
      ageGroup: earnedPrizeAgeGroupOf(date, resolvedBirthYear),
      basePrizeMan: basePrizeManByRaceId[record.raceId],
    );
    if (entry != null) entries.add(entry);
  }
  entries.sort((a, b) => a.date.compareTo(b.date));

  return EarnedPrizeResult(
    asOf: asOfDay,
    ageGroupAtAsOf: earnedPrizeAgeGroupOf(asOfDay, resolvedBirthYear),
    entries: entries,
    decisionPeriod1Start: decisionPeriod1Start ??
        DateTime(asOfDay.year, asOfDay.month, asOfDay.day - 358),
    decisionPeriod2Start: decisionPeriod2Start ??
        DateTime(asOfDay.year, asOfDay.month, asOfDay.day - 723),
  );
}

/// 'YYYY/MM/DD' を日付にする。読めなければ null。
DateTime? parseEarnedPrizeDate(String text) {
  final m = RegExp(r'^(\d{4})/(\d{1,2})/(\d{1,2})').firstMatch(text.trim());
  if (m == null) return null;
  return DateTime(
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
    int.parse(m.group(3)!),
  );
}

/// 日付と生まれ年から年齢の区分を決める。生まれ年が無ければ3歳以上扱い。
EarnedPrizeAgeGroup earnedPrizeAgeGroupOf(DateTime date, int? birthYear) {
  if (birthYear == null) return EarnedPrizeAgeGroup.threeUp;
  final age = date.year - birthYear;
  if (age <= 2) return EarnedPrizeAgeGroup.two;
  if (age == 3 && (date.month < 6 || (date.month == 6 && date.day == 1))) {
    return EarnedPrizeAgeGroup.threeSpring;
  }
  return EarnedPrizeAgeGroup.threeUp;
}

final RegExp _jraVenue =
    RegExp(r'^\d+(札幌|函館|福島|新潟|東京|中山|中京|京都|阪神|小倉)\d+$');

/// 主催を判定する。
EarnedPrizeSource earnedPrizeSourceOf(HorseRaceRecord record) {
  if (_jraVenue.hasMatch(record.venue.trim())) return EarnedPrizeSource.jra;
  if (record.raceId.trim().isEmpty) return EarnedPrizeSource.foreign;
  return EarnedPrizeSource.local;
}

/// 中央競馬の競走の区分をレース名から判定する。
EarnedPrizeRaceClass earnedPrizeRaceClassOf(String raceName) {
  if (raceName.contains('(GIII)')) return EarnedPrizeRaceClass.g3;
  if (raceName.contains('(GII)')) return EarnedPrizeRaceClass.g2;
  if (raceName.contains('(GI)')) return EarnedPrizeRaceClass.g1;
  if (raceName.contains('(L)')) return EarnedPrizeRaceClass.listed;
  if (raceName.contains('(OP)') || raceName.contains('オープン')) {
    return EarnedPrizeRaceClass.open;
  }
  if (raceName.contains('3勝クラス') || raceName.contains('1600万下')) {
    return EarnedPrizeRaceClass.win3;
  }
  if (raceName.contains('2勝クラス') || raceName.contains('1000万下')) {
    return EarnedPrizeRaceClass.win2;
  }
  if (raceName.contains('1勝クラス') || raceName.contains('500万下')) {
    return EarnedPrizeRaceClass.win1;
  }
  if (raceName.contains('新馬')) return EarnedPrizeRaceClass.newcomer;
  if (raceName.contains('未勝利')) return EarnedPrizeRaceClass.maiden;
  return EarnedPrizeRaceClass.unknown;
}

/// 着順の先頭の数字。読めなければ null（取消・除外・中止など）。
int? earnedPrizeRankOf(String rank) {
  final m = RegExp(r'^\d+').firstMatch(rank.trim());
  if (m == null) return null;
  return int.parse(m.group(0)!);
}

/// 賞金列（'1,580.1' など・万円）を千円の整数にする。空や読めなければ null。
int? parsePrizeInThousandYen(String text) {
  final cleaned = text.replaceAll(',', '').trim();
  if (cleaned.isEmpty) return null;
  final value = double.tryParse(cleaned);
  if (value == null) return null;
  return (value * kThousandYenPerMan).round();
}

/// 半額にして10万円未満を切り捨てる（千円の単位で100未満を切り捨て）。
int halfFloorTenMan(int amountInThousandYen) {
  return (amountInThousandYen ~/ 2) ~/ 100 * 100;
}

/// 1走が収得賞金に算入されるなら、その内訳を返す。算入されなければ null。
/// 障害の競走は平地と別計算のため常に null。
EarnedPrizeEntry? earnedPrizeEntryOf(
  HorseRaceRecord record, {
  required DateTime date,
  required EarnedPrizeAgeGroup ageGroup,
  List<int>? basePrizeMan,
}) {
  final distance = record.distance.trim();
  if (distance.startsWith('障') || record.raceName.startsWith('障害')) {
    return null;
  }
  final rank = earnedPrizeRankOf(record.rank);
  if (rank == null || rank < 1 || rank > 2) return null;

  final source = earnedPrizeSourceOf(record);
  final raceName = record.raceName;
  final prize = parsePrizeInThousandYen(record.prizeMoney);
  final isTurf = distance.startsWith('芝');

  var raceClass = EarnedPrizeRaceClass.unknown;
  var isGradeOne = false;
  int? amount;
  var basis = EarnedPrizeBasis.unknown;

  switch (source) {
    case EarnedPrizeSource.jra:
      raceClass = earnedPrizeRaceClassOf(raceName);
      isGradeOne = raceClass == EarnedPrizeRaceClass.g1;
      final isGraded = raceClass == EarnedPrizeRaceClass.g1 ||
          raceClass == EarnedPrizeRaceClass.g2 ||
          raceClass == EarnedPrizeRaceClass.g3;
      // 2着を算入するのは重賞だけ
      if (rank == 2 && !isGraded) return null;
      if (raceClass == EarnedPrizeRaceClass.g3 &&
          ageGroup == EarnedPrizeAgeGroup.two) {
        // 2歳GⅢ: 1着1,600万・2着600万
        amount = rank == 1 ? 16000 : 6000;
        basis = EarnedPrizeBasis.fixed;
      } else if (isGraded) {
        // 2歳GⅠ・GⅡと3歳以上の重賞: その着順の本賞金の半額
        final base = (basePrizeMan != null && basePrizeMan.length >= rank)
            ? basePrizeMan[rank - 1]
            : null;
        if (base != null && base > 0) {
          amount = halfFloorTenMan(base * kThousandYenPerMan);
          basis = EarnedPrizeBasis.halfOfBasePrize;
        } else if (prize != null) {
          amount = halfFloorTenMan(prize);
          basis = EarnedPrizeBasis.halfOfPrizeEstimated;
        }
      } else {
        amount = _jraFixedAmount(raceClass, ageGroup, raceName);
        if (amount == null) return null;
        basis = EarnedPrizeBasis.fixed;
      }
      break;
    case EarnedPrizeSource.local:
      final isJpn = raceName.contains('(JpnI)') ||
          raceName.contains('(JpnII)') ||
          raceName.contains('(JpnIII)');
      isGradeOne = raceName.contains('(JpnI)');
      if (rank == 2) {
        // 2着: Jpnの交流重賞の2着、または地方所属の時期の2着（本賞金100万円以上）。
        // 「交流」と付く Jpn 以外の競走（JRA交流など）は中央所属馬の出走なので算入しない
        if (!isJpn) {
          if (raceName.contains('交流')) return null;
          if (prize == null || prize < 1000) return null;
        }
      }
      if (prize != null) {
        amount = _localAmount(prize, rank);
        basis = EarnedPrizeBasis.localTable;
      }
      break;
    case EarnedPrizeSource.foreign:
      final isGradedForeign = RegExp(r'\(G(I{1,3}|[123])\)').hasMatch(raceName);
      isGradeOne = raceName.contains('(GI)') || raceName.contains('(G1)');
      // 2着は外国の重賞だけ
      if (rank == 2 && !isGradedForeign) return null;
      // 円への換算比率が分からず、賞金列も空なので金額は出さない
      break;
  }

  return EarnedPrizeEntry(
    date: date,
    raceId: record.raceId,
    raceName: raceName,
    venue: record.venue,
    rank: rank,
    source: source,
    raceClass: raceClass,
    ageGroup: ageGroup,
    isTurf: isTurf,
    isGradeOne: isGradeOne,
    amountInThousandYen: amount,
    basis: basis,
  );
}

/// 中央の重賞以外の1着の固定額（千円）。区分が分からなければ null。
int? _jraFixedAmount(
  EarnedPrizeRaceClass raceClass,
  EarnedPrizeAgeGroup ageGroup,
  String raceName,
) {
  switch (raceClass) {
    case EarnedPrizeRaceClass.newcomer:
    case EarnedPrizeRaceClass.maiden:
      return 4000;
    case EarnedPrizeRaceClass.win1:
      return 5000;
    case EarnedPrizeRaceClass.win2:
      return 6000;
    case EarnedPrizeRaceClass.win3:
      return 9000;
    case EarnedPrizeRaceClass.open:
      switch (ageGroup) {
        case EarnedPrizeAgeGroup.two:
          // 九州産馬限定（ひまわり賞）は500万
          return raceName.contains('ひまわり賞') ? 5000 : 6000;
        case EarnedPrizeAgeGroup.threeSpring:
          return 10000;
        case EarnedPrizeAgeGroup.threeUp:
          return 12000;
      }
    case EarnedPrizeRaceClass.listed:
      switch (ageGroup) {
        case EarnedPrizeAgeGroup.two:
          return 8000;
        case EarnedPrizeAgeGroup.threeSpring:
          return 12000;
        case EarnedPrizeAgeGroup.threeUp:
          return 14000;
      }
    default:
      return null;
  }
}

/// 地方の競走の加算額（千円）。
/// 1着: 1,200万以上は半額・400万以上は400万・未満はそのまま。
/// 2着: 480万以上は半額・160万以上は160万・未満はそのまま。
int _localAmount(int prizeInThousandYen, int rank) {
  final halfLine = rank == 1 ? 12000 : 4800;
  final flat = rank == 1 ? 4000 : 1600;
  if (prizeInThousandYen >= halfLine) return halfFloorTenMan(prizeInThousandYen);
  if (prizeInThousandYen >= flat) return flat;
  return prizeInThousandYen;
}
