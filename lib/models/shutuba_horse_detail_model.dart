// lib/models/shutuba_horse_detail_model.dart

class ShutubaHorseDetail {
  final String horseId;
  final int horseNumber; // 馬番
  final int gateNumber; // 枠番
  final String horseName; // 馬名
  final String sexAndAge; // 性齢
  final String jockey; // 騎手
  final double carriedWeight; // 斤量
  final String trainer;
  final String? horseWeight;
  double? odds; // オッズ (変動するためNullable)
  int? popularity; // 人気 (変動するためNullable)
  final bool isScratched; // 出走取消フラグ

  ShutubaHorseDetail({
    required this.horseId,
    required this.horseNumber,
    required this.gateNumber,
    required this.horseName,
    required this.sexAndAge,
    required this.jockey,
    required this.carriedWeight,
    required this.trainer,
    this.horseWeight,
    this.odds,
    this.popularity,
    this.isScratched = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'horseId': horseId,
      'horseNumber': horseNumber,
      'gateNumber': gateNumber,
      'horseName': horseName,
      'sexAndAge': sexAndAge,
      'jockey': jockey,
      'carriedWeight': carriedWeight,
      'trainer': trainer,
      'horseWeight': horseWeight,
      'odds': odds,
      'popularity': popularity,
      'isScratched': isScratched ? 1 : 0, // SQLiteではboolをINTEGERで保存
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
      carriedWeight: (map['carriedWeight'] as num).toDouble(), // numからdoubleにキャスト
      trainer: map['trainer'] as String,
      horseWeight: map['horseWeight'] as String?,
      odds: (map['odds'] as num?)?.toDouble(), // numからdoubleにキャスト, null許容
      popularity: map['popularity'] as int?,
      isScratched: map['isScratched'] == 1,
    );
  }
}