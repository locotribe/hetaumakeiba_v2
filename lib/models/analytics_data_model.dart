// lib/models/analytics_data_model.dart
import 'dart:convert';

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

  Map<String, dynamic> toMap() {
    return {
      'month': month,
      'raceName': raceName,
      'investment': investment,
      'payout': payout,
    };
  }

  factory MonthlyPurchaseDetail.fromMap(Map<String, dynamic> map) {
    return MonthlyPurchaseDetail(
      month: map['month'] as int,
      raceName: map['raceName'] as String,
      investment: map['investment'] as int,
      payout: map['payout'] as int,
    );
  }
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

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'investment': investment,
      'payout': payout,
      'hitCount': hitCount,
      'betCount': betCount,
    };
  }

  factory CategorySummary.fromMap(Map<String, dynamic> map) {
    return CategorySummary(
      name: map['name'] as String,
      investment: map['investment'] as int? ?? 0,
      payout: map['payout'] as int? ?? 0,
      hitCount: map['hitCount'] as int? ?? 0,
      betCount: map['betCount'] as int? ?? 0,
    );
  }
}

class MonthlyDataPoint {
  final int month;
  int investment;
  int payout;

  MonthlyDataPoint({required this.month, this.investment = 0, this.payout = 0});

  int get profit => payout - investment;

  Map<String, dynamic> toMap() {
    return {
      'month': month,
      'investment': investment,
      'payout': payout,
    };
  }

  factory MonthlyDataPoint.fromMap(Map<String, dynamic> map) {
    return MonthlyDataPoint(
      month: map['month'] as int,
      investment: map['investment'] as int,
      payout: map['payout'] as int,
    );
  }
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

  Map<String, dynamic> toMap() {
    return {
      'year': year,
      'monthlyData': monthlyData.map((x) => x.toMap()).toList(),
      'monthlyPurchaseDetails': monthlyPurchaseDetails.map((x) => x.toMap()).toList(),
      'totalInvestment': totalInvestment,
      'totalPayout': totalPayout,
      'totalHitCount': totalHitCount,
      'totalBetCount': totalBetCount,
    };
  }

  factory YearlySummary.fromMap(Map<String, dynamic> map) {
    final summary = YearlySummary(
      year: map['year'] as int,
    );
    summary.monthlyData.clear();
    summary.monthlyData.addAll(List<MonthlyDataPoint>.from(map['monthlyData']?.map((x) => MonthlyDataPoint.fromMap(x))));
    summary.monthlyPurchaseDetails.clear();
    summary.monthlyPurchaseDetails.addAll(List<MonthlyPurchaseDetail>.from(map['monthlyPurchaseDetails']?.map((x) => MonthlyPurchaseDetail.fromMap(x))));
    summary.totalInvestment = map['totalInvestment'] as int;
    summary.totalPayout = map['totalPayout'] as int;
    summary.totalHitCount = map['totalHitCount'] as int;
    summary.totalBetCount = map['totalBetCount'] as int;
    return summary;
  }
}

class TopPayoutInfo {
  final int payout;
  final String raceName;
  final String raceDate;

  TopPayoutInfo({
    required this.payout,
    required this.raceName,
    required this.raceDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'payout': payout,
      'raceName': raceName,
      'raceDate': raceDate,
    };
  }

  factory TopPayoutInfo.fromMap(Map<String, dynamic> map) {
    return TopPayoutInfo(
      payout: map['payout'] as int,
      raceName: map['raceName'] as String,
      raceDate: map['raceDate'] as String,
    );
  }
}

class AnalyticsData {
  final Map<int, YearlySummary> yearlySummaries;
  final List<CategorySummary> gradeSummaries;
  final List<CategorySummary> venueSummaries;
  final List<CategorySummary> distanceSummaries;
  final List<CategorySummary> trackSummaries;
  final List<CategorySummary> ticketTypeSummaries;
  final List<CategorySummary> purchaseMethodSummaries;
  final TopPayoutInfo? topPayout;
  final CategorySummary? grandTotalSummary;

  AnalyticsData({
    required this.yearlySummaries,
    required this.gradeSummaries,
    required this.venueSummaries,
    required this.distanceSummaries,
    required this.trackSummaries,
    required this.ticketTypeSummaries,
    required this.purchaseMethodSummaries,
    this.topPayout,
    this.grandTotalSummary,
  });

  factory AnalyticsData.empty() {
    return AnalyticsData(
      yearlySummaries: {},
      gradeSummaries: [],
      venueSummaries: [],
      distanceSummaries: [],
      trackSummaries: [],
      ticketTypeSummaries: [],
      purchaseMethodSummaries: [],
      topPayout: null,
      grandTotalSummary: null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'yearlySummaries': yearlySummaries.map((key, value) => MapEntry(key.toString(), value.toMap())),
      'gradeSummaries': gradeSummaries.map((x) => x.toMap()).toList(),
      'venueSummaries': venueSummaries.map((x) => x.toMap()).toList(),
      'distanceSummaries': distanceSummaries.map((x) => x.toMap()).toList(),
      'trackSummaries': trackSummaries.map((x) => x.toMap()).toList(),
      'ticketTypeSummaries': ticketTypeSummaries.map((x) => x.toMap()).toList(),
      'purchaseMethodSummaries': purchaseMethodSummaries.map((x) => x.toMap()).toList(),
      'topPayout': topPayout?.toMap(),
      'grandTotalSummary': grandTotalSummary?.toMap(),
    };
  }

  factory AnalyticsData.fromMap(Map<String, dynamic> map) {
    return AnalyticsData(
      yearlySummaries: Map<int, YearlySummary>.from(map['yearlySummaries'].map((key, value) => MapEntry(int.parse(key), YearlySummary.fromMap(value)))),
      gradeSummaries: List<CategorySummary>.from(map['gradeSummaries']?.map((x) => CategorySummary.fromMap(x))),
      venueSummaries: List<CategorySummary>.from(map['venueSummaries']?.map((x) => CategorySummary.fromMap(x))),
      distanceSummaries: List<CategorySummary>.from(map['distanceSummaries']?.map((x) => CategorySummary.fromMap(x))),
      trackSummaries: List<CategorySummary>.from(map['trackSummaries']?.map((x) => CategorySummary.fromMap(x))),
      ticketTypeSummaries: List<CategorySummary>.from(map['ticketTypeSummaries']?.map((x) => CategorySummary.fromMap(x))),
      purchaseMethodSummaries: List<CategorySummary>.from(map['purchaseMethodSummaries']?.map((x) => CategorySummary.fromMap(x))),
      topPayout: map['topPayout'] != null ? TopPayoutInfo.fromMap(map['topPayout']) : null,
      grandTotalSummary: map['grandTotalSummary'] != null ? CategorySummary.fromMap(map['grandTotalSummary']) : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory AnalyticsData.fromJson(String source) => AnalyticsData.fromMap(json.decode(source));
}