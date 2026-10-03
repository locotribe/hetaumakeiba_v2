// lib/logic/entry_meaning.dart

// [追加] 陣営の本気度指数: 各馬がこのレースに出てきた「出走の意味」を、実施順3・5の事実
// （収得賞金・クラス・格上挑戦・同クラス滞在走数・賞金順位・遠征・3歳未勝利の期限・間隔・休み明けから何戦目・
// 乗り替わりなど）と同じ馬主・同じ厩舎の出走から、言葉の行のリストにする純粋関数。
// 一覧と書き方は memory/陣営の本気度指数_決定事項.md の11章。DB・画面・通信には触れない (v.2026.10.3+26100305)

import 'package:hetaumakeiba_v2/logic/camp_signals.dart';
import 'package:hetaumakeiba_v2/logic/earned_prize_calculator.dart';
import 'package:hetaumakeiba_v2/logic/horse_circumstance.dart';
import 'package:hetaumakeiba_v2/logic/race_classification.dart';
import 'package:hetaumakeiba_v2/logic/race_interval_analyzer.dart';
import 'package:hetaumakeiba_v2/logic/trainer_affiliation.dart';
import 'package:hetaumakeiba_v2/models/horse_profile_model.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';

/// 同じクラスでの出走がこの数以上なら「◯◯クラスで今回◯走目」を出す（A2）
const int kClassStayStartsToShow = 6;

/// 根拠の印。
enum EntryMeaningBasis {
  /// 賞金・クラスの規則から確実に言えること
  rule,

  /// よく言われること
  general,

  /// 事実だけ（解釈を付けない）
  fact,

  /// 規則の計算の限界（要確認）
  ruleLimit,
}

/// 根拠の印の表示名（「規則」「一般論」「事実」「規則の限界」）。
String entryMeaningBasisLabel(EntryMeaningBasis basis) {
  switch (basis) {
    case EntryMeaningBasis.rule:
      return '規則';
    case EntryMeaningBasis.general:
      return '一般論';
    case EntryMeaningBasis.fact:
      return '事実';
    case EntryMeaningBasis.ruleLimit:
      return '規則の限界';
  }
}

/// 出走の意味の種類（決定事項11章の記号）。
enum EntryMeaningKind {
  /// 過去走を取得していないため判定できない
  unjudged,

  /// A1 昇級初戦
  classPromotionFirstStart,

  /// A2 同じクラスで6走以上（◯走目）
  classStay,

  /// A3 格上挑戦
  classChallenge,

  /// A4 重賞2着の加算で昇級
  gradedSecondPromotion,

  /// A5 賞金順位（春の3歳GⅠ・古馬の重賞）
  prizeRank,

  /// A6 地方の賞金加算でクラス要確認
  classNeedsCheck,

  /// A7 3歳未勝利の期限
  maidenDeadline,

  /// A8 3歳の未勝利戦で初出走・2戦目
  maidenStartCount,

  /// B1 遠征
  expedition,

  /// C1 長期休養明け（180日以上）
  longLayoff,

  /// C2 長めの休み明け（120〜179日）
  longishLayoff,

  /// C3 休み明け（60〜119日）
  layoff,

  /// C4 休み明けから3〜4戦目
  startsAfterLayoff,

  /// C5 間隔が詰まっている（27日以下）
  tightInterval,

  /// D1 前走の騎手が同じレースの別馬に騎乗
  previousJockeyOnOtherHorse,

  /// D2 乗り替わり
  jockeyChange,

  /// D3 主戦騎手の継続騎乗
  mainJockey,

  /// D4 ブリンカー初装着
  firstBlinker,

  /// E1 同じ馬主の馬も出走
  sameOwner,

  /// E2 同じ厩舎の馬も出走
  sameStable,

  /// R1 レース全体: 格上挑戦の頭数
  raceClassChallengeCount,

  /// R2 レース全体: 判定できない頭数
  raceUnjudgedCount,
}

/// 出走の意味の1行。
class EntryMeaningLine {
  final EntryMeaningKind kind;

