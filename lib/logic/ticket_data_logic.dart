// lib/logic/ticket_data_logic.dart

import 'dart:convert';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/models/qr_data_model.dart';
import 'package:hetaumakeiba_v2/models/ticket_list_item.dart';
import 'package:hetaumakeiba_v2/logic/parse.dart';
import 'package:hetaumakeiba_v2/utils/url_generator.dart';
import 'package:hetaumakeiba_v2/services/race_result_scraper_service.dart';
import 'package:hetaumakeiba_v2/logic/hit_checker.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/logic/combination_calculator.dart';
import 'package:hetaumakeiba_v2/services/shutuba_table_scraper_service.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_race_data.dart';
import 'package:hetaumakeiba_v2/models/featured_race_model.dart';

class TicketDataLogic {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // ★追加: 確定済みデータを保持するメモリキャッシュ (staticにしてインスタンス間で共有)
  static final Map<int, TicketListItem> _memoryCache = {};

  Future<List<TicketListItem>> fetchAndProcessTickets(String userId) async {
    final allQrData = await _dbHelper.getAllQrData(userId);
    final List<TicketListItem> tempItems = [];
    final shutubaScraper = ShutubaTableScraperService();

    for (final qrData in allQrData) {
      // ---------------------------------------------------------
      // キャッシュチェック (高速化ロジック)
      // ---------------------------------------------------------
      if (qrData.id != null && _memoryCache.containsKey(qrData.id)) {
        final cachedItem = _memoryCache[qrData.id]!;
        // もし「レース結果(RaceResult)」を持っている(=確定済み)なら、
        // DB問い合わせを行わずキャッシュをそのまま使う
        if (cachedItem.raceResult != null) {
          tempItems.add(cachedItem);
          continue; // 次のループへ（処理スキップ）
        }
        // 未確定(raceResult == null)の場合は、レースが終わっている可能性があるため
        // キャッシュを使わず下の処理へ進み、再チェックを行う
      }

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

        String raceDate = '';
        String raceName = '';

        // ---------------------------------------------------------
        // ステップ1: レース結果(RaceResult)をDBから探す [確定済み]
        // ---------------------------------------------------------
        final raceResult = await _dbHelper.getRaceResult(raceId);
        if (raceResult != null) {
          raceDate = raceResult.raceDate;
          raceName = raceResult.raceTitle;
        }

        // ---------------------------------------------------------
        // ステップ2: 結果がない場合、注目レース(FeaturedRace)をDBから探す [キャッシュ]
        // ---------------------------------------------------------
        if (raceDate.isEmpty) {
          final featuredRace = await _dbHelper.getFeaturedRace(raceId);
          if (featuredRace != null && featuredRace.raceDate.isNotEmpty) {
            raceDate = featuredRace.raceDate;
            raceName = featuredRace.raceName;
          }
        }

        // ---------------------------------------------------------
        // ステップ3: それでも日付がない場合、Webから出馬表を取得する [最終手段]
        // ---------------------------------------------------------
        if (raceDate.isEmpty) {
          try {
            final predictionData = await shutubaScraper.scrapeAllData(raceId);
            raceDate = predictionData.raceDate;
            raceName = predictionData.raceName;
          } catch (e) {
            print('出馬表スクレイピングエラー ($raceId): $e');
          }
        }

        // ---------------------------------------------------------
        // ステップ4: 日付フォーマットの正規化 (バグ対策)
        // ---------------------------------------------------------
        raceDate = _normalizeDate(raceDate);

        // 的中判定 (結果がある場合のみ)
        HitResult? hitResult;
        if (raceResult != null) {
          hitResult = HitChecker.check(parsedTicket: parsedTicket, raceResult: raceResult);
        }

        final newItem = TicketListItem(
          raceId: raceId,
          qrData: qrData,
          parsedTicket: parsedTicket,
          raceResult: raceResult,
          hitResult: hitResult,
          displayTitle: '', // 後で設定
          displaySubtitle: '', // 後で設定
          raceDate: raceDate,
          raceName: raceName,
        );

        tempItems.add(newItem);

        // ★追加: 処理が終わったデータをキャッシュに保存
        if (qrData.id != null) {
          _memoryCache[qrData.id!] = newItem;
        }

      } catch (e) {
        print('購入履歴のデータ処理中にエラーが発生しました: ${qrData.id} - $e');
      }
    }

    // 重複カウントと表示タイトルの生成処理
    final Map<String, int> duplicateCounter = {};
    for (final item in tempItems) {
      final key = _generatePurchaseKey(item.parsedTicket);
      duplicateCounter[key] = (duplicateCounter[key] ?? 0) + 1;
    }

    final Map<String, int> currentDuplicateIndex = {};
    final List<TicketListItem> finalItems = [];

    for (final item in tempItems) {
      String title;
      if (item.raceName.isNotEmpty) {
        title = item.raceName;
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

      final completeItem = TicketListItem(
        raceId: item.raceId,
        qrData: item.qrData,
        parsedTicket: item.parsedTicket,
        raceResult: item.raceResult,
        hitResult: item.hitResult,
        displayTitle: title,
        displaySubtitle: combinedSubtitle,
        raceDate: item.raceDate,
        raceName: item.raceName,
      );

      finalItems.add(completeItem);

      // ★追加: タイトル等の詳細情報が付与された完全な状態でもう一度キャッシュ更新
      if (item.qrData.id != null) {
        _memoryCache[item.qrData.id!] = completeItem;
      }
    }

    finalItems.sort((a, b) {
      if (a.raceDate.isEmpty && b.raceDate.isEmpty) return 0;
      if (a.raceDate.isEmpty) return 1;
      if (b.raceDate.isEmpty) return -1;
      return b.raceDate.compareTo(a.raceDate);
    });

    return finalItems;
  }

  /// 日付文字列を「yyyy年MM月dd日」形式に統一するヘルパーメソッド
  String _normalizeDate(String date) {
    if (date.isEmpty) return '';

    // すでに日本語形式が含まれている場合はそのまま返す
    if (date.contains('年') && date.contains('月') && date.contains('日')) {
      return date;
    }

    // "yyyy/MM/dd" や "yyyy-MM-dd" 形式への対応
    try {
      final parts = date.split(RegExp(r'[-/]'));
      if (parts.length == 3) {
        return '${parts[0]}年${parts[1]}月${parts[2]}日';
      }
    } catch (e) {
      // 解析できない場合は元の文字列を返す
    }
    return date;
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