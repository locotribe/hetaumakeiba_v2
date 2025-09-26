// lib/models/course_preset_model.dart

/// コースの物理的な特徴を格納するデータモデル。
/// レースごとに変動する情報は含まず、不変的な静的データのみを扱う。
class CoursePreset {
  /// ユニークID (例: '05_shiba_1600')
  final String id;

  /// 競馬場コード (例: '05')
  final String venueCode;

  /// 競馬場名 (例: '東京')
  final String venueName;

  /// トラック種別と距離 (例: '芝1600')
  final String distance;

  /// 回り方向 (例: '左回り')
  final String direction;

  /// ゴール前の直線長 (メートル)
  final int straightLength;

  /// コース全体のレイアウトや起伏に関する客観的な特徴
  final String courseLayout;

  /// 枠順の有利不利、特殊なスタート地点など、予想における重要なポイント
  final String keyPoints;

  CoursePreset({
    required this.id,
    required this.venueCode,
    required this.venueName,
    required this.distance,
    required this.direction,
    required this.straightLength,
    required this.courseLayout,
    required this.keyPoints,
  });

  /// データベース保存用にMap形式に変換するメソッド
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'venueCode': venueCode,
      'venueName': venueName,
      'distance': distance,
      'direction': direction,
      'straightLength': straightLength,
      'courseLayout': courseLayout,
      'keyPoints': keyPoints,
    };
  }
}