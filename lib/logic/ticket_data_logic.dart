// lib/logic/ticket_data_logic.dart

import 'dart:convert';
import 'package:hetaumakeiba_v2/db/repositories/ticket_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/race_repository.dart';
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
import 'package:hetaumakeiba_v2/models/shutuba_table_cache_model.dart';

class TicketDataLogic {
  final TicketRepository _ticketRepository = TicketRepository();
  final RaceRepository _raceRepository = RaceRepository();

  // ★追加: 確定済みデータを保持するメモリキャッシュ (staticにしてインスタンス間で共有)
  static final Map<int, TicketListItem> _memoryCache = {};

  Future<List<TicketListItem>> fetchAndProcessTickets(String userId) async {
    final allQrData = await _ticketRepository.getAllQrData(userId);
    final List<TicketListItem> tempItems = [];
    final shutubaScraper = ShutubaTableScraperService(); // インスタンスは維持しますが、このループ内では通信しません

    // ---------------------------------------------------------
    // Step 0: N+1問題対策 & 高速化のための事前準備
    // 全QRデータからRaceIDを抽出し、DBにあるデータを一括取得する
    // ---------------------------------------------------------
    final Set<String> raceIdsToFetch = {};
    final Map<int, Map<String, dynamic>> parsedTicketCache = {}; // JSONパース結果の一時保持
    final Map<int, String> raceIdCache = {}; // RaceIDの一時保持

    for (final qrData in allQrData) {
      // メモリキャッシュにあり、かつ確定済み(RaceResultあり)の場合はスキップ
      if (qrData.id != null && _memoryCache.containsKey(qrData.id)) {
        final cachedItem = _memoryCache[qrData.id]!;
        if (cachedItem.raceResult != null) continue;
      }

      try {
        final parsedTicket = jsonDecode(qrData.parsedDataJson) as Map<String, dynamic>;
        if (parsedTicket.isEmpty) continue;
        if (qrData.id == null) continue;

        parsedTicketCache[qrData.id!] = parsedTicket;

        final url = generateNetkeibaUrl(
          year: parsedTicket['年'].toString(),
          racecourseCode: racecourseDict.entries.firstWhere((e) => e.value == parsedTicket['開催場']).key,
          round: parsedTicket['回'].toString(),
          day: parsedTicket['日'].toString(),
          race: parsedTicket['レース'].toString(),
        );
        final raceId = RaceResultScraperService.getRaceIdFromUrl(url)!;

        raceIdCache[qrData.id!] = raceId;
        raceIdsToFetch.add(raceId);
      } catch (e) {
        // パースエラー等は無視
      }
    }

    // 1. レース結果(RaceResult)の一括取得 [確定済みデータ]
    final Map<String, RaceResult> batchRaceResults = await _raceRepository.getMultipleRaceResults(raceIdsToFetch.toList());

    // 2. 注目レース(FeaturedRace)の一括取得 [未確定・出馬表データ] (★ここを復元・追加)
    // ※FeaturedRaceには一括取得メソッドがないため、全件取得してメモリでフィルタリング（件数が数千件程度なら高速）
    final List<FeaturedRace> allFeaturedRaces = await _raceRepository.getAllFeaturedRaces();
    final Map<String, FeaturedRace> batchFeaturedRaces = {
      for (var race in allFeaturedRaces) race.raceId: race
    };

    // ---------------------------------------------------------
    // Step 1: メインループ (オブジェクト生成)
    // ---------------------------------------------------------
    for (final qrData in allQrData) {
      // キャッシュチェック
      if (qrData.id != null && _memoryCache.containsKey(qrData.id)) {
        final cachedItem = _memoryCache[qrData.id]!;
        if (cachedItem.raceResult != null) {
          tempItems.add(cachedItem);
          continue;
        }
      }

      try {
        // 事前パースデータの利用
        final parsedTicket = (qrData.id != null && parsedTicketCache.containsKey(qrData.id))
            ? parsedTicketCache[qrData.id!]!
            : (jsonDecode(qrData.parsedDataJson) as Map<String, dynamic>);

        if (parsedTicket.isEmpty) continue;

        String raceId;
        if (qrData.id != null && raceIdCache.containsKey(qrData.id)) {
          raceId = raceIdCache[qrData.id]!;
        } else {
          final url = generateNetkeibaUrl(
            year: parsedTicket['年'].toString(),
            racecourseCode: racecourseDict.entries.firstWhere((e) => e.value == parsedTicket['開催場']).key,
            round: parsedTicket['回'].toString(),
            day: parsedTicket['日'].toString(),
            race: parsedTicket['レース'].toString(),
          );
          raceId = RaceResultScraperService.getRaceIdFromUrl(url)!;
        }

        String raceDate = '';
        String raceName = '';

        // ---------------------------------------------------------
        // ステップ1: レース結果(RaceResult)をDBから探す [確定済み]
        // ---------------------------------------------------------
        final raceResult = batchRaceResults[raceId];
        if (raceResult != null) {
          raceDate = raceResult.raceDate;
          raceName = raceResult.raceTitle;
        }

        // ---------------------------------------------------------
        // ステップ2: 結果がない場合、注目レース(FeaturedRace)をDBから探す [未確定・キャッシュ] (★復元)
        // ---------------------------------------------------------
        if (raceDate.isEmpty) {
          final featuredRace = batchFeaturedRaces[raceId];
          if (featuredRace != null && featuredRace.raceDate.isNotEmpty) {
            raceDate = featuredRace.raceDate;
            raceName = featuredRace.raceName;
          }
        }
        // ---------------------------------------------------------
        // ステップ3: 情報がない場合、出馬表キャッシュ(ShutubaTableCache)をDBから探す
        // ---------------------------------------------------------
        if (raceDate.isEmpty) {
          final shutubaCache = await _raceRepository.getShutubaTableCache(raceId);
          if (shutubaCache != null) {
            // すでにパース済みのデータ(predictionRaceData)から直接取得します
            final data = shutubaCache.predictionRaceData;
            if (data.raceDate.isNotEmpty) raceDate = data.raceDate;
            if (data.raceName.isNotEmpty) raceName = data.raceName;
          }
        }

        // ---------------------------------------------------------
        // ステップ4: それでも情報がない場合、開催スケジュール(RaceSchedule)をDBから探す
        // ---------------------------------------------------------
        if (raceDate.isEmpty) {
          final scheduleDate = await _raceRepository.getDateFromScheduleByRaceId(raceId);
          if (scheduleDate != null) {
            raceDate = scheduleDate;
            // スケジュールからは日付のみ取得（タイトルは後続処理で「開催場+R」として生成されるため問題なし）
          }
        }

        // ---------------------------------------------------------
        // ステップ5: 【最終手段】Webスクレイピング (未知の馬券のみ)
        // ---------------------------------------------------------
        // DBのどこにも情報がなく、完全に新規のレースの場合のみWebへ取りに行きます。
        if (raceDate.isEmpty && raceId.length == 12) {
          try {
            // 既存のURLジェネレーターを使用してURLを生成
            // raceId (12桁): YYYY(4) PP(2) KK(2) DD(2) RR(2)
            // generateNetkeibaUrlは年を2桁で受け取り "20" を付与するため、raceIdからは下2桁を渡す
            final year = raceId.substring(2, 4);
            final place = raceId.substring(4, 6);
            final kai = raceId.substring(6, 8);
            final day = raceId.substring(8, 10);
            final r = raceId.substring(10, 12);

            final dbUrl = generateNetkeibaUrl(
              year: year,
              racecourseCode: place,
              round: kai,
              day: day,
              race: r,
            );

            // Webからレース詳細を取得
            final fetched = await RaceResultScraperService.scrapeRaceDetails(dbUrl);

            if (fetched.raceDate.isNotEmpty) {
              raceDate = fetched.raceDate;
              raceName = fetched.raceTitle;

            }
          } catch (e) {
            print('新規レース情報のWeb取得に失敗: $raceId - $e');
            // 失敗時は処理を止めず、表示可能な情報だけでリストを生成します
          }
        }

        // 日付フォーマットの正規化
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

        // キャッシュ保存
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