  /// 事実（数字を含む）
  final String fact;

  /// 解釈（「〜の可能性」）。事実だけの行は null
  final String? interpretation;

  final EntryMeaningBasis basis;

  const EntryMeaningLine({
    required this.kind,
    required this.fact,
    required this.interpretation,
    required this.basis,
  });
}

/// 出走馬1頭の出走の意味。
class HorseEntryMeaning {
  final String horseId;
  final int horseNumber;
  final String horseName;

  /// 出走取消か（取消の馬は lines が空）
  final bool isScratched;

  /// 出す順（A→B→C→D→E）に並んだ行
  final List<EntryMeaningLine> lines;

  const HorseEntryMeaning({
    required this.horseId,
    required this.horseNumber,
    required this.horseName,
    required this.isScratched,
    required this.lines,
  });
}

/// レース全体の出走の意味。
class RaceEntryMeanings {
  /// 出したか。JRAの平地で開催日が読めるレースだけ true（false のとき raceNotes・horses は空）
  final bool isSupported;

  /// レース全体の注記（R1・R2）
  final List<EntryMeaningLine> raceNotes;

  /// 出走馬ごと（入力の順）
  final List<HorseEntryMeaning> horses;

  const RaceEntryMeanings({
    required this.isSupported,
    required this.raceNotes,
    required this.horses,
  });
}

/// 馬のクラス（収得賞金）の表示名。
String earnedPrizeClassLabel(EarnedPrizeClass horseClass) {
  switch (horseClass) {
    case EarnedPrizeClass.maiden:
      return '未勝利';
    case EarnedPrizeClass.win1:
      return '1勝クラス';
    case EarnedPrizeClass.win2:
      return '2勝クラス';
    case EarnedPrizeClass.win3:
      return '3勝クラス';
    case EarnedPrizeClass.open:
      return 'オープン';
  }
}

/// 今回レースのクラスの表示名。オープンは格（GⅠ・GⅡ・GⅢ・リステッド・オープン）で出す。読めなければ空。
String raceClassLabel(RaceClassification race) {
  if (race.classLevel == RaceClassLevel.newcomer) return '新馬';
  if (race.classLevel == RaceClassLevel.maiden) return '未勝利';
  if (race.classLevel == RaceClassLevel.win1) return '1勝クラス';
  if (race.classLevel == RaceClassLevel.win2) return '2勝クラス';
  if (race.classLevel == RaceClassLevel.win3) return '3勝クラス';
  if (race.classLevel != RaceClassLevel.open) return '';
  if (race.grade == RaceGradeLevel.g1) return 'GⅠ';
  if (race.grade == RaceGradeLevel.g2) return 'GⅡ';
  if (race.grade == RaceGradeLevel.g3) return 'GⅢ';
  if (race.grade == RaceGradeLevel.listed) return 'リステッド';
  return 'オープン';
}

/// JRAの主場4場の名前（遠征の行に使う）。それ以外は空。
String expeditionVenueName(String venueCode) {
  switch (venueCode) {
    case '05':
      return '東京';
    case '06':
      return '中山';
    case '08':
      return '京都';
    case '09':
      return '阪神';
    default:
      return '';
  }
}

/// 千円の整数を「4,550万円」「4,550.5万円」の形にする。
String formatManYen(int amountInThousandYen) {
  final man = amountInThousandYen ~/ kThousandYenPerMan;
  final rest = amountInThousandYen % kThousandYenPerMan;
  final digits = man.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  if (rest != 0) buffer.write('.$rest');
  buffer.write('万円');
  return buffer.toString();
}

/// 日付を「2026/10/4」の形にする（RaceIntervalAnalyzer に渡す書式）。
String _slashDate(DateTime date) => '${date.year}/${date.month}/${date.day}';

/// 2歳戦・3歳限定のオープンか（各馬の格上挑戦を出さず、レース全体の注記だけにする）。
bool isClassChallengeCommonRace(RaceClassification race) {
  if (race.ageCondition == RaceAgeCondition.two) return true;
  return race.ageCondition == RaceAgeCondition.three &&
      race.classLevel == RaceClassLevel.open;
}

