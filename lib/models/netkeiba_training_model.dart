// lib/models/netkeiba_training_model.dart

import 'dart:convert';

// [追加] 調教タブ改修Step2: netkeiba の調教評価（レース×馬）と調教1本ごとのモデル (v.2026.9.22+26092211)

/// 併せ馬1件。例: 「内」「レイルジェット」「一杯と併せ０秒６先着」
class TrainingPartner {
  final String side; // 内 / 外 / 中（不明なら ''）
  final String? horseId; // 相手の馬ID
  final String name; // 相手の馬名
  final String text; // 相手の脚色と結果

  const TrainingPartner({
    required this.side,
    this.horseId,
    required this.name,
    required this.text,
  });

  /// 表示用の1行（例: 内レイルジェット一杯と併せ０秒６先着）
  String get fullText => '$side$name$text';

  Map<String, dynamic> toJson() => {
        'side': side,
        'horseId': horseId,
        'name': name,
        'text': text,
      };

  factory TrainingPartner.fromJson(Map<String, dynamic> json) {
    return TrainingPartner(
      side: json['side'] as String? ?? '',
      horseId: json['horseId'] as String?,
      name: json['name'] as String? ?? '',
      text: json['text'] as String? ?? '',
    );
  }
}

/// レース×馬の評価（短評・最終追切の評価・厩舎コメント）。
class NetkeibaTrainingReview {
  final String raceId;
  final String horseId;
  final String? shortReview; // 短評
  final String? critic; // 最終追切の評価文
  final String? rank; // 最終追切の A/B/C/D
  final String? stableComment; // 厩舎コメント本文
  final String? stableSpeaker; // 話者（例: 加藤公師）
  final String? stableMark; // 評価アイコン番号（例: '02' = ○）
  final String? oikiriFetchedAt;
  final String? commentFetchedAt;

  const NetkeibaTrainingReview({
    required this.raceId,
    required this.horseId,
    this.shortReview,
    this.critic,
    this.rank,
    this.stableComment,
    this.stableSpeaker,
    this.stableMark,
    this.oikiriFetchedAt,
    this.commentFetchedAt,
  });

  Map<String, dynamic> toMap() => {
        'race_id': raceId,
        'horse_id': horseId,
        'short_review': shortReview,
        'critic': critic,
        'rank': rank,
        'stable_comment': stableComment,
        'stable_speaker': stableSpeaker,
        'stable_mark': stableMark,
        'oikiri_fetched_at': oikiriFetchedAt,
        'comment_fetched_at': commentFetchedAt,
      };

  factory NetkeibaTrainingReview.fromMap(Map<String, dynamic> map) {
    return NetkeibaTrainingReview(
      raceId: map['race_id'] as String,
      horseId: map['horse_id'] as String,
      shortReview: map['short_review'] as String?,
      critic: map['critic'] as String?,
      rank: map['rank'] as String?,
      stableComment: map['stable_comment'] as String?,
      stableSpeaker: map['stable_speaker'] as String?,
      stableMark: map['stable_mark'] as String?,
      oikiriFetchedAt: map['oikiri_fetched_at'] as String?,
      commentFetchedAt: map['comment_fetched_at'] as String?,
    );
  }

  /// 既存行 [base] に重ねる。自分の値が null の項目は既存値を残す。
  NetkeibaTrainingReview mergeOnto(NetkeibaTrainingReview? base) {
    if (base == null) return this;
    return NetkeibaTrainingReview(
      raceId: raceId,
      horseId: horseId,
      shortReview: shortReview ?? base.shortReview,
      critic: critic ?? base.critic,
      rank: rank ?? base.rank,
      stableComment: stableComment ?? base.stableComment,
      stableSpeaker: stableSpeaker ?? base.stableSpeaker,
      stableMark: stableMark ?? base.stableMark,
      oikiriFetchedAt: oikiriFetchedAt ?? base.oikiriFetchedAt,
      commentFetchedAt: commentFetchedAt ?? base.commentFetchedAt,
    );
  }
}

/// netkeiba の調教1本。
/// 主キー: horseId + trainingDate + courseRaw + seq
/// （seq = 同じページ内で、同じ馬・同じ日・同じコースが複数あるときの出現順。通常 0）
class NetkeibaTrainingSession {
  static const int slotCount = 5;

  final String horseId;
  final String trainingDate; // YYYYMMDD
  final String courseRaw; // 表記そのまま（空白除去済み。例: ＣＷ / 栗坂）
  final int seq;
  final String? trainingTime; // HHmm（競走馬ページのみ）
  final String? trackCondition; // 良/稍/重/不
  final String? rider; // 乗り役
  final bool? isBestTime; // 一番時計なら true（それ以外は null）
  final List<double?> slots; // 時計5枠そのまま（長さ5）
  final List<double?> laps; // ラップ5枠（調教ページのみ。長さ5）
  final List<int?> colors; // 色の段階 0=なし 1=橙 2=薄黄（長さ5）
  final int? position; // 位置
  final String? trainingLoad; // 脚色（馬也・一杯…）
  final String? critic; // 評価文
  final String? rank; // A/B/C/D
  final List<TrainingPartner>? partners; // 併せ馬（無い・読めないときは null）
  final String? raceId; // どのレースに向けた調教か
  final String? source; // 'oikiri' / 'horse_page'
  final String? fetchedAt;

