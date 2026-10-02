// lib/logic/horse_circumstance.dart

// [追加] 陣営の本気度指数 実施順5 Step2: 出走馬ごとの「事情」（収得賞金・クラス・格上挑戦・同クラス滞在走数・
// 重賞2着昇級・出走馬中の賞金順位・遠征・3歳未勝利の期限）を出す純粋関数。
// 収得賞金は earned_prize_calculator.dart、所属は trainer_affiliation.dart を使う。DB・画面・通信には触れない (v.2026.10.3+26100302)

import 'package:hetaumakeiba_v2/logic/earned_prize_calculator.dart';
import 'package:hetaumakeiba_v2/logic/race_classification.dart';
import 'package:hetaumakeiba_v2/logic/trainer_affiliation.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';

/// 遠征の判定（JRA-VAN TARGET の定義）。
enum ExpeditionStatus {
  /// 遠征（栗東の馬が東京・中山、美浦の馬が京都・阪神）
  expedition,

  /// 地元（美浦の馬が東京・中山、栗東の馬が京都・阪神）
  home,

  /// ローカル場（札幌・函館・福島・新潟・中京・小倉）。遠征とは呼ばない
  localVenue,

  /// 対象外（地方・海外・所属不明の馬、JRA以外のレース）
  notApplicable,
}

/// 所属と競馬場コードから遠征を判定する。
ExpeditionStatus expeditionStatusOf(
  TrainerAffiliation affiliation,
  String venueCode,
) {
  if (affiliation != TrainerAffiliation.miho &&
      affiliation != TrainerAffiliation.ritto) {
    return ExpeditionStatus.notApplicable;
  }
  switch (venueCode) {
    case '05':
    case '06':
      return affiliation == TrainerAffiliation.ritto
          ? ExpeditionStatus.expedition
          : ExpeditionStatus.home;
    case '08':
    case '09':
      return affiliation == TrainerAffiliation.miho
          ? ExpeditionStatus.expedition
          : ExpeditionStatus.home;
    case '01':
    case '02':
    case '03':
    case '04':
    case '07':
    case '10':
      return ExpeditionStatus.localVenue;
    default:
      return ExpeditionStatus.notApplicable;
  }
}

/// 出走馬の所属。出馬表の所属が空や読めないときは調教師名（「地方榎屋充」「海外イプ」など）で読む。
TrainerAffiliation affiliationOfHorse(PredictionHorseDetail horse) {
  final byAffiliation = parseTrainerAffiliation(horse.trainerAffiliation);
  if (byAffiliation != TrainerAffiliation.unknown) return byAffiliation;
  return parseTrainerAffiliation(horse.trainerName);
}

/// 実際に出走した走か（着順が数字、または中止・失格）。取消・除外・空は出走ではない。
bool isRaceStart(HorseRaceRecord record) {
  final rank = record.rank.trim();
  if (RegExp(r'^\d').hasMatch(rank)) return true;
  return rank == '中' || rank == '失';
}

/// 平地の走か（距離が「障」で始まらない）。
bool isFlatRecord(HorseRaceRecord record) {
  return !record.distance.trim().startsWith('障');
}

/// 金額でのクラス（earnedPrizeClassOf）が最後に上がった走。上がったことが無ければ null。
/// [entries] は日付の古い順（EarnedPrizeResult.entries）。金額が分からない走はクラスを変えない。
EarnedPrizeEntry? lastClassPromotionOf(List<EarnedPrizeEntry> entries) {
  var total = 0;
  EarnedPrizeEntry? last;
  for (final entry in entries) {
    final amount = entry.amountInThousandYen;
    if (amount == null || amount <= 0) continue;
    final before = earnedPrizeClassOf(total);
    total += amount;
    if (earnedPrizeClassOf(total) != before) last = entry;
  }
  return last;
}

/// 重賞の2着か（中央の重賞・外国の重賞・地方のJpn交流重賞の2着）。
/// 地方所属の時期の重賞ではない2着は含めない。
bool isGradedSecondPlace(EarnedPrizeEntry entry) {
  if (entry.rank != 2) return false;
  switch (entry.source) {
    case EarnedPrizeSource.jra:
    case EarnedPrizeSource.foreign:
      return true;
    case EarnedPrizeSource.local:
      return entry.raceName.contains('(Jpn');
  }
}

/// [after] より後（同じ日は含まない）・[before] より前の、平地の出走数。[after] が null なら最初から数える。
int countFlatStartsBetween(
  List<HorseRaceRecord> records, {
  DateTime? after,
  required DateTime before,
}) {
  var count = 0;
  for (final record in records) {
    final date = parseEarnedPrizeDate(record.date);
    if (date == null) continue;
    if (!date.isBefore(before)) continue;
    if (after != null && !date.isAfter(after)) continue;
    if (!isRaceStart(record) || !isFlatRecord(record)) continue;
    count++;
  }
  return count;
}

