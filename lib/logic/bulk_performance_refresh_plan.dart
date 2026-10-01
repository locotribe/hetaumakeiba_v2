// lib/logic/bulk_performance_refresh_plan.dart

// [一時] 陣営の本気度指数 実施順2: 過去走の一括取り直し（一時ボタン）の対象の並べ方・結果の集計。
// DBも画面も持たない純粋なロジック。一括取り直しの実行後、ボタンと一緒に削除する (v.2026.10.2+26100204)

/// 1頭ごとの待ち時間（netkeiba への負荷を抑えるため）
const Duration kBulkRefreshInterval = Duration(seconds: 1);

/// 取得結果が空だったときに、もう1回だけ取り直すまでの待ち時間
const Duration kBulkRefreshRetryDelay = Duration(seconds: 2);

/// 失敗がこの頭数続いたら自動で止める（通信断・アクセス制限の疑い）
const int kBulkRefreshMaxConsecutiveFailures = 5;

/// 1頭あたりの所要時間の目安（秒）。確認ダイアログの「約◯分」の計算にだけ使う
const int kBulkRefreshSecondsPerHorse = 2;

/// 一括取り直しの対象1頭
class BulkRefreshTarget {
  final String horseId;
  final String horseName;

  const BulkRefreshTarget({required this.horseId, required this.horseName});

  /// 画面表示用。馬名があれば「馬名（馬ID）」、無ければ馬IDだけ
  String get label => horseName.isEmpty ? horseId : '$horseName（$horseId）';
}

/// [all] の並び順を保ったまま、[doneIds] に含まれる馬・馬IDが空の馬・重複を除いた残りを返す。
List<BulkRefreshTarget> remainingBulkRefreshTargets(
  List<BulkRefreshTarget> all,
  Set<String> doneIds,
) {
  final seen = <String>{};
  final result = <BulkRefreshTarget>[];
  for (final target in all) {
    if (target.horseId.isEmpty) continue;
    if (doneIds.contains(target.horseId)) continue;
    if (!seen.add(target.horseId)) continue;
    result.add(target);
  }
  return result;
}

/// 残り [remainingCount] 頭の所要時間の目安（分・切り上げ）。0頭以下なら0。
int estimatedBulkRefreshMinutes(int remainingCount) {
  if (remainingCount <= 0) return 0;
  return (remainingCount * kBulkRefreshSecondsPerHorse + 59) ~/ 60;
}

/// 一括取り直しの途中経過と結果の集計
class BulkRefreshTally {
  int successCount = 0;
  final List<BulkRefreshTarget> failed = [];
  int consecutiveFailures = 0;

  /// 処理した頭数（成功＋失敗）
  int get processedCount => successCount + failed.length;

  void recordSuccess() {
    successCount++;
    consecutiveFailures = 0;
  }

  void recordFailure(BulkRefreshTarget target) {
    failed.add(target);
    consecutiveFailures++;
  }

  /// 失敗が [kBulkRefreshMaxConsecutiveFailures] 頭続いたら true
  bool get shouldAutoStop =>
      consecutiveFailures >= kBulkRefreshMaxConsecutiveFailures;
}
