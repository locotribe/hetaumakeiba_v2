// lib/logic/ticket_aggregator.dart

import 'package:hetaumakeiba_v2/logic/combination_calculator.dart';
import 'package:hetaumakeiba_v2/models/ticket_list_item.dart';

class BettingTypeStats {
  final int purchaseCount;
  final int purchaseAmount;
  final int payoutAmount;
  final int hitCount;

  const BettingTypeStats({
    required this.purchaseCount,
    required this.purchaseAmount,
    this.payoutAmount = 0,
    this.hitCount = 0,
  });
}

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

  /// parsedTicket['購入内容']の式別・購入金額から券種別集計を計算する
  /// 応援馬券（parsedTicket['方式'] == '応援馬券'）は単勝・複勝を分離せず1件としてまとめる
  static Map<String, BettingTypeStats> calculateTypeStats(List<TicketListItem> items) {
    final Map<String, int> countMap = {};
    final Map<String, int> amountMap = {};
    final Map<String, int> payoutMap = {};
    final Map<String, int> hitCountMap = {};

    for (final item in items) {
      final isOen = item.parsedTicket['方式'] == '応援馬券';
      final purchases = item.parsedTicket['購入内容'] as List<dynamic>?;
      if (purchases == null) continue;

      if (isOen) {
        int totalAmount = 0;
        for (final p in purchases) {
          totalAmount += ((p as Map<String, dynamic>)['購入金額'] as int?) ?? 0;
        }
        countMap['応援馬券'] = (countMap['応援馬券'] ?? 0) + 1;
        amountMap['応援馬券'] = (amountMap['応援馬券'] ?? 0) + totalAmount;
        final oenPayout = item.hitResult?.payoutByType ?? {};
        for (final entry in oenPayout.entries) {
          payoutMap['応援馬券'] = (payoutMap['応援馬券'] ?? 0) + entry.value;
        }
        final oenHit = item.hitResult?.hitCountByType ?? {};
        for (final entry in oenHit.entries) {
          hitCountMap['応援馬券'] = (hitCountMap['応援馬券'] ?? 0) + entry.value;
        }
      } else {
        for (final p in purchases) {
          final typeId = (p as Map<String, dynamic>)['式別'] as String?;
          if (typeId == null) continue;
          final typeName = bettingDict[typeId] ?? typeId;
          final combCount = (p['組合せ数'] as int?) ?? 1;
          final amount = ((p['購入金額'] as int?) ?? 0) * combCount;

          countMap[typeName] = (countMap[typeName] ?? 0) + 1;
          amountMap[typeName] = (amountMap[typeName] ?? 0) + amount;
        }

        final payoutByType = item.hitResult?.payoutByType ?? {};
        for (final entry in payoutByType.entries) {
          payoutMap[entry.key] = (payoutMap[entry.key] ?? 0) + entry.value;
        }
        final hitCountByType = item.hitResult?.hitCountByType ?? {};
        for (final entry in hitCountByType.entries) {
          hitCountMap[entry.key] = (hitCountMap[entry.key] ?? 0) + entry.value;
        }
      }
    }

    return {
      for (final typeName in countMap.keys)
        typeName: BettingTypeStats(
          purchaseCount: countMap[typeName]!,
          purchaseAmount: amountMap[typeName]!,
          payoutAmount: payoutMap[typeName] ?? 0,
          hitCount: hitCountMap[typeName] ?? 0,
        ),
    };
  }
}