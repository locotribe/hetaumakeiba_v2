// lib/logic/race_classification.dart

// [追加] 陣営の本気度指数 実施順5 Step1: 今回レースの区分（クラス・格・年齢条件・牝馬限定・斤量・本賞金）を
// 出馬表の値（raceCategory・raceGrade・本賞金）から読む純粋関数。DB・画面・通信には触れない (v.2026.10.3+26100301)

import 'package:hetaumakeiba_v2/models/race_data.dart';

/// レースのクラス（出馬表の raceCategory から読む）。
enum RaceClassLevel {
  /// 新馬
  newcomer,

  /// 未勝利
  maiden,

  /// 1勝クラス（旧 500万下）
  win1,

  /// 2勝クラス（旧 1000万下）
  win2,

  /// 3勝クラス（旧 1600万下）
  win3,

  /// オープン（OP特別・リステッド・重賞）
  open,

  /// 読めない
  unknown,
}

/// オープンの中の格（出馬表の raceGrade から読む）。オープン以外は none。
enum RaceGradeLevel {
  /// オープンではない
  none,

  /// オープン特別（OP、または印なしのオープン）
  openSpecial,

  /// リステッド
  listed,

  /// GⅢ
  g3,

  /// GⅡ
  g2,

  /// GⅠ
  g1,
}

/// 年齢の条件。
enum RaceAgeCondition {
  /// 2歳
  two,

  /// 3歳（3歳限定）
  three,

  /// 3歳以上
  threeUp,

  /// 4歳以上
  fourUp,

  /// 読めない
  unknown,
}

/// 斤量の決め方。
enum RaceWeightRule {
  /// 馬齢
  age,

  /// 定量
  fixed,

  /// 別定
  allowance,

  /// ハンデ
  handicap,

  /// 読めない
  unknown,
}

/// 出走馬中の賞金順位に使う賞金。
enum PrizeRankingBasis {
  /// 収得賞金（条件戦、2歳・3歳限定のオープン、3(4)歳以上のオープン特別）
  earned,

  /// 出走馬決定賞金（3(4)歳以上の重賞・リステッド）
  decision,

  /// 春の3歳GⅠ用の賞金（桜花賞・皐月賞・NHKマイルC・オークス・ダービー）
  springClassic,
}

/// 今回レースの区分。
class RaceClassification {
  final String raceId;

  /// 開催日。読めなければ null
  final DateTime? date;

  /// レースIDの5〜6桁目（競馬場コード。'05' 東京など）。読めなければ空
  final String venueCode;

  /// JRA のレースか（競馬場コード 01〜10）
  final bool isJra;

  /// 障害レースか
  final bool isJump;

  final RaceClassLevel classLevel;
  final RaceGradeLevel grade;
  final RaceAgeCondition ageCondition;

  /// 牝馬限定か（「牡・牝」は限定ではない）
  final bool isFillyMareOnly;

  final RaceWeightRule weightRule;

  /// 1着・2着の本賞金（万円）。出馬表に無ければ null
  final int? basePrize1stMan;
  final int? basePrize2ndMan;

  /// 春の3歳GⅠか（JRA・平地・GⅠ・3歳限定・6月まで）
  final bool isSpringClassic;

  /// 出走馬中の賞金順位に使う賞金
  final PrizeRankingBasis prizeBasis;

  const RaceClassification({
    required this.raceId,
    required this.date,
    required this.venueCode,
    required this.isJra,
    required this.isJump,
    required this.classLevel,
    required this.grade,
    required this.ageCondition,
    required this.isFillyMareOnly,
    required this.weightRule,
    required this.basePrize1stMan,
    required this.basePrize2ndMan,
    required this.isSpringClassic,
    required this.prizeBasis,
  });

