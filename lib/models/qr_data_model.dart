// lib/models/qr_data_model.dart

class QrData {
  final int? id; // データベースID (自動生成されるためnullable)
  final String qrCode; // 190桁のQRコードデータ
  final DateTime timestamp; // 保存日時
  final String parsedDataJson; // 解析済みデータをJSON文字列で保持

  QrData({
    this.id,
    required this.qrCode,
    required this.timestamp,
    required this.parsedDataJson,
  });

  // MapからQrDataオブジェクトを生成するファクトリコンストラクタ
  factory QrData.fromMap(Map<String, dynamic> map) {
    return QrData(
      id: map['id'] as int?,
      qrCode: map['qr_code'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      // DBにまだこの列がない場合も考慮し、nullなら空のJSONオブジェクトを返す
      parsedDataJson: map['parsed_data_json'] as String? ?? '{}',
    );
  }

  // QrDataオブジェクトからMapを生成するメソッド (データベース保存用)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'qr_code': qrCode,
      'timestamp': timestamp.toIso8601String(),
      'parsed_data_json': parsedDataJson,
    };
  }
}