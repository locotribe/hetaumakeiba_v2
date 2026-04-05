// lib/models/horse_profile_model.dart

class HorseProfile {
  final String horseId;
  final String horseName;
  // [追加] 性別プロパティを追加 (v.13)
  final String gender;
  final String birthday; // 生年月日
  final String ownerId; // 馬主ID
  final String ownerName; // 馬主名
  final String ownerImageLocalPath; // 勝負服画像のローカルパス
  final String trainerId; // 調教師ID
  final String trainerName; // 調教師名
  final String breederName; // 生産者名
  final String fatherId; // 父ID
  final String fatherName; // 父名
  final String motherId; // 母ID
  final String motherName; // 母名
  final String ffName; // 父父名
  final String fmName; // 父母名
  final String mfName; // 母父名
  final String mmName; // 母母名
  final String lastUpdated; // 最終更新日時

  HorseProfile({
    required this.horseId,
    required this.horseName,
    // [追加] コンストラクタに性別を追加 (v.13)
    required this.gender,
    required this.birthday,
    required this.ownerId,
    required this.ownerName,
    required this.ownerImageLocalPath,
    required this.trainerId,
    required this.trainerName,
    required this.breederName,
    required this.fatherId,
    required this.fatherName,
    required this.motherId,
    required this.motherName,
    required this.ffName,
    required this.fmName,
    required this.mfName,
    required this.mmName,
    required this.lastUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'horseId': horseId,
      'horseName': horseName,
      // [追加] toMapに性別を追加 (v.13)
      'gender': gender,
      'birthday': birthday,
      'ownerId': ownerId,
      'ownerName': ownerName,
      'ownerImageLocalPath': ownerImageLocalPath,
      'trainerId': trainerId,
      'trainerName': trainerName,
      'breederName': breederName,
      'fatherId': fatherId,
      'fatherName': fatherName,
      'motherId': motherId,
      'motherName': motherName,
      'ffName': ffName,
      'fmName': fmName,
      'mfName': mfName,
      'mmName': mmName,
      'lastUpdated': lastUpdated,
    };
  }

  factory HorseProfile.fromMap(Map<String, dynamic> map) {
    return HorseProfile(
      horseId: map['horseId'] as String,
      horseName: map['horseName'] as String? ?? '',
      // [追加] fromMapに性別を追加 (v.13)
      gender: map['gender'] as String? ?? '',
      birthday: map['birthday'] as String? ?? '',
      ownerId: map['ownerId'] as String? ?? '',
      ownerName: map['ownerName'] as String? ?? '',
      ownerImageLocalPath: map['ownerImageLocalPath'] as String? ?? '',
      trainerId: map['trainerId'] as String? ?? '',
      trainerName: map['trainerName'] as String? ?? '',
      breederName: map['breederName'] as String? ?? '',
      fatherId: map['fatherId'] as String? ?? '',
      fatherName: map['fatherName'] as String? ?? '',
      motherId: map['motherId'] as String? ?? '',
      motherName: map['motherName'] as String? ?? '',
      ffName: map['ffName'] as String? ?? '',
      fmName: map['fmName'] as String? ?? '',
      mfName: map['mfName'] as String? ?? '',
      mmName: map['mmName'] as String? ?? '',
      lastUpdated: map['lastUpdated'] as String,
    );
  }
}