// lib/logic/ticket_data_logic.dart

import 'dart:convert';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/models/ticket_list_item.dart';
import 'package:hetaumakeiba_v2/logic/parse.dart';
import 'package:hetaumakeiba_v2/utils/url_generator.dart';
import 'package:hetaumakeiba_v2/services/race_result_scraper_service.dart';
import 'package:hetaumakeiba_v2/logic/hit_checker.dart';
import 'package:hetaumakeiba_v2/logic/combination_calculator.dart';

class TicketDataLogic {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<TicketListItem>> fetchAndProcessTickets(String userId) async {
    final allQrData = await _dbHelper.getAllQrData(userId);
    final List<TicketListItem> tempItems = [];

    for (final qrData in allQrData) {
      try {
        final parsedTicket = jsonDecode(qrData.parsedDataJson) as Map<String, dynamic>;
        if (parsedTicket.isEmpty) continue;

        final url = generateNetkeibaUrl(
          year: parsedTicket['年'].toString(),
          racecourseCode: racecourseDict.entries.firstWhere((e) => e.value == parsedTicket['開催場']).key,
          round: parsedTicket['回'].toString(),
          day: parsedTicket['日'].toString(),
          race: parsedTicket['レース'].toString(),
        );
        final raceId = RaceResultScraperService.getRaceIdFromUrl(url)!;
        final raceResult = await _dbHelper.getRaceResult(raceId);

        HitResult? hitResult;
        if (raceResult != null) {
          hitResult = HitChecker.check(parsedTicket: parsedTicket, raceResult: raceResult);
        }

        tempItems.add(TicketListItem(
          raceId: raceId,
          qrData: qrData,
          parsedTicket: parsedTicket,
          raceResult: raceResult,
          hitResult: hitResult,
          displayTitle: '',
          displaySubtitle: '',
        ));
      } catch (e) {
        print('購入履歴のデータ処理中にエラーが発生しました: ${qrData.id} - $e');
      }
    }

    final Map<String, int> duplicateCounter = {};
    for (final item in tempItems) {
      final key = _generatePurchaseKey(item.parsedTicket);
      duplicateCounter[key] = (duplicateCounter[key] ?? 0) + 1;
    }

    final Map<String, int> currentDuplicateIndex = {};
    final List<TicketListItem> finalItems = [];

    for (final item in tempItems) {
      String title;
      if (item.raceResult != null) {
        title = item.raceResult!.raceTitle;
      } else {
        final venue = item.parsedTicket['開催場'] ?? '不明';
        final raceNum = item.parsedTicket['レース'] ?? '??';
        title = '$venue ${raceNum}R';
      }

      String purchaseMethodDisplay = item.parsedTicket['方式'] ?? '';
      if (purchaseMethodDisplay == 'ながし') {
        final purchaseContents = item.parsedTicket['購入内容'] as List<dynamic>?;
        if (purchaseContents != null && purchaseContents.isNotEmpty) {
          final firstPurchase = purchaseContents.first as Map<String, dynamic>;
          purchaseMethodDisplay = firstPurchase['ながし種別'] as String? ?? purchaseMethodDisplay;
          if (firstPurchase.containsKey('マルチ') && firstPurchase['マルチ'] == 'あり') {
            purchaseMethodDisplay += 'マルチ';
          }
        }
      }

      final purchaseDetails = (item.parsedTicket['購入内容'] as List)
          .map((p) => bettingDict[p['式別']] ?? '')
          .where((name) => name.isNotEmpty)
          .toSet()
          .join(', ');

      String line2 = '$purchaseDetails $purchaseMethodDisplay';
      final key = _generatePurchaseKey(item.parsedTicket);
      if (duplicateCounter[key]! > 1) {
        final index = (currentDuplicateIndex[key] ?? 0) + 1;
        line2 += ' ($index)';
        currentDuplicateIndex[key] = index;
      }

      final line3 = _formatPurchaseSummary(item.parsedTicket['購入内容'] as List<dynamic>);
      final combinedSubtitle = '$line2\n$line3';

      finalItems.add(TicketListItem(
        raceId: item.raceId,
        qrData: item.qrData,
        parsedTicket: item.parsedTicket,
        raceResult: item.raceResult,
        hitResult: item.hitResult,
        displayTitle: title,
        displaySubtitle: combinedSubtitle,
      ));
    }

    finalItems.sort((a, b) {
      final dateA = a.raceResult?.raceDate;
      final dateB = b.raceResult?.raceDate;
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateB.compareTo(dateA);
    });

    return finalItems;
  }

  String _generatePurchaseKey(Map<String, dynamic> parsedTicket) {
    try {
      final url = generateNetkeibaUrl(
        year: parsedTicket['年'].toString(),
        racecourseCode: racecourseDict.entries.firstWhere((e) => e.value == parsedTicket['開催場']).key,
        round: parsedTicket['回'].toString(),
        day: parsedTicket['日'].toString(),
        race: parsedTicket['レース'].toString(),
      );
      final raceId = RaceResultScraperService.getRaceIdFromUrl(url)!;
      final purchaseMethod = parsedTicket['方式'] ?? '';
      final purchaseDetails = (parsedTicket['購入内容'] as List);
      final detailsString = purchaseDetails.map((p) {
        final detailMap = p as Map<String, dynamic>;
        final sortedKeys = detailMap.keys.toList()..sort();
        return sortedKeys.map((key) => '$key:${detailMap[key]}').join(';');
      }).join('|');
      return '$raceId-$purchaseMethod-$detailsString';
    } catch (e) {
      return parsedTicket['QR'] ?? parsedTicket.toString();
    }
  }

  String _formatPurchaseSummary(List<dynamic> purchases) {
    if (purchases.isEmpty) return '';
    try {
      final firstPurchase = purchases.first as Map<String, dynamic>;
      final ticketTypeId = firstPurchase['式別'] as String?;
      final ticketType = bettingDict[ticketTypeId] ?? '';
      final amount = firstPurchase['購入金額'] ?? 0;
      String horseNumbersStr = '';
      if (firstPurchase.containsKey('all_combinations')) {
        final combinations = firstPurchase['all_combinations'] as List;
        if (combinations.isNotEmpty) {
          final separator = (ticketType == '馬単' || ticketType == '3連単') ? '→' : '-';
          horseNumbersStr = (combinations.first as List).join(separator);
        }
      }
      String summary = '$horseNumbersStr / $amount円';
      if (purchases.length > 1 || (firstPurchase.containsKey('all_combinations') && (firstPurchase['all_combinations'] as List).length > 1)) {
        summary += ' ...他';
      }
      return summary;
    } catch (e) {
      print('Error in _formatPurchaseSummary: $e');
      return '購入内容の表示に失敗しました';
    }
  }
}