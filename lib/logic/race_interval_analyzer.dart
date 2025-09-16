// lib/logic/race_interval_analyzer.dart

import 'package:intl/intl.dart';

class RaceIntervalAnalyzer {
  static DateTime? _parseDate(String dateStr) {
    try {
      if (dateStr.contains('/')) {
        return DateFormat('yyyy/M/d').parse(dateStr);
      } else if (dateStr.contains('.')) {
        return DateFormat('yyyy.M.d').parse(dateStr);
      } else if (dateStr.contains('年')) {
        return DateFormat('yyyy年M月d日').parse(dateStr);
      }
    } catch (e) {
      print('日付の解析に失敗しました: $dateStr, エラー: $e');
    }
    return null;
  }

  // 距離文字列 (例: "芝1600m") から数値 (例: 1600) を抽出
  static int? _parseDistance(String distanceStr) {
    final match = RegExp(r'(\d+)m?').firstMatch(distanceStr);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  // "m"を目印に距離を抽出する新しいヘルパー関数
  static int? _parseDistanceWithUnit(String distanceStr) {
    final match = RegExp(r'(\d+)m').firstMatch(distanceStr);
    return match != null ? int.tryParse(match.group(1)!) : null;
  }

  // レース間隔をフォーマットする
  static String formatRaceInterval(String currentDateStr, String previousDateStr) {
    final currentDate = _parseDate(currentDateStr);
    final previousDate = _parseDate(previousDateStr);

    if (currentDate == null || previousDate == null) {
      return '--';
    }

    final differenceInDays = currentDate.difference(previousDate).inDays;

    if (differenceInDays <= 8) return '連闘';

    // 週数を計算 (日曜基準)
    final prevSunday = previousDate.add(Duration(days: 7 - previousDate.weekday));
    final currentSunday = currentDate.add(Duration(days: 7 - currentDate.weekday));
    final weeks = currentSunday.difference(prevSunday).inDays ~/ 7;

    if (weeks <= 4) {
      return '中${weeks - 1}週';
    }

    // 月数を計算
    int months = (currentDate.year - previousDate.year) * 12 + currentDate.month - previousDate.month;
    if (currentDate.day < previousDate.day) {
      months--;
    }

    if (months > 0) {
      return '$monthsヶ月';
    }

    // 1ヶ月未満だが5週以上の場合
    if (weeks > 4) {
      return '中${weeks - 1}週';
    }

    return '--';
  }

  // 距離変化をフォーマットする
  static String formatDistanceChange(String currentDistanceStr, String previousDistanceStr) {
    final bool isCurrentRaceDetail = currentDistanceStr.contains('/');

    final currentDistance = isCurrentRaceDetail
        ? _parseDistanceWithUnit(currentDistanceStr)
        : _parseDistance(currentDistanceStr);

    final previousDistance = _parseDistance(previousDistanceStr);

    if (currentDistance == null || previousDistance == null) {
      return '--';
    }

    if (currentDistance > previousDistance) return '延長';
    if (currentDistance < previousDistance) return '短縮';
    return '同';
  }
}