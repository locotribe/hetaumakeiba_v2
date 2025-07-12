// lib/models/data_model.dart
class Ticket {
  final String qr;
  final String venue;
  final int round;
  final int day;
  final int race;
  final String betType;
  final List<Map<String, dynamic>> purchaseDetails;
  final String url;

  Ticket({
    required this.qr,
    required this.venue,
    required this.round,
    required this.day,
    required this.race,
    required this.betType,
    required this.purchaseDetails,
    required this.url,
  });

  factory Ticket.fromMap(Map<String, dynamic> map) {
    return Ticket(
      qr: map['QR'] as String,
      venue: map['開催場'] as String,
      round: map['回'] as int,
      day: map['日'] as int,
      race: map['レース'] as int,
      betType: map['方式'] as String,
      purchaseDetails: (map['購入内容'] as List).cast<Map<String, dynamic>>(),
      url: map['URL'] as String,
    );
  }

  Map<String, dynamic> toMap() => {
    'QR': qr,
    '開催場': venue,
    '回': round,
    '日': day,
    'レース': race,
    '方式': betType,
    '購入内容': purchaseDetails,
    'URL': url,
  };
}