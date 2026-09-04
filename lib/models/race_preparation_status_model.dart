// lib/models/race_preparation_status_model.dart

// [追加] Phase 4-A: レース準備パイプライン（出馬表〜過去10年統計）の取得状態を
// 永続化するためのモデル。race_preparation_status テーブルに対応する (v.2026.9.5+26090501)

/// レース準備パイプラインの各ステップ。
enum PreparationStep {
  /// 出馬表 + 競馬新聞マーク。
  shutuba,

  /// 各馬のプロフィール（馬主・血統・馬主画像）。
  horseProfile,

  /// 各馬の過去成績。
  horsePerformance,

  /// 過去成績に出てくるレース結果。
  pastRaceResults,

  /// 調教データ（pakara坂路 + ウッド）。
  training,

  /// 同レースの過去10年統計。
  raceStatistics,
}

/// 各ステップの取得状態。
enum PreparationState {
  /// 未着手。
  pending,

  /// 実行中。
  running,

  /// 完了（itemCount が 0 の「完了だが0件」もこれに含む）。
  done,

  /// 失敗（error に理由）。
  failed,

  /// このレースでは取得対象外。
  skipped,
}

/// あるレースの、あるステップの準備状態を表す。
class RacePreparationStatus {
  final String raceId;
  final PreparationStep step;
  final PreparationState state;

  /// 取得できた件数。「未取得」と「取得済み0件」の区別に使う。
  final int itemCount;

  final DateTime updatedAt;

  /// 失敗理由（state == failed のときのみ意味を持つ）。
  final String? error;

  RacePreparationStatus({
    required this.raceId,
    required this.step,
    required this.state,
    this.itemCount = 0,
    required this.updatedAt,
    this.error,
  });

  factory RacePreparationStatus.fromMap(Map<String, dynamic> map) {
    return RacePreparationStatus(
      raceId: map['race_id'] as String,
      step: PreparationStep.values
          .firstWhere((e) => e.name == map['step'] as String),
      state: PreparationState.values.firstWhere(
        (e) => e.name == map['state'] as String,
        orElse: () => PreparationState.pending,
      ),
      itemCount: map['item_count'] as int,
      updatedAt: DateTime.parse(map['updated_at'] as String),
      error: map['error'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'race_id': raceId,
      'step': step.name,
      'state': state.name,
      'item_count': itemCount,
      'updated_at': updatedAt.toIso8601String(),
      'error': error,
    };
  }
}