/// 賞金順位を出すレースか（春の3歳GⅠ、古馬の重賞）。
bool isPrizeRankShownRace(RaceClassification race) {
  if (race.prizeBasis == PrizeRankingBasis.springClassic) return true;
  if (race.prizeBasis != PrizeRankingBasis.decision) return false;
  return race.isGraded;
}

/// 同じレースに出る他の馬の一覧（「3番馬名、5番馬名」）。
String _otherHorsesText(List<PredictionHorseDetail> others) {
  return others.map((h) => '${h.horseNumber}番${h.horseName}').join('、');
}

/// 出走馬ごとの「出走の意味」を出す。
///
/// [circumstances] buildRaceCircumstances の結果（JRAの平地で日付が読めるときだけ出す）。
/// [campSignals] buildCampSignals の結果（馬IDで対応させる。無い馬は間隔・人の行を出さない）。
/// [horses] 出馬表の出走馬（取消を含む）。出す順はこの順。
/// [profilesByHorseId] 馬ID → 競走馬プロフィール（同じ馬主の判定に使う。無い馬は同じ馬主の行を出さない）。
RaceEntryMeanings buildEntryMeanings({
  required RaceCircumstances circumstances,
  required List<HorseCampSignals> campSignals,
  required List<PredictionHorseDetail> horses,
  Map<String, HorseProfile> profilesByHorseId = const {},
}) {
  final race = circumstances.race;
  final raceDate = race.date;
  if (!circumstances.isSupported || raceDate == null) {
    return const RaceEntryMeanings(
      isSupported: false,
      raceNotes: [],
      horses: [],
    );
  }

  final circumstanceById = <String, HorseCircumstance>{
    for (final c in circumstances.horses) c.horseId: c,
  };
  final signalsById = <String, HorseCampSignals>{
    for (final s in campSignals) s.horseId: s,
  };
  final activeHorses = horses.where((h) => !h.isScratched).toList();
  final challengeCommon = isClassChallengeCommonRace(race);
  final raceLabel = raceClassLabel(race);

  final result = <HorseEntryMeaning>[];
  for (final horse in horses) {
    final lines = <EntryMeaningLine>[];
    final circumstance = circumstanceById[horse.horseId];
    if (horse.isScratched || circumstance == null) {
      result.add(HorseEntryMeaning(
        horseId: horse.horseId,
        horseNumber: horse.horseNumber,
        horseName: horse.horseName,
        isScratched: horse.isScratched,
        lines: lines,
      ));
      continue;
    }

    if (!circumstance.canJudge) {
      lines.add(const EntryMeaningLine(
        kind: EntryMeaningKind.unjudged,
        fact: '過去走を取得していないため判定できません',
        interpretation: null,
        basis: EntryMeaningBasis.fact,
      ));
      result.add(HorseEntryMeaning(
        horseId: horse.horseId,
        horseNumber: horse.horseNumber,
        horseName: horse.horseName,
        isScratched: false,
        lines: lines,
      ));
      continue;
    }

    // ---- A クラス・賞金 ----
    final horseClass = circumstance.horseClass;
    final horseClassLabel =
        horseClass == null ? '' : earnedPrizeClassLabel(horseClass);
    final gap = circumstance.classGap;
    final starts = circumstance.startsSinceClassReached;

    // A1 昇級初戦
    if (gap == 0 &&
        circumstance.classReachedDate != null &&
        starts == 0) {
      lines.add(EntryMeaningLine(
        kind: EntryMeaningKind.classPromotionFirstStart,
        fact: '昇級初戦（$horseClassLabelに上がって初めての出走）',
        interpretation: '新しいクラスでの力試しの可能性',
        basis: EntryMeaningBasis.rule,
      ));
    }

    // A2 同じクラスで6走以上（事実だけ）
    if (gap == 0 && starts != null && starts >= kClassStayStartsToShow) {
      lines.add(EntryMeaningLine(
        kind: EntryMeaningKind.classStay,
        fact: '$horseClassLabelで今回${starts + 1}走目',
        interpretation: null,
        basis: EntryMeaningBasis.fact,
      ));
    }

    // A3 格上挑戦（2歳戦・3歳限定のオープンでは出さない）
    if (circumstance.isClassChallenge && !challengeCommon) {
      lines.add(EntryMeaningLine(
        kind: EntryMeaningKind.classChallenge,
        fact: '格上挑戦（収得賞金では$horseClassLabel・今回は$raceLabel）',
        interpretation: '自分のクラスに合う番組が無い・除外を避けた・力試しのどれかの可能性',
        basis: EntryMeaningBasis.rule,
      ));
    }

    // A4 重賞2着の加算で昇級
    final reachedDate = circumstance.classReachedDate;
    if (circumstance.promotedByGradedSecond && reachedDate != null) {
      lines.add(EntryMeaningLine(
        kind: EntryMeaningKind.gradedSecondPromotion,
        fact: '重賞2着の賞金加算でクラスが上がった（${_slashDate(reachedDate)}）',
        interpretation: null,
        basis: EntryMeaningBasis.rule,
      ));
    }

    // A5 賞金順位（春の3歳GⅠ・古馬の重賞）。賞金の額も出す
    final rank = circumstance.prizeRank;
    final rankingPrize = circumstance.rankingPrizeInThousandYen;
    final prize = circumstance.prize;
    if (isPrizeRankShownRace(race) &&
        rank != null &&
        rankingPrize != null &&
        prize != null) {
      final String prizeLabel;
      final int unknownForeign;
      if (race.prizeBasis == PrizeRankingBasis.springClassic) {
        prizeLabel = raceDate.year >= 2025
            ? '春の3歳GⅠ用の賞金（芝）'
            : '春の3歳GⅠ用の賞金（収得賞金）';
        unknownForeign = prize.springClassicUnknownForeignCount;
      } else {
        prizeLabel = '出走馬決定賞金';
        unknownForeign = prize.unknownForeignCount;
      }
      final notes = <String>[
        '${circumstances.rankedCount}頭中$rank位',
        if (prize.hasEstimated) '重賞の半額は推定を含む',
        if (unknownForeign > 0) '外国$unknownForeign走は金額不明',
      ];
      lines.add(EntryMeaningLine(
        kind: EntryMeaningKind.prizeRank,
        fact: '$prizeLabel ${formatManYen(rankingPrize)}（${notes.join('・')}）',
        interpretation: null,
        basis: EntryMeaningBasis.fact,
      ));
    }

    // A6 クラス要確認
    if (circumstance.needsCheck) {
      lines.add(EntryMeaningLine(
        kind: EntryMeaningKind.classNeedsCheck,
        fact: '収得賞金のクラス（$horseClassLabel）が今回のレース（$raceLabel）より上',
        interpretation: '地方の賞金加算を含むため要確認',
        basis: EntryMeaningBasis.ruleLimit,
      ));
    }

    // A7 3歳未勝利の期限
    if (circumstance.isMaidenDeadline) {
      lines.add(EntryMeaningLine(
        kind: EntryMeaningKind.maidenDeadline,
        fact: '3歳未勝利の期限が近い時期（${raceDate.month}月）',
        interpretation: '勝ち上がりを急ぐ局面の可能性',
        basis: EntryMeaningBasis.rule,
      ));
    }

    // A8 3歳の未勝利戦で初出走・2戦目
    final birthYear = birthYearOfHorseId(horse.horseId);
    if (race.classLevel == RaceClassLevel.maiden &&
        birthYear != null &&
        raceDate.year - birthYear == 3 &&
        horseClass == EarnedPrizeClass.maiden &&
        starts != null) {
      if (starts == 0) {
        lines.add(EntryMeaningLine(
          kind: EntryMeaningKind.maidenStartCount,
          fact: '3歳${raceDate.month}月の初出走',
          interpretation: 'デビューが遅れた事情がある可能性',
          basis: EntryMeaningBasis.general,
        ));
      } else if (starts == 1) {
        lines.add(const EntryMeaningLine(
          kind: EntryMeaningKind.maidenStartCount,
          fact: '3歳の未勝利戦で2戦目',
          interpretation: null,
          basis: EntryMeaningBasis.fact,
        ));
      }
    }

    // ---- B 遠征 ----
    if (circumstance.expedition == ExpeditionStatus.expedition) {
      final from = trainerAffiliationLabel(circumstance.affiliation);
      final to = expeditionVenueName(race.venueCode);
      lines.add(EntryMeaningLine(
        kind: EntryMeaningKind.expedition,
        fact: '$fromから$toへ遠征',
        interpretation: '輸送してまで使う理由がある可能性',
        basis: EntryMeaningBasis.general,
      ));
    }

    // ---- C 間隔 ----
    final signals = signalsById[horse.horseId];
    if (signals != null) {
      final days = signals.daysSinceLastStart;
      final lastDate = signals.lastStartDate;
      final interval = lastDate == null
          ? ''
          : RaceIntervalAnalyzer.formatRaceInterval(
              _slashDate(raceDate), _slashDate(lastDate));
      final startNumber = signals.startNumberSinceLayoff;
      final startOrigin = signals.isCountedFromLayoff ? '休み明け' : 'デビュー';
      final tightSuffix =
          startNumber >= 5 ? '・$startOriginから$startNumber戦目' : '';
      switch (signals.restCategory) {
        case RestCategory.longLayoff:
          lines.add(EntryMeaningLine(
            kind: EntryMeaningKind.longLayoff,
            fact: '長期休養明け（$interval・$days日ぶり）',
            interpretation: '叩き台の可能性',
            basis: EntryMeaningBasis.general,
          ));
          break;
        case RestCategory.longishLayoff:
          lines.add(EntryMeaningLine(
            kind: EntryMeaningKind.longishLayoff,
            fact: '長めの休み明け（$interval・$days日ぶり）',
            interpretation: null,
            basis: EntryMeaningBasis.fact,
          ));
          break;
        case RestCategory.layoff:
          lines.add(EntryMeaningLine(
            kind: EntryMeaningKind.layoff,
            fact: '休み明け（$interval・$days日ぶり）',
            interpretation: null,
            basis: EntryMeaningBasis.fact,
          ));
          break;
        case RestCategory.tight:
          lines.add(EntryMeaningLine(
            kind: EntryMeaningKind.tightInterval,
            fact: '間隔が詰まっている（$interval$tightSuffix）',
            interpretation: null,
            basis: EntryMeaningBasis.fact,
          ));
          break;
        case RestCategory.debut:
        case RestCategory.standard:
        case RestCategory.unknown:
          break;
      }

      // C4 休み明けから3〜4戦目
      if (signals.isCountedFromLayoff &&
          startNumber >= 3 &&
          startNumber <= 4) {
        lines.add(EntryMeaningLine(
          kind: EntryMeaningKind.startsAfterLayoff,
          fact: '休み明けから$startNumber戦目',
          interpretation: '調子が上向く頃の可能性',
          basis: EntryMeaningBasis.general,
        ));
      }

      // ---- D 人・仕上げ ----
      final rides = signals.ridesOnThisHorse;
      final isSeasonedMain = signals.isMainJockey && rides >= 2;
      if (signals.isJockeyChanged == true) {
        final previousName = signals.previousJockeyName ?? '不明';
        final rideText =
            rides == 0 ? 'この馬に初騎乗' : 'この馬に${rides + 1}回目の騎乗';
        final mainText = isSeasonedMain ? '・主戦騎手が戻る' : '';
        lines.add(EntryMeaningLine(
          kind: EntryMeaningKind.jockeyChange,
          fact: '乗り替わり（前走 $previousName → 今回 ${horse.jockey}・$rideText$mainText）',
          interpretation: null,
          basis: EntryMeaningBasis.fact,
        ));
      }

      final otherNumber = signals.previousJockeyRidingHorseNumber;
      if (otherNumber != null) {
        PredictionHorseDetail? other;
        for (final h in activeHorses) {
          if (h.horseNumber == otherNumber && h.horseId != horse.horseId) {
            other = h;
            break;
          }
        }
        if (other != null) {
          lines.add(EntryMeaningLine(
            kind: EntryMeaningKind.previousJockeyOnOtherHorse,
            fact: '前走の騎手（${other.jockey}）は${other.horseNumber}番${other.horseName}に騎乗',
            interpretation: null,
            basis: EntryMeaningBasis.fact,
          ));
        }
      }

      if (signals.isJockeyChanged == false && isSeasonedMain) {
        lines.add(EntryMeaningLine(
          kind: EntryMeaningKind.mainJockey,
          fact: '主戦騎手の継続騎乗（この馬に${rides + 1}回目）',
          interpretation: null,
          basis: EntryMeaningBasis.fact,
        ));
      }

      if (signals.isFirstBlinker) {
        lines.add(const EntryMeaningLine(
          kind: EntryMeaningKind.firstBlinker,
          fact: 'ブリンカー初装着',
          interpretation: '集中力を引き出す工夫の可能性',
          basis: EntryMeaningBasis.general,
        ));
      }
    }

    // ---- E 同じ馬主・同じ厩舎 ----
    final profile = profilesByHorseId[horse.horseId];
    final ownerId = profile?.ownerId.trim() ?? '';
    if (profile != null && ownerId.isNotEmpty) {
      final sameOwner = activeHorses.where((h) {
        if (h.horseId == horse.horseId) return false;
        final otherOwnerId = profilesByHorseId[h.horseId]?.ownerId.trim() ?? '';
        return otherOwnerId == ownerId;
      }).toList();
      if (sameOwner.isNotEmpty) {
        lines.add(EntryMeaningLine(
          kind: EntryMeaningKind.sameOwner,
          fact: '同じ馬主（${profile.ownerName.trim()}）の${_otherHorsesText(sameOwner)}も出走',
          interpretation: null,
          basis: EntryMeaningBasis.fact,
        ));
      }
    }

    final trainerName = horse.trainerName.trim();
    final affiliation = circumstance.affiliation;
    if (trainerName.isNotEmpty && affiliation != TrainerAffiliation.unknown) {
      final sameStable = activeHorses.where((h) {
        if (h.horseId == horse.horseId) return false;
        return h.trainerName.trim() == trainerName &&
            affiliationOfHorse(h) == affiliation;
      }).toList();
      if (sameStable.isNotEmpty) {
        lines.add(EntryMeaningLine(
          kind: EntryMeaningKind.sameStable,
          fact: '同じ厩舎（${trainerAffiliationLabel(affiliation)}・$trainerName）の${_otherHorsesText(sameStable)}も出走',
          interpretation: null,
          basis: EntryMeaningBasis.fact,
        ));
      }
    }

    result.add(HorseEntryMeaning(
      horseId: horse.horseId,
      horseNumber: horse.horseNumber,
      horseName: horse.horseName,
      isScratched: false,
      lines: lines,
    ));
  }

  // ---- レース全体の注記 ----
  final raceNotes = <EntryMeaningLine>[];
  if (circumstances.classChallengeCount > 0) {
    raceNotes.add(EntryMeaningLine(
      kind: EntryMeaningKind.raceClassChallengeCount,
      fact: '格上挑戦が${circumstances.classChallengeCount}頭',
      interpretation: challengeCommon
          ? '2歳戦・3歳限定のオープンは多くの馬が格上挑戦になるため、各馬には出していません'
          : null,
      basis: EntryMeaningBasis.rule,
    ));
  }
  if (circumstances.unjudgedCount > 0) {
    raceNotes.add(EntryMeaningLine(
      kind: EntryMeaningKind.raceUnjudgedCount,
      fact: '過去走を取得していないため判定できない馬が${circumstances.unjudgedCount}頭',
      interpretation: null,
      basis: EntryMeaningBasis.fact,
    ));
  }

  return RaceEntryMeanings(
    isSupported: true,
    raceNotes: raceNotes,
    horses: result,
  );
}
