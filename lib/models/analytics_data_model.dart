// lib/models/analytics_data_model.dart

// 月ごとの詳細な購入履歴1件分のデータ
class MonthlyPurchaseDetail {
  final int month;
  final String raceName;
  final int investment;
  final int payout;

  MonthlyPurchaseDetail({
    required this.month,
    required this.raceName,
    required this.investment,
    required this.payout,
  });

  int get profit => payout - investment;
}

class CategorySummary {
  final String name;
  int investment;
  int payout;
  int hitCount;
  int betCount;

  CategorySummary({
    required this.name,
    this.investment = 0,
    this.payout = 0,
    this.hitCount = 0,
    this.betCount = 0,
  });

  int get profit => payout - investment;
  double get recoveryRate => investment == 0 ? 0.0 : (payout / investment) * 100;
  double get hitRate => betCount == 0 ? 0.0 : (hitCount / betCount) * 100;
}

class MonthlyDataPoint {
  final int month;
  int investment;
  int payout;

  MonthlyDataPoint({required this.month, this.investment = 0, this.payout = 0});

  int get profit => payout - investment;
}

class YearlySummary {
  final int year;
  final List<MonthlyDataPoint> monthlyData;
  final List<MonthlyPurchaseDetail> monthlyPurchaseDetails;
  int totalInvestment = 0;
  int totalPayout = 0;
  int totalHitCount = 0;
  int totalBetCount = 0;

  YearlySummary({required this.year})
      : monthlyData = List.generate(12, (i) => MonthlyDataPoint(month: i + 1)),
        monthlyPurchaseDetails = [];

  int get totalProfit => totalPayout - totalInvestment;
  double get totalRecoveryRate => totalInvestment == 0 ? 0.0 : (totalPayout / totalInvestment) * 100;
  double get totalHitRate => totalBetCount == 0 ? 0.0 : (totalHitCount / totalBetCount) * 100;
}

class AnalyticsData {
  final Map<int, YearlySummary> yearlySummaries;
  final List<CategorySummary> gradeSummaries;
  final List<CategorySummary> venueSummaries;
  final List<CategorySummary> distanceSummaries;
  final List<CategorySummary> trackSummaries;
  final List<CategorySummary> ticketTypeSummaries;
  final List<CategorySummary> purchaseMethodSummaries;

  AnalyticsData({
    required this.yearlySummaries,
    required this.gradeSummaries,
    required this.venueSummaries,
    required this.distanceSummaries,
    required this.trackSummaries,
    required this.ticketTypeSummaries,
    required this.purchaseMethodSummaries,
  });
}
