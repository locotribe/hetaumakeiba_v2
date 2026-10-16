// lib/logic/analysis/horse_record_stats.dart

// [追加] 好走条件・個別成績・相対評価の移動 Step1: 出走馬分析の「個別成績」の勝率・複勝率・単勝回収率・複勝回収率を出す純粋な部品。
// 馬詳細の「全」ページの能力の表（2段目）と、1頭のページ「能力・条件」の回収率で使う。戦績は読み込み係（RaceEntrantDataService）の
// レース日より前の戦績を渡す。取消・除外・空欄の行は出走に数えない。DB・画面には触れない (v.2026.10.17+26101706)

import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';

/// 1頭の通算成績と回収率（1走100円ずつ買ったとして計算する）。
class HorseRecordStats {
  /// 出走数（取消・除外・空欄の行を除く。中止は出走に数え、着外として扱う）。
  final int starts;

  /// 1着の数。
  final int wins;

  /// 3着以内の数。
  final int shows;

  /// 単勝を買ったとみなした走の数（出走のうち、単勝オッズが読めた走）。
  final int winBets;

  /// 単勝の払戻の合計（円。1着のとき オッズ×100）。
  final double winPayout;

  /// 複勝を買ったとみなした走の数（出走のうち、そのレースの結果がDBにあり、複勝の払戻が読めた走）。
  final int showBets;

  /// 複勝の払戻の合計（円）。
  final double showPayout;

  const HorseRecordStats({
    this.starts = 0,
    this.wins = 0,
    this.shows = 0,
    this.winBets = 0,
    this.winPayout = 0,
    this.showBets = 0,
    this.showPayout = 0,
  });

  /// 勝率（0〜1）。出走が無ければ null。
  double? get winRate => starts > 0 ? wins / starts : null;

  /// 複勝率（3着以内の割合、0〜1）。出走が無ければ null。
  double? get showRate => starts > 0 ? shows / starts : null;

  /// 単勝回収率（1.0 = 100%）。単勝を買った走が無ければ null。
  double? get winReturnRate => winBets > 0 ? winPayout / (winBets * 100) : null;

  /// 複勝回収率（1.0 = 100%）。複勝を買った走が無ければ null。
  double? get showReturnRate =>
      showBets > 0 ? showPayout / (showBets * 100) : null;
}

/// 出走に数える行か。着順が数字の行と、中止（'中'）などの数字でない行は数える。
/// 取消（'取'）・除外（'除'）・空欄は数えない（馬券は返還されるため、回収率にも入れない）。
bool isCountedStart(String rank) {
  final s = rank.trim();
  if (s.isEmpty) return false;
  if (s.contains('取') || s.contains('除')) return false;
  return true;
}

/// 戦績（レース日より前の走を渡す）と、DBに保存した過去走のレース結果（払戻）から、1頭の通算成績と回収率を出す。
/// 単勝の払戻は戦績の単勝オッズから、複勝の払戻はレース結果の複勝（券種ID '2'）の払戻から読む（今までの個別成績と同じ）。
HorseRecordStats horseRecordStatsOf(
  List<HorseRaceRecord> records,
  Map<String, RaceResult> raceResults,
) {
  int starts = 0;
  int wins = 0;
  int shows = 0;
  int winBets = 0;
  double winPayout = 0;
  int showBets = 0;
  double showPayout = 0;

  for (final record in records) {
    if (!isCountedStart(record.rank)) continue;
    starts++;
    final rank = int.tryParse(record.rank.trim());
    final isWin = rank == 1;
    final isShow = rank != null && rank >= 1 && rank <= 3;
    if (isWin) wins++;
    if (isShow) shows++;

    final odds = double.tryParse(record.odds.trim());
    if (odds != null && odds > 0) {
      winBets++;
      if (isWin) winPayout += odds * 100;
    }

    final result = raceResults[record.raceId];
    if (result == null) continue;
    Refund? showRefund;
    for (final refund in result.refunds) {
      if (refund.ticketTypeId == '2') {
        showRefund = refund;
        break;
      }
    }
    if (showRefund == null || showRefund.payouts.isEmpty) continue;
    showBets++;
    if (!isShow) continue;
    final horseNumber = int.tryParse(record.horseNumber.trim());
    if (horseNumber == null) continue;
    for (final payout in showRefund.payouts) {
      if (payout.combinationNumbers.contains(horseNumber)) {
        showPayout += int.tryParse(
                payout.amount.replaceAll(',', '').replaceAll('円', '').trim()) ??
            0;
        break;
      }
    }
  }

  return HorseRecordStats(
    starts: starts,
    wins: wins,
    shows: shows,
    winBets: winBets,
    winPayout: winPayout,
    showBets: showBets,
    showPayout: showPayout,
  );
}

/// 割合（0〜1）を「12%」の形にする。null は「-」。
String recordPercentLabel(double? rate) {
  if (rate == null) return '-';
  return '${(rate * 100).round()}%';
}
