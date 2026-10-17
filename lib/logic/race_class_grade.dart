// lib/logic/race_class_grade.dart

// [追加] クラス判定の共通化 Step1: レース名・過去走・今回のレースからクラスの区分を返す共通の部品。各機能はこの区分を自分の数値（人気妙味の係数・Rt の基準値など）に置き換えて使う (v.2026.10.16+26101601)
// [修正] レーティング削除: Rt（能力分析）を削除したので、今の使い手は人気妙味・好走条件・ヒートマップ・路線 (v.2026.10.18+26101803)

import 'package:hetaumakeiba_v2/logic/earned_prize_calculator.dart';
import 'package:hetaumakeiba_v2/logic/race_classification.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';

/// レースのクラスの区分。
enum RaceClassGrade {
  /// GⅠ（JpnⅠ・J・GⅠ・外国のGⅠを含む）
  g1,

  /// GⅡ（JpnⅡ・J・GⅡ・外国のGⅡを含む）
  g2,

  /// GⅢ（JpnⅢ・J・GⅢ・外国のGⅢを含む）
  g3,

  /// リステッド
  listed,

  /// オープン特別
  open,

  /// 3勝クラス（旧 1600万下）
  win3,

  /// 2勝クラス（旧 1000万下）
  win2,

  /// 1勝クラス（旧 500万下）
  win1,

  /// 新馬
  newcomer,

  /// 未勝利
  maiden,

  /// 地方主催の重賞以外（地方の「(重賞)」・地方のOP・地方の条件戦）
  local,

  /// 判定できない
  unknown,
}

/// 括弧のグレード（(GI)・(G1)・(JpnI)・(Jpn1)・(J.GI)・(J.G1) と、その II・2・III・3）。
/// III を先に試すので (GIII) が (GI) にはならない。
final RegExp _kGradeBracket = RegExp(r'\((?:G|Jpn|J\.G)(III|II|I|3|2|1)\)');

/// レース名だけでクラスを判定する（主催は見ない）。
RaceClassGrade raceClassGradeOfName(String raceName) {
  final t = normalizeRaceDigits(raceName);
  final m = _kGradeBracket.firstMatch(t);
  if (m != null) {
    switch (m.group(1)) {
      case 'I':
      case '1':
        return RaceClassGrade.g1;
      case 'II':
      case '2':
        return RaceClassGrade.g2;
      default:
        return RaceClassGrade.g3;
    }
  }
  if (t.contains('(L)') || t.contains('リステッド')) return RaceClassGrade.listed;
  if (t.contains('OP') || t.contains('オープン')) return RaceClassGrade.open;
  if (t.contains('3勝クラス') || t.contains('1600万下')) return RaceClassGrade.win3;
  if (t.contains('2勝クラス') || t.contains('1000万下')) return RaceClassGrade.win2;
  if (t.contains('1勝クラス') || t.contains('500万下')) return RaceClassGrade.win1;
  if (t.contains('新馬')) return RaceClassGrade.newcomer;
  if (t.contains('未勝利')) return RaceClassGrade.maiden;
  return RaceClassGrade.unknown;
}

/// 過去走のクラスを判定する。
/// 重賞（Jpn交流重賞・地方の国際GⅠを含む）は主催に関係なく G1〜G3。
/// それ以外の地方主催の競走は local。中央・外国はレース名で判定する。
RaceClassGrade raceClassGradeOfRecord(HorseRaceRecord record) {
  final byName = raceClassGradeOfName(record.raceName);
  if (byName == RaceClassGrade.g1 ||
      byName == RaceClassGrade.g2 ||
      byName == RaceClassGrade.g3) {
    return byName;
  }
  if (earnedPrizeSourceOf(record) == EarnedPrizeSource.local) {
    return RaceClassGrade.local;
  }
  return byName;
}

/// 今回のレースのクラスを判定する（中央だけを扱うので local は返さない）。
/// ① 出馬表のグレード欄（'G1'・'J.G1'・'L'・'OP'・'3勝' など）
/// ② グレード欄の文字をレース名として読む（結果から作ったデータはグレード欄にレース名が入る）
/// ③ レース名（'3歳以上1勝クラス'・'2歳新馬' など）
/// ④ レース条件（raceCategory）
RaceClassGrade raceClassGradeOfCurrentRace(PredictionRaceData race) {
  switch (race.raceGrade.trim()) {
    case 'G1':
    case 'J.G1':
      return RaceClassGrade.g1;
    case 'G2':
    case 'J.G2':
      return RaceClassGrade.g2;
    case 'G3':
    case 'J.G3':
      return RaceClassGrade.g3;
    case 'L':
      return RaceClassGrade.listed;
    case 'OP':
      return RaceClassGrade.open;
    case '3勝':
      return RaceClassGrade.win3;
    case '2勝':
      return RaceClassGrade.win2;
    case '1勝':
      return RaceClassGrade.win1;
  }
  final byGradeText = raceClassGradeOfName(race.raceGrade);
  if (byGradeText != RaceClassGrade.unknown) return byGradeText;
  final byName = raceClassGradeOfName(race.raceName);
  if (byName != RaceClassGrade.unknown) return byName;
  switch (raceClassLevelOf(race.raceCategory ?? '', '')) {
    case RaceClassLevel.newcomer:
      return RaceClassGrade.newcomer;
    case RaceClassLevel.maiden:
      return RaceClassGrade.maiden;
    case RaceClassLevel.win1:
      return RaceClassGrade.win1;
    case RaceClassLevel.win2:
      return RaceClassGrade.win2;
    case RaceClassLevel.win3:
      return RaceClassGrade.win3;
    case RaceClassLevel.open:
      return RaceClassGrade.open;
    case RaceClassLevel.unknown:
      return RaceClassGrade.unknown;
  }
}
