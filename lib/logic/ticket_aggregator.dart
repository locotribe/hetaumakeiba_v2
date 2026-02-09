// lib/logic/ticket_aggregator.dart

import 'package:hetaumakeiba_v2/models/ticket_list_item.dart';

class TicketStats {
  final int totalCount;
  final int hitCount;
  final int totalPurchase;
  final int totalPayout;
  final int balance;
  final double hitRate;

  TicketStats({
    required this.totalCount,
    required this.hitCount,
    required this.totalPurchase,
    required this.totalPayout,
    required this.balance,
    required this.hitRate,
  });
}

class TicketAggregator {
  static TicketStats calculateMonthlyStats(List<TicketListItem> items) {
    int totalCount = items.length;
    int hitCount = 0;
    int totalPurchase = 0;
    int totalPayout = 0;

    for (final item in items) {
      if (item.hitResult?.isHit == true) {
        hitCount++;
      }
      totalPurchase += (item.parsedTicket['合計金額'] as int? ?? 0);
      totalPayout += (item.hitResult?.totalPayout ?? 0) + (item.hitResult?.totalRefund ?? 0);
    }

    final balance = totalPayout - totalPurchase;
    final hitRate = totalCount > 0 ? (hitCount / totalCount) * 100 : 0.0;

    return TicketStats(
      totalCount: totalCount,
      hitCount: hitCount,
      totalPurchase: totalPurchase,
      totalPayout: totalPayout,
      balance: balance,
      hitRate: hitRate,
    );
  }
}