  /// クラスの段（新馬・未勝利 0、1勝 1、2勝 2、3勝 3、オープン 4）。読めなければ null。
  /// 収得賞金のクラス（EarnedPrizeClass の index）と同じ段で比べられる
  int? get classStep {
    switch (classLevel) {
      case RaceClassLevel.newcomer:
      case RaceClassLevel.maiden:
        return 0;
      case RaceClassLevel.win1:
        return 1;
      case RaceClassLevel.win2:
        return 2;
      case RaceClassLevel.win3:
        return 3;
      case RaceClassLevel.open:
        return 4;
      case RaceClassLevel.unknown:
        return null;
    }
  }

  /// 重賞（GⅠ・GⅡ・GⅢ）か
  bool get isGraded =>
      grade == RaceGradeLevel.g1 ||
      grade == RaceGradeLevel.g2 ||
      grade == RaceGradeLevel.g3;
}

const Set<String> _kJraVenueCodes = {
  '01',
  '02',
  '03',
  '04',
  '05',
  '06',
  '07',
  '08',
  '09',
  '10',
};

/// 全角数字を半角にする（出馬表の「３歳以上 ２勝クラス」など）。
String normalizeRaceDigits(String text) {
  const fullWidth = '０１２３４５６７８９';
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    final ch = String.fromCharCode(rune);
    final index = fullWidth.indexOf(ch);
    buffer.write(index >= 0 ? '$index' : ch);
  }
  return buffer.toString();
}

/// 「2026年10月4日」「2026/10/04」を日付にする。読めなければ null。
DateTime? parseRaceDate(String text) {
  final m = RegExp(r'(\d{4})\D+(\d{1,2})\D+(\d{1,2})')
      .firstMatch(normalizeRaceDigits(text));
  if (m == null) return null;
  return DateTime(
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
    int.parse(m.group(3)!),
  );
}

/// クラスを読む。raceCategory で読めなければ raceGrade（'1勝'〜'3勝'・'OP'・'L'・'G1'〜'G3'）で読む。
RaceClassLevel raceClassLevelOf(String raceCategory, String raceGrade) {
  final t = normalizeRaceDigits(raceCategory);
  if (t.contains('新馬')) return RaceClassLevel.newcomer;
  if (t.contains('未勝利')) return RaceClassLevel.maiden;
  if (t.contains('1勝クラス') || t.contains('500万下')) {
    return RaceClassLevel.win1;
  }
  if (t.contains('2勝クラス') || t.contains('1000万下')) {
    return RaceClassLevel.win2;
  }
  if (t.contains('3勝クラス') || t.contains('1600万下')) {
    return RaceClassLevel.win3;
  }
  if (t.contains('オープン')) return RaceClassLevel.open;
  switch (raceGrade.trim()) {
    case '1勝':
      return RaceClassLevel.win1;
    case '2勝':
      return RaceClassLevel.win2;
    case '3勝':
      return RaceClassLevel.win3;
    case 'OP':
    case 'L':
    case 'G1':
    case 'G2':
    case 'G3':
      return RaceClassLevel.open;
    default:
      return RaceClassLevel.unknown;
  }
}

/// オープンの中の格を読む。オープン以外は none。印が無いオープンはオープン特別。
RaceGradeLevel raceGradeLevelOf(RaceClassLevel classLevel, String raceGrade) {
  if (classLevel != RaceClassLevel.open) return RaceGradeLevel.none;
  switch (raceGrade.trim()) {
    case 'G1':
      return RaceGradeLevel.g1;
    case 'G2':
      return RaceGradeLevel.g2;
    case 'G3':
      return RaceGradeLevel.g3;
    case 'L':
      return RaceGradeLevel.listed;
    default:
      return RaceGradeLevel.openSpecial;
  }
}

