// lib/models/race_data.dart

import 'package:hetaumakeiba_v2/models/shutuba_horse_detail_model.dart';
import 'package:hetaumakeiba_v2/models/user_mark_model.dart';
import 'package:hetaumakeiba_v2/models/horse_memo_model.dart';
import 'package:hetaumakeiba_v2/models/analysis_model.dart';
import 'package:hetaumakeiba_v2/models/complex_aptitude_model.dart';
import 'package:hetaumakeiba_v2/models/best_time_stats_model.dart';
import 'package:hetaumakeiba_v2/models/fastest_agari_stats_model.dart';
import 'package:hetaumakeiba_v2/logic/analysis/leg_style_analyzer.dart';
import 'package:hetaumakeiba_v2/models/jockey_combo_stats_model.dart';

/// レース全体の予想データを保持するコンテナです。
class PredictionRaceData {
  final String raceId;
  final String raceName;
  final String raceDate;
  final String venue;
  final String raceNumber;
  final String shutubaTableUrl;
  final String raceGrade;
  final String? raceDetails1;
  final List<PredictionHorseDetail> horses;
  RacePacePrediction? racePacePrediction;

  // ▼▼ 新規追加: 細分化されたレース環境データ ▼▼
  final String? trackType;
  final int? distanceValue;
  final String? direction;
  final String? courseInOut;
  final String? weather;
  final String? trackCondition;
  final int? holdingTimes;
  final int? holdingDays;
  final String? raceCategory;
  final int? horseCount;
  final String? startTime;
  final int? basePrize1st;
  final int? basePrize2nd;
  final int? basePrize3rd;
  final int? basePrize4th;
  final int? basePrize5th;
  // ▲▲ 新規追加 ▲▲

  PredictionRaceData({
    required this.raceId,
    required this.raceName,
    required this.raceDate,
    required this.venue,
    required this.raceNumber,
    required this.shutubaTableUrl,
    required this.raceGrade,
    this.raceDetails1,
    required this.horses,
    this.racePacePrediction,
    // ▼▼ 新規追加 ▼▼
    this.trackType,
    this.distanceValue,
    this.direction,
    this.courseInOut,
    this.weather,
    this.trackCondition,
    this.holdingTimes,
    this.holdingDays,
    this.raceCategory,
    this.horseCount,
    this.startTime,
    this.basePrize1st,
    this.basePrize2nd,
    this.basePrize3rd,
    this.basePrize4th,
    this.basePrize5th,
    // ▲▲ 新規追加 ▲▲
  });

  Map<String, dynamic> toJson() {
    return {
      'raceId': raceId,
      'raceName': raceName,
      'raceDate': raceDate,
      'venue': venue,
      'raceNumber': raceNumber,
      'shutubaTableUrl': shutubaTableUrl,
      'raceGrade': raceGrade,
      'raceDetails1': raceDetails1,
      'horses': horses.map((h) => h.toJson()).toList(),
      // ▼▼ 新規追加 ▼▼
      'trackType': trackType,
      'distanceValue': distanceValue,
      'direction': direction,
      'courseInOut': courseInOut,
      'weather': weather,
      'trackCondition': trackCondition,
      'holdingTimes': holdingTimes,
      'holdingDays': holdingDays,
      'raceCategory': raceCategory,
      'horseCount': horseCount,
      'startTime': startTime,
      'basePrize1st': basePrize1st,
      'basePrize2nd': basePrize2nd,
      'basePrize3rd': basePrize3rd,
      'basePrize4th': basePrize4th,
      'basePrize5th': basePrize5th,
      // ▲▲ 新規追加 ▲▲
    };
  }

