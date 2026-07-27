// lib/models/shutuba_horse_detail_model.dart

class ShutubaHorseDetail {
  final String horseId;
  final int horseNumber; // 馬番
  final int gateNumber; // 枠番
  final String horseName; // 馬名
  final String sexAndAge; // 性齢
  final String jockey; // 騎手
  final String jockeyId; // 騎手ID
  final double carriedWeight; // 斤量
  final String trainerName; // 調教師
  final String trainerAffiliation; // 所属
  final String? horseWeight;  //  馬体重
  double? odds; // オッズ (変動するためNullable)
  int? popularity; // 人気 (変動するためNullable)
  final bool isScratched; // 出走取消フラグ

  // ▼ [追加] 競馬新聞ページから取得するマーク情報 (v.2026.7.27+26072708)
  bool isBlinker;
  bool isFirstBlinker;
  bool isMaruGai;
  bool isMaruChi;
  // ▲ [追加]

  ShutubaHorseDetail({
    required this.horseId,
    required this.horseNumber,
    required this.gateNumber,
    required this.horseName,
    required this.sexAndAge,
    required this.jockey,
    required this.jockeyId,
    required this.carriedWeight,
    required this.trainerName,
    required this.trainerAffiliation,
    this.horseWeight,
    this.odds,
    this.popularity,
    this.isScratched = false,
    // ▼ [追加] 競馬新聞ページから取得するマーク情報 (v.2026.7.27+26072708)
    this.isBlinker = false,
    this.isFirstBlinker = false,
    this.isMaruGai = false,
    this.isMaruChi = false,
    // ▲ [追加]
  });

  Map<String, dynamic> toMap() {
    return {
      'horseId': horseId,
      'horseNumber': horseNumber,
      'gateNumber': gateNumber,
      'horseName': horseName,
      'sexAndAge': sexAndAge,
      'jockey': jockey,
      'jockeyId': jockeyId,
      'carriedWeight': carriedWeight,
      'trainerName': trainerName,
      'trainerAffiliation': trainerAffiliation,
      'horseWeight': horseWeight,
      'odds': odds,
      'popularity': popularity,
      'isScratched': isScratched ? 1 : 0,
      // ▼ [追加] 競馬新聞ページから取得するマーク情報 (v.2026.7.27+26072708)
      'isBlinker': isBlinker,
      'isFirstBlinker': isFirstBlinker,
      'isMaruGai': isMaruGai,
      'isMaruChi': isMaruChi,
      // ▲ [追加]
    };
  }

  factory ShutubaHorseDetail.fromMap(Map<String, dynamic> map) {
    return ShutubaHorseDetail(
      horseId: map['horseId'] as String,
      horseNumber: map['horseNumber'] as int,
      gateNumber: map['gateNumber'] as int,
      horseName: map['horseName'] as String,
      sexAndAge: map['sexAndAge'] as String,
      jockey: map['jockey'] as String,
      jockeyId: map['jockeyId'] as String? ?? '', // 旧バージョンとの互換性のため
      carriedWeight: (map['carriedWeight'] as num).toDouble(),
      trainerName: map['trainerName'] as String,
      trainerAffiliation: map['trainerAffiliation'] as String,
      horseWeight: map['horseWeight'] as String?,
      odds: (map['odds'] as num?)?.toDouble(),
      popularity: map['popularity'] as int?,
      isScratched: map['isScratched'] == 1,
      // ▼ [追加] 競馬新聞ページから取得するマーク情報。旧キャッシュに無ければfalse (v.2026.7.27+26072708)
      isBlinker: map['isBlinker'] as bool? ?? false,
      isFirstBlinker: map['isFirstBlinker'] as bool? ?? false,
      isMaruGai: map['isMaruGai'] as bool? ?? false,
      isMaruChi: map['isMaruChi'] as bool? ?? false,
      // ▲ [追加]
    );
  }
}