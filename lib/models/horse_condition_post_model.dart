// lib/models/horse_condition_post_model.dart

// [追加] 出走の意味 調教の行 Step1: netkeiba の近況（horse_info_state.html）の投稿1件。horse_condition_posts テーブルの1行に対応する（表は Step3 で作る） (v.2026.10.24+26102401)

/// netkeiba の近況の投稿1件。
class HorseConditionPost {
  /// 馬ID
  final String horseId;

  /// 投稿の日時（YYYYMMDDHHmmss）
  final String postedAt;

  /// 同じ日時の投稿の順（ページの上から0, 1, …）
  final int seq;

  /// 見出し（例: 放牧）
  final String title;

  /// 本文（例: 休養のため放牧／放牧から帰厩）
  final String body;

  /// 取得した日時（ISO 8601）
  final String fetchedAt;

  const HorseConditionPost({
    required this.horseId,
    required this.postedAt,
    required this.seq,
    required this.title,
    required this.body,
    required this.fetchedAt,
  });

  /// 投稿の日（YYYYMMDD）。読めなければ空。
  String get postedDate => postedAt.length >= 8 ? postedAt.substring(0, 8) : '';

  /// 放牧に出た投稿か（見出しが「放牧」で、本文に「帰厩」を含まない）。帰厩の投稿は使わない。
  bool get isLayoffPost => title == '放牧' && !body.contains('帰厩');

  /// horse_condition_posts テーブルの1行にする。
  Map<String, Object?> toMap() {
    return {
      'horse_id': horseId,
      'posted_at': postedAt,
      'seq': seq,
      'title': title,
      'body': body,
      'fetched_at': fetchedAt,
    };
  }

  /// horse_condition_posts テーブルの1行を読む。読めなければ null。
  static HorseConditionPost? fromMap(Map<String, Object?> map) {
    final horseId = map['horse_id'];
    final postedAt = map['posted_at'];
    final seq = map['seq'];
    final title = map['title'];
    final body = map['body'];
    final fetchedAt = map['fetched_at'];
    if (horseId is! String ||
        postedAt is! String ||
        seq is! int ||
        title is! String ||
        body is! String) {
      return null;
    }
    return HorseConditionPost(
      horseId: horseId,
      postedAt: postedAt,
      seq: seq,
      title: title,
      body: body,
      fetchedAt: fetchedAt is String ? fetchedAt : '',
    );
  }
}