  factory PredictionRaceData.fromJson(Map<String, dynamic> json) {
    // ▼▼ フォールバック処理用の変数準備 ▼▼
    String? pTrackType = json['trackType'] as String?;
    int? pDistanceValue = json['distanceValue'] as int?;
    String? pDirection = json['direction'] as String?;
    String? pCourseInOut = json['courseInOut'] as String?;
    String? pWeather = json['weather'] as String?;
    String? pTrackCondition = json['trackCondition'] as String?;
    int? pHoldingTimes = json['holdingTimes'] as int?;
    int? pHoldingDays = json['holdingDays'] as int?;
    String? pRaceCategory = json['raceCategory'] as String?;
    int? pHorseCount = json['horseCount'] as int?;
    String? pStartTime = json['startTime'] as String?;

    // 古いデータで項目がnullの場合、raceDetails1から正規表現で救済する
    final details = json['raceDetails1'] as String?;
    if (details != null && details.isNotEmpty) {
      // 第◯回 または ◯回
      final holdingTimesMatch = RegExp(r'(\d+)回').firstMatch(details);
      if (holdingTimesMatch != null) pHoldingTimes ??= int.tryParse(holdingTimesMatch.group(1)!);

      // ◯日目
      final holdingDaysMatch = RegExp(r'(\d+)日目').firstMatch(details);
      if (holdingDaysMatch != null) pHoldingDays ??= int.tryParse(holdingDaysMatch.group(1)!);

      // ◯頭
      final horseCountMatch = RegExp(r'(\d+)頭').firstMatch(details);
      if (horseCountMatch != null) pHorseCount ??= int.tryParse(horseCountMatch.group(1)!);

      // カテゴリ (例: 日目 と 頭 の間にある "サラ系３歳未勝利" などを抽出)
      final categoryMatch = RegExp(r'日目\s+(.+?)\s+\d+頭').firstMatch(details);
      if (categoryMatch != null) pRaceCategory ??= categoryMatch.group(1)?.trim();

      // 発走時刻
      final timeMatch = RegExp(r'(\d{2}:\d{2})発走').firstMatch(details);
      if (timeMatch != null) pStartTime ??= timeMatch.group(1);

      // トラック種別と距離 (例: 芝2000m)
      final trackDistMatch = RegExp(r'(芝|ダ|障)(\d+)m').firstMatch(details);
      if (trackDistMatch != null) {
        pTrackType ??= trackDistMatch.group(1);
        pDistanceValue ??= int.tryParse(trackDistMatch.group(2)!);
      }

      // 回転方向と内外 (例: (右 A) または (右) または (直))
      final dirMatch = RegExp(r'\((右|左|直)(?:\s+(.+?))?\)').firstMatch(details);
      if (dirMatch != null) {
        pDirection ??= dirMatch.group(1);
        if (dirMatch.group(2) != null) pCourseInOut ??= dirMatch.group(2);
      }

      // 天候
      final weatherMatch = RegExp(r'天候:(\S+)').firstMatch(details);
      if (weatherMatch != null) pWeather ??= weatherMatch.group(1);

      // 馬場状態
      final condMatch = RegExp(r'馬場:(\S+)').firstMatch(details);
      if (condMatch != null) pTrackCondition ??= condMatch.group(1);
    }
    // ▲▲ フォールバック処理終了 ▲▲

    return PredictionRaceData(
      raceId: json['raceId'] as String,
      raceName: json['raceName'] as String,
      raceDate: json['raceDate'] as String,
      venue: json['venue'] as String,
      raceNumber: json['raceNumber'] as String,
      shutubaTableUrl: json['shutubaTableUrl'] as String,
      raceGrade: json['raceGrade'] as String,
      raceDetails1: details,
      horses: (json['horses'] as List<dynamic>)
          .map((e) => PredictionHorseDetail.fromJson(e as Map<String, dynamic>))
          .toList(),
      // ▼▼ 新規追加: フォールバック結果を反映 ▼▼
      trackType: pTrackType,
      distanceValue: pDistanceValue,
      direction: pDirection,
      courseInOut: pCourseInOut,
      weather: pWeather,
      trackCondition: pTrackCondition,
      holdingTimes: pHoldingTimes,
      holdingDays: pHoldingDays,
      raceCategory: pRaceCategory,
      horseCount: pHorseCount,
      startTime: pStartTime,
      basePrize1st: json['basePrize1st'] as int?,
      basePrize2nd: json['basePrize2nd'] as int?,
      basePrize3rd: json['basePrize3rd'] as int?,
      basePrize4th: json['basePrize4th'] as int?,
      basePrize5th: json['basePrize5th'] as int?,
      // ▲▲ 新規追加 ▲▲
    );
  }
}

/// 各出走馬の予想に必要な詳細情報（特に動的な情報）を保持します。
class PredictionHorseDetail {
  final String horseId;
  final int horseNumber;
  final int gateNumber;
  final String horseName;
  final String sexAndAge;
  final String jockey;
  final String jockeyId;
  final double carriedWeight;
  final String trainerName;
  final String trainerAffiliation;
  double? odds;
  final String? effectiveOdds;
  int? popularity;
  String? horseWeight;
  UserMark? userMark;
  HorseMemo? userMemo;
  final bool isScratched;
  HorsePredictionScore? predictionScore;
  ConditionFitResult? conditionFit;
  ComplexAptitudeStats? distanceCourseAptitudeStats;
  String? trackAptitudeLabel;
  BestTimeStats? bestTimeStats;
  FastestAgariStats? fastestAgariStats;

