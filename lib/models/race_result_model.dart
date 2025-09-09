// lib/models/race_result_model.dart

import 'dart:convert';
import 'package:hetaumakeiba_v2/models/horse_memo_model.dart';

// JSON文字列とRaceResultオブジェクトを相互変換するためのトップレベル関数
String raceResultToJson(RaceResult data) => json.encode(data.toJson());
RaceResult raceResultFromJson(String str) => RaceResult.fromJson(json.decode(str));

/// レース全体のスクレイピング結果を保持するクラス
class RaceResult {
  final String raceId; // レースID (例: 202508020911)
  final String raceTitle; // レース名 (例: 第32回平安ステークス(GIII))
  final String raceInfo; // コース情報 (例: ダ右1900m / 天候 : 雨 / ダート : 稍重)
  final String raceDate; // 開催日 (例: 2025年5月24日)
  final String raceGrade; // レース条件 (例: 4歳以上オープン (国際)(指)(別定))
  final List<HorseResult> horseResults; // 全出走馬の結果リスト
  final List<Refund> refunds; // 払戻金情報リスト
  final List<String> cornerPassages; // コーナー通過順位
  final List<String> lapTimes; // ラップタイム

  /// データが不完全（未来のレースなどで、まだ結果が取得できていない状態）かどうかを判定します。
  bool get isIncomplete {
    // レースタイトルが空、または開催日が初期値（1970年）の場合、不完全とみなす
    final bool isInfoMissing = (raceTitle.trim().isEmpty || raceDate.startsWith('1970'));
    // 馬の着順情報が空の場合も不完全とみなす
    final bool hasNoResults = horseResults.isEmpty;

    return isInfoMissing || hasNoResults;
  }

  RaceResult({
    required this.raceId,
    required this.raceTitle,
    required this.raceInfo,
    required this.raceDate,
    required this.raceGrade,
    required this.horseResults,
    required this.refunds,
    required this.cornerPassages,
    required this.lapTimes,
  });

  // JSON (Map) から RaceResult オブジェクトを生成するファクトリコンストラクタ
  factory RaceResult.fromJson(Map<String, dynamic> json) => RaceResult(
    raceId: json["raceId"],
    raceTitle: json["raceTitle"],
    raceInfo: json["raceInfo"],
    raceDate: json["raceDate"],
    raceGrade: json["raceGrade"],
    horseResults: List<HorseResult>.from(json["horseResults"].map((x) => HorseResult.fromJson(x))),
    refunds: List<Refund>.from(json["refunds"].map((x) => Refund.fromJson(x))),
    cornerPassages: List<String>.from(json["cornerPassages"].map((x) => x)),
    lapTimes: List<String>.from(json["lapTimes"].map((x) => x)),
  );

  // RaceResult オブジェクトから JSON (Map) へ変換するメソッド
  Map<String, dynamic> toJson() => {
    "raceId": raceId,
    "raceTitle": raceTitle,
    "raceInfo": raceInfo,
    "raceDate": raceDate,
    "raceGrade": raceGrade,
    "horseResults": List<dynamic>.from(horseResults.map((x) => x.toJson())),
    "refunds": List<dynamic>.from(refunds.map((x) => x.toJson())),
    "cornerPassages": List<dynamic>.from(cornerPassages.map((x) => x)),
    "lapTimes": List<dynamic>.from(lapTimes.map((x) => x)),
  };
}

/// 出走馬1頭ごとの成績を保持するクラス
class HorseResult {
  final String rank; // 着順
  final String frameNumber; // 枠番
  final String horseNumber; // 馬番
  final String horseName; // 馬名
  final String horseId; // 馬ID (URLから取得)
  final String sexAndAge; // 性齢
  final String weightCarried; // 斤量
  final String jockeyName; // 騎手
  final String time; // タイム
  final String margin; // 着差
  final String cornerRanking; // 通過
  final String agari; // 上り
  final String odds; // 単勝オッズ
  final String popularity; // 人気
  final String horseWeight; // 馬体重
  final String trainerName; // 調教師名
  final String trainerAffiliation; // 所属
  final String ownerName; // 馬主
  final String prizeMoney; // 賞金(万円)
  HorseMemo? userMemo;

