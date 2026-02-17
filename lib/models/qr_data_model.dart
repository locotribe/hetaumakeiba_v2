// lib/models/qr_data_model.dart

class QrData {
  final int? id; // データベースID
  final String userId; // 所有者を示すユーザーID
  final String? raceId;
  final String qrCode; // 190桁のQRコードデータ
  final DateTime timestamp; // 保存日時
  final String parsedDataJson; // 解析済みデータをJSON文字列で保持

  QrData({
    this.id,
    required this.userId,
    this.raceId,
    required this.qrCode,
    required this.timestamp,
    required this.parsedDataJson,
  });

  // MapからQrDataオブジェクトを生成するファクトリコンストラクタ
  factory QrData.fromMap(Map<String, dynamic> map) {
    return QrData(
      id: map['id'] as int?,
      userId: map['userId'] as String? ?? '',
      raceId: map['race_id'] as String?,
      qrCode: map['qr_code'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      parsedDataJson: map['parsed_data_json'] as String? ?? '{}',
    );
  }

  // QrDataオブジェクトからMapを生成するメソッド (データベース保存用)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'race_id': raceId,
      'qr_code': qrCode,
      'timestamp': timestamp.toIso8601String(),
      'parsed_data_json': parsedDataJson,
    };
  }
}