  // ▼▼ 新規追加: 同コース専用の成績箱 ▼▼
  BestTimeStats? bestCourseTimeStats;
  FastestAgariStats? fastestCourseAgariStats;
  // ▲▲ 新規追加 ▲▲

  double? overallScore;
  double? expectedValue;
  LegStyleProfile? legStyleProfile;
  String? previousHorseWeight;
  String? previousJockey;

  JockeyComboStats? jockeyComboStats;

  String? ownerName;
  String? ownerId;
  String? ownerImageLocalPath;
  String? breederName;
  String? fatherName;
  String? motherName;
  String? mfName;

  PredictionHorseDetail({
    required this.horseId,
    required this.horseNumber,
    required this.gateNumber,
    required this.horseName,
    required this.sexAndAge,
    required this.jockey,
    required this.jockeyId,
    required this.carriedWeight,
    required this.trainerName,
    required this.trainerAffiliation,
    this.odds,
    this.effectiveOdds,
    this.popularity,
    this.horseWeight,
    this.userMark,
    this.userMemo,
    required this.isScratched,
    this.predictionScore,
    this.conditionFit,
    this.distanceCourseAptitudeStats,
    this.trackAptitudeLabel,
    this.bestTimeStats,
    this.fastestAgariStats,
    // ▼▼ 新規追加 ▼▼
    this.bestCourseTimeStats,
    this.fastestCourseAgariStats,
    // ▲▲ 新規追加 ▲▲
    this.overallScore,
    this.expectedValue,
    this.legStyleProfile,
    this.previousHorseWeight,
    this.previousJockey,
    this.ownerName,
    this.ownerId,
    this.ownerImageLocalPath,
    this.breederName,
    this.fatherName,
    this.motherName,
    this.mfName,
    this.jockeyComboStats,
  });

  factory PredictionHorseDetail.fromShutubaHorseDetail(ShutubaHorseDetail detail) {
    return PredictionHorseDetail(
      horseId: detail.horseId,
      horseNumber: detail.horseNumber,
      gateNumber: detail.gateNumber,
      horseName: detail.horseName,
      sexAndAge: detail.sexAndAge,
      jockey: detail.jockey,
      jockeyId: detail.jockeyId,
      carriedWeight: detail.carriedWeight,
      trainerName: detail.trainerName,
      trainerAffiliation: detail.trainerAffiliation,
      horseWeight: detail.horseWeight,
      odds: detail.odds,
      effectiveOdds: null,
      popularity: detail.popularity,
      isScratched: detail.isScratched,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'horseId': horseId,
      'horseNumber': horseNumber,
      'gateNumber': gateNumber,
      'horseName': horseName,
      'sexAndAge': sexAndAge,
      'jockey': jockey,
      'jockeyId': jockeyId,
      'carriedWeight': carriedWeight,
      'trainerName': trainerName,
      'trainerAffiliation': trainerAffiliation,
      'odds': odds,
      'effectiveOdds': effectiveOdds,
      'popularity': popularity,
      'horseWeight': horseWeight,
      'isScratched': isScratched,
      'userMark': userMark?.toMap(),
      'userMemo': userMemo?.toMap(),
      'overallScore': overallScore,
      'expectedValue': expectedValue,
      'distanceCourseAptitudeStats': distanceCourseAptitudeStats?.toMap(),
      'trackAptitudeLabel': trackAptitudeLabel,
      'legStyleProfile': legStyleProfile?.toJson(),
      'previousHorseWeight': previousHorseWeight,
      'previousJockey': previousJockey,
      'bestTimeStats': bestTimeStats?.toMap(),
      'fastestAgariStats': fastestAgariStats?.toMap(),
      // ▼▼ 新規追加 ▼▼
      'bestCourseTimeStats': bestCourseTimeStats?.toMap(),
      'fastestCourseAgariStats': fastestCourseAgariStats?.toMap(),
      // ▲▲ 新規追加 ▲▲
      'ownerName': ownerName,
      'ownerId': ownerId,
      'ownerImageLocalPath': ownerImageLocalPath,
      'breederName': breederName,
      'fatherName': fatherName,
      'motherName': motherName,
      'mfName': mfName,
      'jockeyComboStats': jockeyComboStats != null ? {
        'isFirstRide': jockeyComboStats!.isFirstRide,
        'rideCount': jockeyComboStats!.rideCount,
        'winRate': jockeyComboStats!.winRate,
        'placeRate': jockeyComboStats!.placeRate,
        'showRate': jockeyComboStats!.showRate,
        'winRecoveryRate': jockeyComboStats!.winRecoveryRate,
        'showRecoveryRate': jockeyComboStats!.showRecoveryRate,
        'recordString': jockeyComboStats!.recordString,
      } : null,
    };
  }