/// 年齢の条件を読む。
RaceAgeCondition raceAgeConditionOf(String raceCategory) {
  final t = normalizeRaceDigits(raceCategory);
  if (t.contains('2歳')) return RaceAgeCondition.two;
  if (t.contains('3歳以上') || t.contains('3歳上')) {
    return RaceAgeCondition.threeUp;
  }
  if (t.contains('4歳以上') || t.contains('4歳上')) {
    return RaceAgeCondition.fourUp;
  }
  if (t.contains('3歳')) return RaceAgeCondition.three;
  return RaceAgeCondition.unknown;
}

/// 斤量の決め方を読む。
RaceWeightRule raceWeightRuleOf(String raceCategory) {
  if (raceCategory.contains('ハンデ')) return RaceWeightRule.handicap;
  if (raceCategory.contains('別定')) return RaceWeightRule.allowance;
  if (raceCategory.contains('定量')) return RaceWeightRule.fixed;
  if (raceCategory.contains('馬齢')) return RaceWeightRule.age;
  return RaceWeightRule.unknown;
}

/// 牝馬限定か（「牡・牝」を除いて「牝」があれば限定）。
bool isFillyMareOnlyOf(String raceCategory) {
  return raceCategory.replaceAll('牡・牝', '').contains('牝');
}

/// 出馬表の値から今回レースの区分を読む（テストしやすいように値を個別に受け取る形）。
RaceClassification classifyRaceFromParts({
  required String raceId,
  required String raceDate,
  String? raceCategory,
  String raceGrade = '',
  String? trackType,
  int? basePrize1st,
  int? basePrize2nd,
}) {
  final category = raceCategory ?? '';
  final id = raceId.trim();
  final venueCode = id.length >= 6 ? id.substring(4, 6) : '';
  final isJra = _kJraVenueCodes.contains(venueCode);
  final isJump =
      (trackType ?? '').trim() == '障' || category.contains('障害');
  final date = parseRaceDate(raceDate);
  final classLevel = raceClassLevelOf(category, raceGrade);
  final grade = raceGradeLevelOf(classLevel, raceGrade);
  final ageCondition = raceAgeConditionOf(category);

  final isSpringClassic = isJra &&
      !isJump &&
      grade == RaceGradeLevel.g1 &&
      ageCondition == RaceAgeCondition.three &&
      date != null &&
      date.month <= 6;

  final isOlderGradedOrListed = (ageCondition == RaceAgeCondition.threeUp ||
          ageCondition == RaceAgeCondition.fourUp) &&
      (grade == RaceGradeLevel.listed ||
          grade == RaceGradeLevel.g3 ||
          grade == RaceGradeLevel.g2 ||
          grade == RaceGradeLevel.g1);

  final PrizeRankingBasis prizeBasis;
  if (isSpringClassic) {
    prizeBasis = PrizeRankingBasis.springClassic;
  } else if (isOlderGradedOrListed) {
    prizeBasis = PrizeRankingBasis.decision;
  } else {
    prizeBasis = PrizeRankingBasis.earned;
  }

  return RaceClassification(
    raceId: id,
    date: date,
    venueCode: venueCode,
    isJra: isJra,
    isJump: isJump,
    classLevel: classLevel,
    grade: grade,
    ageCondition: ageCondition,
    isFillyMareOnly: isFillyMareOnlyOf(category),
    weightRule: raceWeightRuleOf(category),
    basePrize1stMan:
        (basePrize1st != null && basePrize1st > 0) ? basePrize1st : null,
    basePrize2ndMan:
        (basePrize2nd != null && basePrize2nd > 0) ? basePrize2nd : null,
    isSpringClassic: isSpringClassic,
    prizeBasis: prizeBasis,
  );
}

/// 出馬表（PredictionRaceData）から今回レースの区分を読む。
RaceClassification classifyRace(PredictionRaceData race) {
  return classifyRaceFromParts(
    raceId: race.raceId,
    raceDate: race.raceDate,
    raceCategory: race.raceCategory,
    raceGrade: race.raceGrade,
    trackType: race.trackType,
    basePrize1st: race.basePrize1st,
    basePrize2nd: race.basePrize2nd,
  );
}
