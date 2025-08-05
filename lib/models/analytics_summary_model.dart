// lib/models/analytics_summary_model.dart
class AnalyticsSummary {
  final String period; // 'YYYY-MM'形式
  final int totalInvestment;
  final int totalPayout;
  final int hitCount;
  final int betCount;
  final String lastCalculated;

  AnalyticsSummary({
    required this.period,
    required this.totalInvestment,
    required this.totalPayout,
    required this.hitCount,
    required this.betCount,
    required this.lastCalculated,
  });

  Map<String, dynamic> toMap() {
    return {
      'period': period,
      'totalInvestment': totalInvestment,
      'totalPayout': totalPayout,
      'hitCount': hitCount,
      'betCount': betCount,
      'lastCalculated': lastCalculated,
    };
  }

  factory AnalyticsSummary.fromMap(Map<String, dynamic> map) {
    return AnalyticsSummary(
      period: map['period'] as String,
      totalInvestment: map['totalInvestment'] as int,
      totalPayout: map['totalPayout'] as int,
      hitCount: map['hitCount'] as int,
      betCount: map['betCount'] as int,
      lastCalculated: map['lastCalculated'] as String,
    );
  }
}

class CategorySummaryCache {
  final String cacheKey; // 例: 'grade_summary_2024'
  final String summaryJson; // CategorySummaryのリストをJSON化した文字列
  final String lastCalculated;

  CategorySummaryCache({
    required this.cacheKey,
    required this.summaryJson,
    required this.lastCalculated,
  });

  Map<String, dynamic> toMap() {
    return {
      'cacheKey': cacheKey,
      'summaryJson': summaryJson,
      'lastCalculated': lastCalculated,
    };
  }

  factory CategorySummaryCache.fromMap(Map<String, dynamic> map) {
    return CategorySummaryCache(
      cacheKey: map['cacheKey'] as String,
      summaryJson: map['summaryJson'] as String,
      lastCalculated: map['lastCalculated'] as String,
    );
  }
}