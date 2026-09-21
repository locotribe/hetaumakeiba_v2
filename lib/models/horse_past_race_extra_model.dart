// lib/models/horse_past_race_extra_model.dart

import 'dart:convert';

/// 過去走の通過順1コーナー分（位置と注記）。
/// 注記は競馬新聞ページの「出」「不」「ア」「接」「鈍」「膨」など。無い場合は空文字。
class PastRaceCorner {
  final String position; // 通過順位 (例: '11'。不明時は '-')
  final String note; // 注記 (例: '出')

  const PastRaceCorner({required this.position, required this.note});

  Map<String, dynamic> toJson() => {'pos': position, 'note': note};

  factory PastRaceCorner.fromJson(Map<String, dynamic> json) => PastRaceCorner(
        position: (json['pos'] ?? '').toString(),
        note: (json['note'] ?? '').toString(),
      );
}

/// 過去走1走ごとの追加情報を保持するモデル。キーは (horseId, raceId)。
/// 競馬新聞ページ・競走馬データベースページから取得する。
/// 取得できない項目（有料会員限定で伏せ字、空欄など）は null とする。
class HorsePastRaceExtra {
  final String horseId;
  final String raceId;
  final String? raceCondition; // 条件 (例: '国際 別定')
  final String? courseSection; // 回り・コース区分 (例: '右B', '右 外C')
  final String? paceMark; // ペース記号 ('S' / 'M' / 'H')
  final List<PastRaceCorner>? corners; // 通過順と注記
  final int? agariRank; // 上がり3F順位
  final bool? isRecord; // レコード
  final bool? isBlinker; // その走でのブリンカー着用
  final String? winnerHorseId; // 勝ち馬(2着馬)の馬ID
  final double? individualFirst3f; // 個別前半3F（スーパープレミアム以上のみ）
  final String? shortComment; // 短評（スーパープレミアム以上のみ）
  final int? timeIndex; // タイム指数
  final int? trackIndex; // 馬場指数
  final String? remark; // 備考 (例: '出遅れ')
  final String? newspaperFetchedAt; // 新聞ページから保存した日時 (ISO8601)
  final String? horsePageFetchedAt; // 競走馬ページから保存した日時 (ISO8601)
  final bool? horsePagePremium; // 競走馬ページ取得時にnetkeibaログイン中だったか

  const HorsePastRaceExtra({
    required this.horseId,
    required this.raceId,
    this.raceCondition,
    this.courseSection,
    this.paceMark,
    this.corners,
    this.agariRank,
    this.isRecord,
    this.isBlinker,
    this.winnerHorseId,
    this.individualFirst3f,
    this.shortComment,
    this.timeIndex,
    this.trackIndex,
    this.remark,
    this.newspaperFetchedAt,
    this.horsePageFetchedAt,
    this.horsePagePremium,
  });

  static int? _boolToInt(bool? value) => value == null ? null : (value ? 1 : 0);

  static bool? _intToBool(dynamic value) => value == null ? null : (value as int) == 1;

  Map<String, dynamic> toMap() {
    return {
      'horse_id': horseId,
      'race_id': raceId,
      'race_condition': raceCondition,
      'course_section': courseSection,
      'pace_mark': paceMark,
      'corners_json': corners == null
          ? null
          : jsonEncode(corners!.map((c) => c.toJson()).toList()),
      'agari_rank': agariRank,
      'is_record': _boolToInt(isRecord),
      'is_blinker': _boolToInt(isBlinker),
      'winner_horse_id': winnerHorseId,
      'individual_first_3f': individualFirst3f,
      'short_comment': shortComment,
      'time_index': timeIndex,
      'track_index': trackIndex,
      'remark': remark,
      'newspaper_fetched_at': newspaperFetchedAt,
      'horse_page_fetched_at': horsePageFetchedAt,
      'horse_page_premium': _boolToInt(horsePagePremium),
    };
  }

  factory HorsePastRaceExtra.fromMap(Map<String, dynamic> map) {
    List<PastRaceCorner>? corners;
    final cornersJson = map['corners_json'] as String?;
    if (cornersJson != null && cornersJson.isNotEmpty) {
      try {
        corners = (jsonDecode(cornersJson) as List<dynamic>)
            .map((e) => PastRaceCorner.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (_) {
        corners = null;
      }
    }
    return HorsePastRaceExtra(
      horseId: map['horse_id'] as String,
      raceId: map['race_id'] as String,
      raceCondition: map['race_condition'] as String?,
      courseSection: map['course_section'] as String?,
      paceMark: map['pace_mark'] as String?,
      corners: corners,
      agariRank: map['agari_rank'] as int?,
      isRecord: _intToBool(map['is_record']),
      isBlinker: _intToBool(map['is_blinker']),
      winnerHorseId: map['winner_horse_id'] as String?,
      individualFirst3f: (map['individual_first_3f'] as num?)?.toDouble(),
      shortComment: map['short_comment'] as String?,
      timeIndex: map['time_index'] as int?,
      trackIndex: map['track_index'] as int?,
      remark: map['remark'] as String?,
      newspaperFetchedAt: map['newspaper_fetched_at'] as String?,
      horsePageFetchedAt: map['horse_page_fetched_at'] as String?,
      horsePagePremium: _intToBool(map['horse_page_premium']),
    );
  }

  /// [base]（既存の保存値）に対し、自身の null でない項目だけを上書きした新しいインスタンスを返す。
  /// 伏せ字・空欄は保存前に null にしているため、有料データが後から消えることはない。
  HorsePastRaceExtra mergeOnto(HorsePastRaceExtra? base) {
    if (base == null) return this;
    return HorsePastRaceExtra(
      horseId: horseId,
      raceId: raceId,
      raceCondition: raceCondition ?? base.raceCondition,
      courseSection: courseSection ?? base.courseSection,
      paceMark: paceMark ?? base.paceMark,
      corners: corners ?? base.corners,
      agariRank: agariRank ?? base.agariRank,
      isRecord: isRecord ?? base.isRecord,
      isBlinker: isBlinker ?? base.isBlinker,
      winnerHorseId: winnerHorseId ?? base.winnerHorseId,
      individualFirst3f: individualFirst3f ?? base.individualFirst3f,
      shortComment: shortComment ?? base.shortComment,
      timeIndex: timeIndex ?? base.timeIndex,
      trackIndex: trackIndex ?? base.trackIndex,
      remark: remark ?? base.remark,
      newspaperFetchedAt: newspaperFetchedAt ?? base.newspaperFetchedAt,
      horsePageFetchedAt: horsePageFetchedAt ?? base.horsePageFetchedAt,
      horsePagePremium: horsePagePremium ?? base.horsePagePremium,
    );
  }

  /// 取得した文字列を保存用に正規化する。空欄・伏せ字（＊ / *）・'----' は null を返す。
  static String? normalizeScrapedText(dynamic value) {
    if (value == null) return null;
    final text = value.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty) return null;
    if (text.contains('＊') || text.contains('*')) return null;
    if (RegExp(r'^[-－]+$').hasMatch(text)) return null;
    return text;
  }
}