/// 馬IDの先頭4桁（生まれ年）。読めなければ null。
int? birthYearOfHorseId(String horseId) {
  final id = horseId.trim();
  if (id.length < 4) return null;
  return int.tryParse(id.substring(0, 4));
}

/// 出走馬1頭の「事情」。
class HorseCircumstance {
  final String horseId;
  final int horseNumber;
  final String horseName;

  /// 出走取消か（賞金順位・頭数から外す）
  final bool isScratched;

  /// 判定できるか。過去走がDBに1件も無く、新馬戦・未勝利戦でもないときは false
  /// （過去走を取得していない馬を「未勝利」と誤判定しないため）
  final bool canJudge;

  /// 収得賞金の計算結果（判定できないときは null）
  final EarnedPrizeResult? prize;

  /// 馬のクラス（年齢の区分を考えたクラス。判定できないときは null）
  final EarnedPrizeClass? horseClass;

  /// レースの段 − 馬の段。正なら格上挑戦、負なら馬のクラスがレースより上（要確認）。
  /// 判定できない・レースのクラスが読めないときは null
  final int? classGap;

  /// 格上挑戦か（classGap > 0）
  final bool isClassChallenge;

  /// 馬のクラスがレースのクラスより上（classGap < 0）。地方移籍から戻った馬など、要確認の印
  final bool needsCheck;

  /// 金額でのクラスが最後に上がった日（上がったことが無ければ null）
  final DateTime? classReachedDate;

  /// 同クラス滞在走数（クラスが最後に上がった走より後の平地の出走数。上がったことが無ければデビューからの数）
  final int? startsSinceClassReached;

  /// 最後にクラスが上がったのが重賞2着の加算だったか
  final bool promotedByGradedSecond;

  /// 賞金順位に使った賞金（千円。基準はレースの prizeBasis）
  final int? rankingPrizeInThousandYen;

  /// 出走馬中の賞金順位（1始まり・同額は同順位）。取消・判定できない馬は null
  final int? prizeRank;

  final TrainerAffiliation affiliation;
  final ExpeditionStatus expedition;

  /// 3歳未勝利の期限が近いか（3歳・未勝利クラスで、7〜9月のレース）
  final bool isMaidenDeadline;

  const HorseCircumstance({
    required this.horseId,
    required this.horseNumber,
    required this.horseName,
    required this.isScratched,
    required this.canJudge,
    required this.prize,
    required this.horseClass,
    required this.classGap,
    required this.isClassChallenge,
    required this.needsCheck,
    required this.classReachedDate,
    required this.startsSinceClassReached,
    required this.promotedByGradedSecond,
    required this.rankingPrizeInThousandYen,
    required this.prizeRank,
    required this.affiliation,
    required this.expedition,
    required this.isMaidenDeadline,
  });
}

/// レース全体の「事情」。
class RaceCircumstances {
  final RaceClassification race;

  /// 事情を出したか。JRAの平地で開催日が読めるレースだけ true（false のとき horses は空）
  final bool isSupported;

  /// 出走馬ごとの事情（入力の順）
  final List<HorseCircumstance> horses;

  /// 賞金順位を付けた頭数（取消・判定できない馬を除く）
  final int rankedCount;

  /// 過去走が無く判定できなかった頭数（取消を除く）
  final int unjudgedCount;

  /// 格上挑戦の頭数（取消を除く）
  final int classChallengeCount;

  const RaceCircumstances({
    required this.race,
    required this.isSupported,
    required this.horses,
    required this.rankedCount,
    required this.unjudgedCount,
    required this.classChallengeCount,
  });
}

class _Work {
  final PredictionHorseDetail horse;
  final bool canJudge;
  final EarnedPrizeResult? prize;
  final EarnedPrizeClass? horseClass;
  final int? classGap;
  final EarnedPrizeEntry? promotion;
  final int? startsSinceClassReached;
  final int? rankingPrize;
  final TrainerAffiliation affiliation;
  final bool isMaidenDeadline;

  _Work({
    required this.horse,
    required this.canJudge,
    required this.prize,
    required this.horseClass,
    required this.classGap,
    required this.promotion,
    required this.startsSinceClassReached,
    required this.rankingPrize,
    required this.affiliation,
    required this.isMaidenDeadline,
  });

  bool get isRanked => !horse.isScratched && canJudge && rankingPrize != null;
}

