// lib/models/training_time_model.dart

/// 競走馬の調教タイムを保持するデータモデルクラスです。
class TrainingTimeModel {
  final String horseId; // 馬ID
  final String trainingDate; // 調教日 (YYYYMMDD)
  final String trainingTime; // 時間 (HHmm)
  final String trackType; // 坂路 or ウッド
  final String location; // 栗東, 美浦など
  final double? f6; // 6Fタイム
  final double? f5; // 5Fタイム
  final double? f4; // 4Fタイム
  final double? f3; // 3Fタイム
  final double? f2; // 2Fタイム
  final double? f1; // 1Fタイム
  final String? stableName; // 厩舎名

  TrainingTimeModel({
    required this.horseId,
    required this.trainingDate,
    required this.trainingTime,
    required this.trackType,
    required this.location,
    this.f6,
    this.f5,
    this.f4,
    this.f3,
    this.f2,
    this.f1,
    this.stableName,
  });

  /// TrainingTimeModelオブジェクトからMapを生成するメソッドです（データベース保存用）。
  Map<String, dynamic> toMap() {
    return {
      'horse_id': horseId,
      'training_date': trainingDate,
      'training_time': trainingTime,
      'track_type': trackType,
      'location': location,
      'f6': f6,
      'f5': f5,
      'f4': f4,
      'f3': f3,
      'f2': f2,
      'f1': f1,
      'stable_name': stableName,
    };
  }

  /// データベースのMapからTrainingTimeModelオブジェクトを生成するメソッドです。
  factory TrainingTimeModel.fromMap(Map<String, dynamic> map) {
    return TrainingTimeModel(
      horseId: map['horse_id'] as String,
      trainingDate: map['training_date'] as String,
      trainingTime: map['training_time'] as String,
      trackType: map['track_type'] as String,
      location: map['location'] as String,
      f6: map['f6'] as double?,
      f5: map['f5'] as double?,
      f4: map['f4'] as double?,
      f3: map['f3'] as double?,
      f2: map['f2'] as double?,
      f1: map['f1'] as double?,
      stableName: map['stable_name'] as String?,
    );
  }
}