  NetkeibaTrainingSession({
    required this.horseId,
    required this.trainingDate,
    required this.courseRaw,
    required this.seq,
    this.trainingTime,
    this.trackCondition,
    this.rider,
    this.isBestTime,
    List<double?>? slots,
    List<double?>? laps,
    List<int?>? colors,
    this.position,
    this.trainingLoad,
    this.critic,
    this.rank,
    this.partners,
    this.raceId,
    this.source,
    this.fetchedAt,
  })  : slots = _fit<double>(slots),
        laps = _fit<double>(laps),
        colors = _fit<int>(colors);

  static List<T?> _fit<T>(List<T?>? source) {
    return List<T?>.generate(slotCount,
        (i) => (source != null && i < source.length) ? source[i] : null);
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'horse_id': horseId,
      'training_date': trainingDate,
      'course_raw': courseRaw,
      'seq': seq,
      'training_time': trainingTime,
      'track_condition': trackCondition,
      'rider': rider,
      'is_best_time': isBestTime == null ? null : (isBestTime! ? 1 : 0),
      'position': position,
      'training_load': trainingLoad,
      'critic': critic,
      'rank': rank,
      'partner_text':
          partners == null ? null : partners!.map((p) => p.fullText).join('\n'),
      'partner_json': partners == null
          ? null
          : jsonEncode(partners!.map((p) => p.toJson()).toList()),
      'race_id': raceId,
      'source': source,
      'fetched_at': fetchedAt,
    };
    for (int i = 0; i < slotCount; i++) {
      map['slot${i + 1}'] = slots[i];
      map['lap${i + 1}'] = laps[i];
      map['color${i + 1}'] = colors[i];
    }
    return map;
  }

  factory NetkeibaTrainingSession.fromMap(Map<String, dynamic> map) {
    List<TrainingPartner>? partners;
    final partnerJson = map['partner_json'] as String?;
    if (partnerJson != null && partnerJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(partnerJson) as List<dynamic>;
        partners = decoded
            .map((e) => TrainingPartner.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        partners = null;
      }
    }
    final isBest = map['is_best_time'] as int?;
    return NetkeibaTrainingSession(
      horseId: map['horse_id'] as String,
      trainingDate: map['training_date'] as String,
      courseRaw: map['course_raw'] as String,
      seq: map['seq'] as int,
      trainingTime: map['training_time'] as String?,
      trackCondition: map['track_condition'] as String?,
      rider: map['rider'] as String?,
      isBestTime: isBest == null ? null : isBest == 1,
      slots: List<double?>.generate(
          slotCount, (i) => (map['slot${i + 1}'] as num?)?.toDouble()),
      laps: List<double?>.generate(
          slotCount, (i) => (map['lap${i + 1}'] as num?)?.toDouble()),
      colors: List<int?>.generate(
          slotCount, (i) => (map['color${i + 1}'] as num?)?.toInt()),
      position: map['position'] as int?,
      trainingLoad: map['training_load'] as String?,
      critic: map['critic'] as String?,
      rank: map['rank'] as String?,
      partners: partners,
      raceId: map['race_id'] as String?,
      source: map['source'] as String?,
      fetchedAt: map['fetched_at'] as String?,
    );
  }

  /// 既存行 [base] に重ねる。自分の値が null の項目（5枠は1つずつ）は既存値を残す。
  /// 例: 調教ページ（時刻なし・ラップあり）の行に、競走馬ページ（時刻あり・ラップなし）を重ねると両方そろう。
  NetkeibaTrainingSession mergeOnto(NetkeibaTrainingSession? base) {
    if (base == null) return this;
    return NetkeibaTrainingSession(
      horseId: horseId,
      trainingDate: trainingDate,
      courseRaw: courseRaw,
      seq: seq,
      trainingTime: trainingTime ?? base.trainingTime,
      trackCondition: trackCondition ?? base.trackCondition,
      rider: rider ?? base.rider,
      isBestTime: isBestTime ?? base.isBestTime,
      slots: List<double?>.generate(slotCount, (i) => slots[i] ?? base.slots[i]),
      laps: List<double?>.generate(slotCount, (i) => laps[i] ?? base.laps[i]),
      colors:
          List<int?>.generate(slotCount, (i) => colors[i] ?? base.colors[i]),
      position: position ?? base.position,
      trainingLoad: trainingLoad ?? base.trainingLoad,
      critic: critic ?? base.critic,
      rank: rank ?? base.rank,
      partners: partners ?? base.partners,
      raceId: raceId ?? base.raceId,
      source: source ?? base.source,
      fetchedAt: fetchedAt ?? base.fetchedAt,
    );
  }
}