/// 出走馬ごとの「事情」を出す。
///
/// [race] 今回レースの区分（classifyRace の結果）。
/// [horses] 出馬表の出走馬（取消を含む）。
/// [recordsByHorseId] 馬ID → その馬の過去走（horse_performance の行・順不同）。
///   レース当日以降の走は数えない（収得賞金の計算と同じ）。
RaceCircumstances buildRaceCircumstances({
  required RaceClassification race,
  required List<PredictionHorseDetail> horses,
  required Map<String, List<HorseRaceRecord>> recordsByHorseId,
}) {
  final asOf = race.date;
  if (asOf == null || !race.isJra || race.isJump) {
    return RaceCircumstances(
      race: race,
      isSupported: false,
      horses: const [],
      rankedCount: 0,
      unjudgedCount: 0,
      classChallengeCount: 0,
    );
  }

  final isMaidenRace = race.classLevel == RaceClassLevel.newcomer ||
      race.classLevel == RaceClassLevel.maiden;
  final raceStep = race.classStep;

  final works = <_Work>[];
  for (final horse in horses) {
    final records =
        recordsByHorseId[horse.horseId] ?? const <HorseRaceRecord>[];
    final affiliation = affiliationOfHorse(horse);
    final canJudge = records.isNotEmpty || isMaidenRace;
    if (!canJudge) {
      works.add(_Work(
        horse: horse,
        canJudge: false,
        prize: null,
        horseClass: null,
        classGap: null,
        promotion: null,
        startsSinceClassReached: null,
        rankingPrize: null,
        affiliation: affiliation,
        isMaidenDeadline: false,
      ));
      continue;
    }

    final birthYear = birthYearOfHorseId(horse.horseId);
    final prize = calculateEarnedPrize(
      records: records,
      asOf: asOf,
      birthYear: birthYear,
    );
    final horseClass = prize.classAtAsOf;
    final classGap = raceStep == null ? null : raceStep - horseClass.index;
    final promotion = lastClassPromotionOf(prize.entries);
    final startsSinceClassReached = countFlatStartsBetween(
      records,
      after: promotion?.date,
      before: asOf,
    );

    final int rankingPrize;
    switch (race.prizeBasis) {
      case PrizeRankingBasis.earned:
        rankingPrize = prize.totalInThousandYen;
        break;
      case PrizeRankingBasis.decision:
        rankingPrize = prize.decisionPrizeInThousandYen;
        break;
      case PrizeRankingBasis.springClassic:
        rankingPrize = prize.springClassicInThousandYen;
        break;
    }

    final isMaidenDeadline = birthYear != null &&
        asOf.year - birthYear == 3 &&
        horseClass == EarnedPrizeClass.maiden &&
        asOf.month >= 7 &&
        asOf.month <= 9;

    works.add(_Work(
      horse: horse,
      canJudge: true,
      prize: prize,
      horseClass: horseClass,
      classGap: classGap,
      promotion: promotion,
      startsSinceClassReached: startsSinceClassReached,
      rankingPrize: rankingPrize,
      affiliation: affiliation,
      isMaidenDeadline: isMaidenDeadline,
    ));
  }

  final ranked = works.where((w) => w.isRanked).toList();
  final result = <HorseCircumstance>[];
  for (final w in works) {
    int? prizeRank;
    if (w.isRanked) {
      prizeRank = 1 +
          ranked.where((other) => other.rankingPrize! > w.rankingPrize!).length;
    }
    final gap = w.classGap;
    result.add(HorseCircumstance(
      horseId: w.horse.horseId,
      horseNumber: w.horse.horseNumber,
      horseName: w.horse.horseName,
      isScratched: w.horse.isScratched,
      canJudge: w.canJudge,
      prize: w.prize,
      horseClass: w.horseClass,
      classGap: gap,
      isClassChallenge: gap != null && gap > 0,
      needsCheck: gap != null && gap < 0,
      classReachedDate: w.promotion?.date,
      startsSinceClassReached: w.startsSinceClassReached,
      promotedByGradedSecond:
          w.promotion != null && isGradedSecondPlace(w.promotion!),
      rankingPrizeInThousandYen: w.rankingPrize,
      prizeRank: prizeRank,
      affiliation: w.affiliation,
      expedition: expeditionStatusOf(w.affiliation, race.venueCode),
      isMaidenDeadline: w.isMaidenDeadline,
    ));
  }

  return RaceCircumstances(
    race: race,
    isSupported: true,
    horses: result,
    rankedCount: ranked.length,
    unjudgedCount:
        result.where((h) => !h.isScratched && !h.canJudge).length,
    classChallengeCount:
        result.where((h) => !h.isScratched && h.isClassChallenge).length,
  );
}
