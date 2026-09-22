// lib/services/netkeiba_training_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:hetaumakeiba_v2/db/repositories/netkeiba_training_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/training_repository.dart';
import 'package:hetaumakeiba_v2/logic/netkeiba_training_parser.dart';
import 'package:hetaumakeiba_v2/logic/training_merge.dart';
import 'package:hetaumakeiba_v2/services/netkeiba_session_service.dart';
import 'package:hetaumakeiba_v2/utils/training_course_utils.dart';

// [追加] 調教タブ改修Step3: netkeiba の最終追切（調教ページ type=2）と厩舎コメントの取得・保存 (v.2026.9.22+26092212)

/// レース単位の取得結果（ログ・呼び出し側の確認用）。
class NetkeibaRaceTrainingFetchResult {
  final bool skippedNotLoggedIn;
  final int reviewCount; // 最終追切の評価を保存した頭数
  final int sessionCount; // 最終追切の調教本数
  final int commentCount; // 厩舎コメントを保存した頭数

  const NetkeibaRaceTrainingFetchResult({
    this.skippedNotLoggedIn = false,
    this.reviewCount = 0,
    this.sessionCount = 0,
    this.commentCount = 0,
  });
}

class NetkeibaTrainingService {
  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  };

  final NetkeibaTrainingRepository _repository;
  final TrainingRepository _trainingRepository;

  NetkeibaTrainingService({
    NetkeibaTrainingRepository? repository,
    TrainingRepository? trainingRepository,
  })  : _repository = repository ?? NetkeibaTrainingRepository(),
        _trainingRepository = trainingRepository ?? TrainingRepository();

  static String oikiriUrl(String raceId) =>
      'https://race.netkeiba.com/race/oikiri.html?race_id=$raceId&type=2';

  static String commentUrl(String raceId) =>
      'https://race.netkeiba.com/race/comment.html?race_id=$raceId';

  /// ログイン中なら、指定レースの最終追切と厩舎コメントを取得して保存する。
  /// 未ログインなら何もしない（先頭3頭だけの中途半端なデータを保存しないため）。
  /// 失敗してもエラーは投げず、ログだけ出す。
  /// [horseIds] を渡すと、保存後に pakara との突き合わせ件数をログに出す。
  Future<NetkeibaRaceTrainingFetchResult> fetchAndSaveRaceTraining({
    required String raceId,
    List<String> horseIds = const [],
  }) async {
    if (!await NetkeibaSessionService.isLoggedIn()) {
      debugPrint('NetkeibaTrainingService: 未ログインのため取得しません (race=$raceId)');
      return const NetkeibaRaceTrainingFetchResult(skippedNotLoggedIn: true);
    }

    final fetchedAt = DateTime.now().toIso8601String();
    int reviewCount = 0;
    int sessionCount = 0;
    int commentCount = 0;

    try {
      final html = await _get(oikiriUrl(raceId));
      if (html != null) {
        final result = NetkeibaTrainingParser.parseOikiri(html, raceId,
            fetchedAt: fetchedAt);
        await _repository.upsertReviewsMerge(result.reviews);
        await _repository.upsertSessionsMerge(result.sessions);
        reviewCount = result.reviews.length;
        sessionCount = result.sessions.length;
      }
    } catch (e) {
      debugPrint('NetkeibaTrainingService: 最終追切の取得に失敗 (race=$raceId): $e');
    }

    await Future.delayed(const Duration(milliseconds: 300));

    try {
      final html = await _get(commentUrl(raceId));
      if (html != null) {
        final reviews = NetkeibaTrainingParser.parseStableComment(html, raceId,
            fetchedAt: fetchedAt);
        await _repository.upsertReviewsMerge(reviews);
        commentCount = reviews.length;
      }
    } catch (e) {
      debugPrint('NetkeibaTrainingService: 厩舎コメントの取得に失敗 (race=$raceId): $e');
    }

    debugPrint('NetkeibaTrainingService: race=$raceId 最終追切 $reviewCount頭/$sessionCount本, 厩舎コメント $commentCount頭');

    if (horseIds.isNotEmpty) {
      try {
        await _logMatchStats(horseIds);
      } catch (e) {
        debugPrint('NetkeibaTrainingService: 突き合わせログの出力に失敗: $e');
      }
    }

    return NetkeibaRaceTrainingFetchResult(
      reviewCount: reviewCount,
      sessionCount: sessionCount,
      commentCount: commentCount,
    );
  }

  /// Cookie 付きで取得し、UTF-8 の文字列で返す。失敗時は null。
  Future<String?> _get(String url) async {
    final cookie = await NetkeibaSessionService.getCookieHeader(url);
    if (cookie == null) {
      debugPrint('NetkeibaTrainingService: Cookie が無いため取得しません ($url)');
      return null;
    }
    final headers = Map<String, String>.from(_headers);
    headers['Cookie'] = cookie;
    final response = await http
        .get(Uri.parse(url), headers: headers)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      debugPrint('NetkeibaTrainingService: HTTP ${response.statusCode} ($url)');
      return null;
    }
    return utf8.decode(response.bodyBytes, allowMalformed: true);
  }

  /// 突き合わせのしきい値確認用ログ（設計書 3-4）。
  Future<void> _logMatchStats(List<String> horseIds) async {
    int matched = 0;
    int unmatchedComparable = 0;
    int otherCourse = 0;
    for (final horseId in horseIds) {
      final pakara = await _trainingRepository.getTrainingTimesForHorse(horseId);
      final netkeiba = await _repository.getSessionsForHorse(horseId);
      for (final entry in mergeTrainingSources(pakara, netkeiba)) {
        final nk = entry.netkeiba;
        if (nk == null) continue;
        if (entry.pakara != null) {
          matched++;
        } else if (classifyTrainingCourse(nk.courseRaw).pakaraTrackType !=
            null) {
          unmatchedComparable++;
          debugPrint('  突き合わせ不一致: horse=$horseId ${nk.trainingDate} ${nk.trainingTime ?? '----'} ${nk.courseRaw} ${nk.slots}');
        } else {
          otherCourse++;
        }
      }
    }
    debugPrint('NetkeibaTrainingService: 突き合わせ 一致 $matched本 / 坂路・ウッドで不一致 $unmatchedComparable本 / pakara に無いコース $otherCourse本');
  }
}
