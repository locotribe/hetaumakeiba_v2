// lib/models/qr_data_model.dart

class QrData {
  final int? id; // データベースID (自動生成されるためnullable)
  final String qrCode; // 190桁のQRコードデータ
  final DateTime timestamp; // 保存日時
  final String parsedDataJson; // 解析済みデータをJSON文字列で保持

  // --- ▼▼▼ Step 1 で追加 ▼▼▼ ---
  final String? status; // "processing", "unsettled", "settled"
  final bool? isHit; // 的中したか
  final int? payout; // 払戻金額
  final String? hitDetails; // 的中詳細 (JSON文字列)
  // --- ▲▲▲ Step 1 で追加 ▲▲▲ ---

  QrData({
    this.id,
    required this.qrCode,
    required this.timestamp,
    required this.parsedDataJson,
    // --- ▼▼▼ Step 1 で追加 ▼▼▼ ---
    this.status,
    this.isHit,
    this.payout,
    this.hitDetails,
    // --- ▲▲▲ Step 1 で追加 ▲▲▲ ---
  });

  // MapからQrDataオブジェクトを生成するファクトリコンストラクタ
  factory QrData.fromMap(Map<String, dynamic> map) {
    return QrData(
      id: map['id'] as int?,
      qrCode: map['qr_code'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      parsedDataJson: map['parsed_data_json'] as String? ?? '{}',
      // --- ▼▼▼ Step 1 で追加 ▼▼▼ ---
      status: map['status'] as String?,
      isHit: map['isHit'] == null ? null : map['isHit'] == 1, // INTEGER to bool
      payout: map['payout'] as int?,
      hitDetails: map['hitDetails'] as String?,
      // --- ▲▲▲ Step 1 で追加 ▲▲▲ ---
    );
  }

  // QrDataオブジェクトからMapを生成するメソッド (データベース保存用)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'qr_code': qrCode,
      'timestamp': timestamp.toIso8601String(),
      'parsed_data_json': parsedDataJson,
      // --- ▼▼▼ Step 1 で追加 ▼▼▼ ---
      'status': status,
      'isHit': isHit == null ? null : (isHit! ? 1 : 0), // bool to INTEGER
      'payout': payout,
      'hitDetails': hitDetails,
      // --- ▲▲▲ Step 1 で追加 ▲▲▲ ---
    };
  }
}