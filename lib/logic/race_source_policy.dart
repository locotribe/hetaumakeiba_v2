// lib/logic/race_source_policy.dart

// [修正] Phase 0 是正: race_page.dart への適用（archived時のネットワークアクセス抑止）は
// 「過去レースではrace.netkeiba.com系ページが存在しない」という前提が実測で誤りと判明したため撤回。
// RaceTimelineResolverの判定ロジック自体は将来フェーズ（過去成績のasOfリーク防止、
// 動的データの更新可否判定、調教APIのガード）で使うためそのまま残す (v.2026.9.4+26090403)

import 'package:hetaumakeiba_v2/models/race_timeline.dart';
import 'package:hetaumakeiba_v2/utils/speed_index_date_parser.dart';

/// raceDate文字列と発走時刻からレースの時系列上の位置([RaceTimeline])を判定する。
class RaceTimelineResolver {
  /// 出馬表ページが公開されるおおよそのリード時間。発走のこれより前は unpublished。
  static const Duration shutubaPublishLead = Duration(days: 3);

  /// 発走からこの時間の経過で結果確定とみなす（live → settled）。
  /// shutuba_table_page.dart の _isWeatherLocked() と同じ 1 時間を採用する。
  static const Duration resultConfirmLag = Duration(hours: 1);

  /// 発走からこの時間の経過で「開催週を過ぎた過去レース」とみなす（settled → archived）。
  ///
  /// [修正] Phase 0 是正 (v.2026.9.4+26090403): 2026-09-04の実測により、
  /// race.netkeiba.com 系ページ（出馬表 / 新聞 / オッズ / 結果）は10年前のレースでも
  /// 参照可能であることが確認された。したがってこの境界は「ページの可用性」とは無関係である。
  /// この境界は「予想の対象として扱わない過去レース」を区別するためのプロダクト上の定義であり、
  /// 将来フェーズで過去成績を asOf フィルタする際の判定などに用いる。値 8 日に技術的な根拠はない。
  static const Duration archiveLag = Duration(days: 8);

  /// raceId は現時点では判定に使わない。将来の拡張（先頭4桁の年による健全性チェック等）用。
  static RaceTimeline resolve({
    required String raceId,
    required String raceDate,
    String? startTime,
    String? raceDetails1,
    DateTime? now,
  }) {
    final resolvedNow = now ?? DateTime.now();

    final parsedDate = parseRaceDateForSpeedIndex(raceDate);
    if (parsedDate == null) {
      return RaceTimeline.unknown;
    }

    int hour = 15;
    int minute = 0;

    final startTimeMatch =
        startTime != null ? RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(startTime) : null;
    final raceDetails1MatchA = raceDetails1 != null
        ? RegExp(r'(\d{1,2}):(\d{2})\s*発走').firstMatch(raceDetails1)
        : null;
    final raceDetails1MatchB = raceDetails1 != null
        ? RegExp(r'発走\s*[:：]?\s*(\d{1,2}):(\d{2})').firstMatch(raceDetails1)
        : null;

    if (startTimeMatch != null) {
      hour = int.parse(startTimeMatch.group(1)!);
      minute = int.parse(startTimeMatch.group(2)!);
    } else if (raceDetails1MatchA != null) {
      hour = int.parse(raceDetails1MatchA.group(1)!);
      minute = int.parse(raceDetails1MatchA.group(2)!);
    } else if (raceDetails1MatchB != null) {
      hour = int.parse(raceDetails1MatchB.group(1)!);
      minute = int.parse(raceDetails1MatchB.group(2)!);
    }

    final raceDateTime = DateTime(
      parsedDate.year,
      parsedDate.month,
      parsedDate.day,
      hour,
      minute,
    );

    if (resolvedNow.isBefore(raceDateTime.subtract(shutubaPublishLead))) {
      return RaceTimeline.unpublished;
    }
    if (resolvedNow.isBefore(raceDateTime)) {
      return RaceTimeline.upcoming;
    }
    if (resolvedNow.isBefore(raceDateTime.add(resultConfirmLag))) {
      return RaceTimeline.live;
    }
    if (resolvedNow.isBefore(raceDateTime.add(archiveLag))) {
      return RaceTimeline.settled;
    }
    return RaceTimeline.archived;
  }
}

/// [修正] Phase 0 是正 (v.2026.9.4+26090403): 2026-09-04の実測結果に基づき常にtrueを返す実装に
/// 差し替えた。実測（netkeibaの各ページを実際に取得しアプリの各スクレイパーと同一セレクタで確認）:
/// - `race.netkeiba.com/race/shutuba.html`: 2016年（10年前）のレースでも
///   `table.Shutuba_Table` / `h1.RaceName` / `div.RaceData01` 等が生存し、
///   shutuba_table_scraper_service.dart のセレクタで取得可能（馬体重も残る）。
/// - `newspaper.html` / `odds/index.html?type=b1`: 同じく2016年のレースで生存を確認
///   （`dt.Horse02` 18個、確定オッズ数値セル18個）。
/// - `race.netkeiba.com/race/result.html` の `#All_Result_Table`:
///   未確定・確定済み（先週/10年前）・存在しないIDの4パターンすべてで
///   `isRaceResultConfirmed()` は正しい真偽値を返すことを確認済み。
/// - `db.netkeiba.com/race/{raceId}`: 2016年のページでも `table.race_table_01` が存在し、
///   race_result_scraper_service.dart の25列オフセット処理で対応済み。
/// この結果、「開催週を過ぎると race.netkeiba.com 系ページが参照できなくなる」という
/// Phase 0 の前提は誤りだったため、時系列による可用性制限は行わない。
/// このクラス自体は、検証済みの可用性マトリクスを1箇所に記録しておき、将来フェーズで
/// trainingApi（pakara-keiba.com、第三者サイトのため保持期間が未検証）などの実測結果を
/// 反映できるようにするために残す。
class RaceSourcePolicy {
  static bool isAvailable(RaceDataSource source, RaceTimeline timeline) {
    if (timeline == RaceTimeline.unknown) return true;

    switch (source) {
      // 2026-09-04 実測: 10年前のレースでも参照可能。時系列で制限しない。
      case RaceDataSource.shutubaPage:
      case RaceDataSource.newspaperPage:
      case RaceDataSource.oddsPage:
      case RaceDataSource.resultPageLive:
      case RaceDataSource.resultPageDb:
        return true;

      // [修正] 2026-09-04 実測: 坂路API(get_cyoukyou.php)は10年前のレースでも取得可能。
      // ウッドAPI(get_cyoukyou_wc.php)は2023年以降は完全、2021年頃は部分的、2018年以前は0件。
      // どちらも古いレースではHTTP 200で空配列を返すのみで例外にならないため、
      // 時系列によるガードは不要 (v.2026.9.4+26090405)
      case RaceDataSource.trainingApi:
        return true;

      // 既存の shutuba_table_page.dart の _isWeatherLocked() が判定を持つ。
      // このポリシーからは制限しない。
      case RaceDataSource.weather:
        return true;
    }
  }
}
