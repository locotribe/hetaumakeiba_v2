// lib/models/ticket_status_enum.dart
enum TicketStatus {
  processing,
  unsettled,
  settled
}

// 文字列からenumに変換するための拡張メソッド
extension StringToTicketStatus on String {
  TicketStatus toTicketStatus() {
    return TicketStatus.values.firstWhere(
          (e) => e.name == this,
      orElse: () => throw ArgumentError('Unknown status string: $this'),
    );
  }
}