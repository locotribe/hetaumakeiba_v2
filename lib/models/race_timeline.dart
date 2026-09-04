// lib/models/race_timeline.dart

// [修正] Phase 0 是正: race_page.dart への適用は前提誤り（過去レースでも
// race.netkeiba.com 系ページは10年前まで参照可能と実測で判明）のため撤回した。
// enum自体は将来フェーズ（過去成績のasOfリーク防止等）向けに残す (v.2026.9.4+26090403)

/// レースが時系列上どの位置にあるかを表す。
/// race_page.dart の _determineRaceStatus() が無駄なネットワークアクセスを
/// 避けるための判定に用いる。
enum RaceTimeline {
  /// 出馬表ページ公開前。
  unpublished,

  /// 出馬表公開済み・発走前。
  upcoming,

  /// 発走後・結果確定前。
  live,

  /// 結果確定済み・開催週内。
  settled,

  /// 開催週を過ぎた過去レース。netkeiba のページ可用性とは無関係で、
  /// 予想の対象として扱わない区分を表す。
  archived,

  /// 日付がパースできず判定不能。
  unknown,
}

/// レースデータの取得元を表す。
enum RaceDataSource {
  /// race.netkeiba.com/race/shutuba.html
  shutubaPage,

  /// race.netkeiba.com/race/newspaper.html
  newspaperPage,

  /// race.netkeiba.com/odds/index.html
  oddsPage,

  /// pakara-keiba.com の調教API
  trainingApi,

  /// race.netkeiba.com/race/result.html（当日用・WebView）
  resultPageLive,

  /// db.netkeiba.com/race/{raceId}
  resultPageDb,

  /// JMA / OpenMeteo
  weather,
}
