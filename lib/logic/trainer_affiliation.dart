// lib/logic/trainer_affiliation.dart

// [追加] 陣営の本気度指数: 調教師の所属（美浦・栗東・地方・海外）を1か所で扱う。
// ページごとに書き方が違う所属（「美浦」「美」「[東]」「(栗東)」など）を1つの種類に読み替える。
// 保存済みの値は変えず、読むときにこの関数で揃える。DB・通信には触れない (v.2026.10.2+26100209)

/// 調教師の所属。
enum TrainerAffiliation {
  /// 美浦トレーニングセンター（関東・東）
  miho,

  /// 栗東トレーニングセンター（関西・西）
  ritto,

  /// 地方競馬
  local,

  /// 海外
  overseas,

  /// 分からない（空や読めない書き方）
  unknown,
}

/// 所属の書き方を種類に読み替える。
///
/// 読める書き方:
/// - 出馬表・速報の結果: 「美浦」「栗東」（例「栗東[藤野]」のように後ろに続いてもよい）
/// - db版の結果（保存済みの古い値）: 「美」「栗」（1文字だけのとき）
/// - db.netkeiba の表示: 「[東]」「[西]」「[地]」「[外]」
/// - 競走馬ページ: 「友道康夫 (栗東)」のような括弧書き
/// - 「地方」「海外」
TrainerAffiliation parseTrainerAffiliation(String text) {
  final t = text.trim();
  if (t.isEmpty) return TrainerAffiliation.unknown;
  if (t.contains('美浦') || t.contains('[東]') || t == '美') {
    return TrainerAffiliation.miho;
  }
  if (t.contains('栗東') || t.contains('[西]') || t == '栗') {
    return TrainerAffiliation.ritto;
  }
  if (t.contains('地方') || t.contains('[地]')) return TrainerAffiliation.local;
  if (t.contains('海外') || t.contains('[外]')) return TrainerAffiliation.overseas;
  return TrainerAffiliation.unknown;
}

/// 表示名（「美浦」「栗東」「地方」「海外」、分からなければ空）。
String trainerAffiliationLabel(TrainerAffiliation affiliation) {
  switch (affiliation) {
    case TrainerAffiliation.miho:
      return '美浦';
    case TrainerAffiliation.ritto:
      return '栗東';
    case TrainerAffiliation.local:
      return '地方';
    case TrainerAffiliation.overseas:
      return '海外';
    case TrainerAffiliation.unknown:
      return '';
  }
}