  HorseResult({
    required this.rank,
    required this.frameNumber,
    required this.horseNumber,
    required this.horseName,
    required this.horseId,
    required this.sexAndAge,
    required this.weightCarried,
    required this.jockeyName,
    required this.time,
    required this.margin,
    required this.cornerRanking,
    required this.agari,
    required this.odds,
    required this.popularity,
    required this.horseWeight,
    required this.trainerName,
    required this.trainerAffiliation,
    required this.ownerName,
    required this.prizeMoney,
    this.userMemo,
  });

  factory HorseResult.fromJson(Map<String, dynamic> json) => HorseResult(
    rank: json["rank"],
    frameNumber: json["frameNumber"],
    horseNumber: json["horseNumber"],
    horseName: json["horseName"],
    horseId: json["horseId"],
    sexAndAge: json["sexAndAge"],
    weightCarried: json["weightCarried"],
    jockeyName: json["jockeyName"],
    time: json["time"],
    margin: json["margin"],
    cornerRanking: json["cornerRanking"],
    agari: json["agari"],
    odds: json["odds"],
    popularity: json["popularity"],
    horseWeight: json["horseWeight"],
    trainerName: json["trainerName"],
    trainerAffiliation: json["trainerAffiliation"],
    ownerName: json["ownerName"],
    prizeMoney: json["prizeMoney"],
  );

  Map<String, dynamic> toJson() => {
    "rank": rank,
    "frameNumber": frameNumber,
    "horseNumber": horseNumber,
    "horseName": horseName,
    "horseId": horseId,
    "sexAndAge": sexAndAge,
    "weightCarried": weightCarried,
    "jockeyName": jockeyName,
    "time": time,
    "margin": margin,
    "cornerRanking": cornerRanking,
    "agari": agari,
    "odds": odds,
    "popularity": popularity,
    "horseWeight": horseWeight,
    "trainerName": trainerName,
    "trainerAffiliation": trainerAffiliation,
    "ownerName": ownerName,
    "prizeMoney": prizeMoney,
  };
}

/// 払戻情報を保持するクラス
class Refund {
  final String ticketTypeId; // 券種 (例: 単勝, 複勝, 馬連)
  final List<Payout> payouts; // 払戻の組み合わせリスト

  Refund({
    required this.ticketTypeId,
    required this.payouts,
  });

  factory Refund.fromJson(Map<String, dynamic> json) => Refund(
    ticketTypeId: json["ticketTypeId"],
    payouts: List<Payout>.from(json["payouts"].map((x) => Payout.fromJson(x))),
  );

  Map<String, dynamic> toJson() => {
    "ticketTypeId": ticketTypeId,
    "payouts": List<dynamic>.from(payouts.map((x) => x.toJson())),
  };
}

/// 個々の払戻の組み合わせを保持するクラス
class Payout {
  final String combination; // 馬番の組み合わせ (例: 6 - 7)
  final String amount; // 払戻金額 (円)
  final String popularity; // 人気
  final List<int> combinationNumbers;

  Payout({
    required this.combination,
    required this.amount,
    required this.popularity,
    required this.combinationNumbers,
  });

  factory Payout.fromJson(Map<String, dynamic> json) => Payout(
    combination: json["combination"],
    amount: json["amount"],
    popularity: json["popularity"],
    combinationNumbers: List<int>.from(json["combinationNumbers"].map((x) => x)),
  );

  Map<String, dynamic> toJson() => {
    "combination": combination,
    "amount": amount,
    "popularity": popularity,
    "combinationNumbers": List<dynamic>.from(combinationNumbers.map((x) => x)),
  };
}