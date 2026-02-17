// lib/models/jyusyoichiran_page_data_model.dart

/// 重賞一覧ページ専用の軽量データモデル
class JyusyoRace {
  final int? id;          // DBのプライマリキー
  final String? raceId;   // 12桁のレースID (未定の場合はnull)
  final int year;         // ★追加: 開催年 (例: 2026)
  final String date;      // 日付 (例: "01/05(日)")
  final String raceName;  // レース名 (例: "中山金杯")
  final String grade;     // 格 (G1, G2, G3)
  final String venue;     // 開催場 (例: "中山")
  final String distance;  // 距離 (例: "芝2000m")
  final String conditions;// 条件 (例: "4歳上")
  final String weight;    // 重量 (例: "ハンデ")
  final String? sourceUrl;// ID取得元のURL

  JyusyoRace({
    this.id,
    this.raceId,
    required this.year, // ★追加
    required this.date,
    required this.raceName,
    required this.grade,
    required this.venue,
    required this.distance,
    required this.conditions,
    required this.weight,
    this.sourceUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'race_id': raceId,
      'year': year, // ★追加
      'date': date,
      'race_name': raceName,
      'grade': grade,
      'venue': venue,
      'distance': distance,
      'conditions': conditions,
      'weight': weight,
      'source_url': sourceUrl,
    };
  }

  factory JyusyoRace.fromMap(Map<String, dynamic> map) {
    return JyusyoRace(
      id: map['id'] as int?,
      raceId: map['race_id'] as String?,
      year: map['year'] as int, // ★追加
      date: map['date'] as String,
      raceName: map['race_name'] as String,
      grade: map['grade'] as String,
      venue: map['venue'] as String,
      distance: map['distance'] as String,
      conditions: map['conditions'] as String,
      weight: map['weight'] as String,
      sourceUrl: map['source_url'] as String?,
    );
  }
}