// lib/logic/training_fetch_policy.dart

// [追加] 出走の意味 調教の行 Step3: 調教・近況の取得の間隔と、取りに行くかどうかの判定。通信はしない純粋な関数 (v.2026.10.24+26102403)

/// pakara を前走の日まで遡るときの要求の間隔（ミリ秒）。pakara の規約はオーナーが確認済み
const int kPakaraRequestIntervalMs = 1000;

/// netkeiba の競走馬調教ページ・近況ページを続けて取るときの要求の間隔（ミリ秒）
const int kNetkeibaRequestIntervalMs = 3000;

/// 同じ馬の近況を取り直すまでの最短の時間（時間）
const int kConditionPostRefetchHours = 12;

/// 近況を取りに行くか。前に取った日時が無い、または [kConditionPostRefetchHours] 時間以上前なら true。
/// 前に取った日時が今より先（時計のずれ）のときは false。
bool needsConditionPostFetch(DateTime? lastFetchedAt, DateTime now) {
  if (lastFetchedAt == null) return true;
  return now.difference(lastFetchedAt) >=
      const Duration(hours: kConditionPostRefetchHours);
}

/// 「調教の遡り・近況」のステップで通信を省くか。
/// レース日（YYYYMMDD）が今日より前なら true（結果から開いた古いレースで取りに行かない）。
/// レース日が 8桁の数字として読めないときも true（日付が分からないまま取りに行かない）。
bool shouldSkipTrainingHistory(String raceYmd, DateTime now) {
  if (!RegExp(r'^\d{8}$').hasMatch(raceYmd)) return true;
  final today = '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
  return raceYmd.compareTo(today) < 0;
}