  factory PredictionHorseDetail.fromJson(Map<String, dynamic> json) {
    return PredictionHorseDetail(
      horseId: json['horseId'] as String,
      horseNumber: json['horseNumber'] as int,
      gateNumber: json['gateNumber'] as int,
      horseName: json['horseName'] as String,
      sexAndAge: json['sexAndAge'] as String,
      jockey: json['jockey'] as String,
      jockeyId: json['jockeyId'] as String? ?? '',
      carriedWeight: (json['carriedWeight'] as num).toDouble(),
      trainerName: json['trainerName'] as String,
      trainerAffiliation: json['trainerAffiliation'] as String,
      odds: (json['odds'] as num?)?.toDouble(),
      effectiveOdds: json['effectiveOdds'] as String?,
      popularity: json['popularity'] as int?,
      horseWeight: json['horseWeight'] as String?,
      isScratched: json['isScratched'] as bool,
      userMark: json['userMark'] != null
          ? UserMark.fromMap(json['userMark'] as Map<String, dynamic>)
          : null,
      userMemo: json['userMemo'] != null
          ? HorseMemo.fromMap(json['userMemo'] as Map<String, dynamic>)
          : null,
      overallScore: (json['overallScore'] as num?)?.toDouble(),
      expectedValue: (json['expectedValue'] as num?)?.toDouble(),
      distanceCourseAptitudeStats: json['distanceCourseAptitudeStats'] != null
          ? ComplexAptitudeStats.fromMap(json['distanceCourseAptitudeStats'] as Map<String, dynamic>)
          : null,
      trackAptitudeLabel: json['trackAptitudeLabel'] as String?,
      legStyleProfile: json['legStyleProfile'] != null
          ? LegStyleProfile.fromJson(json['legStyleProfile'] as Map<String, dynamic>)
          : null,
      previousHorseWeight: json['previousHorseWeight'] as String?,
      previousJockey: json['previousJockey'] as String?,
      bestTimeStats: json['bestTimeStats'] != null
          ? BestTimeStats.fromMap(json['bestTimeStats'] as Map<String, dynamic>)
          : null,
      fastestAgariStats: json['fastestAgariStats'] != null
          ? FastestAgariStats.fromMap(json['fastestAgariStats'] as Map<String, dynamic>)
          : null,
      // ▼▼ 新規追加 ▼▼
      bestCourseTimeStats: json['bestCourseTimeStats'] != null
          ? BestTimeStats.fromMap(json['bestCourseTimeStats'] as Map<String, dynamic>)
          : null,
      fastestCourseAgariStats: json['fastestCourseAgariStats'] != null
          ? FastestAgariStats.fromMap(json['fastestCourseAgariStats'] as Map<String, dynamic>)
          : null,
      // ▲▲ 新規追加 ▲▲
      ownerName: json['ownerName'] as String?,
      ownerId: json['ownerId'] as String?,
      ownerImageLocalPath: json['ownerImageLocalPath'] as String?,
      breederName: json['breederName'] as String?,
      fatherName: json['fatherName'] as String?,
      motherName: json['motherName'] as String?,
      mfName: json['mfName'] as String?,
      jockeyComboStats: json['jockeyComboStats'] != null
          ? JockeyComboStats(
        isFirstRide: json['jockeyComboStats']['isFirstRide'] as bool? ?? false,
        rideCount: json['jockeyComboStats']['rideCount'] as int? ?? 0,
        winRate: (json['jockeyComboStats']['winRate'] as num?)?.toDouble() ?? 0.0,
        placeRate: (json['jockeyComboStats']['placeRate'] as num?)?.toDouble() ?? 0.0,
        showRate: (json['jockeyComboStats']['showRate'] as num?)?.toDouble() ?? 0.0,
        winRecoveryRate: (json['jockeyComboStats']['winRecoveryRate'] as num?)?.toDouble() ?? 0.0,
        showRecoveryRate: (json['jockeyComboStats']['showRecoveryRate'] as num?)?.toDouble() ?? 0.0,
        recordString: json['jockeyComboStats']['recordString'] as String? ?? '0-0-0-0',
      )
          : null,
    );
  }
}