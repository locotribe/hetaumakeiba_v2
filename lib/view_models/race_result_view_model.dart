// lib/view_models/race_result_view_model.dart

import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:hetaumakeiba_v2/db/repositories/horse_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/race_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/ticket_repository.dart';
import 'package:hetaumakeiba_v2/logic/analysis/race_analyzer.dart';
import 'package:hetaumakeiba_v2/logic/hit_checker.dart';
import 'package:hetaumakeiba_v2/logic/memo_import_logic.dart';
import 'package:hetaumakeiba_v2/models/analysis_model.dart';
import 'package:hetaumakeiba_v2/models/horse_memo_model.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/qr_data_model.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/models/race_memo_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/services/race_result_scraper_service.dart';
import 'package:hetaumakeiba_v2/services/statistics_service.dart';
import 'package:hetaumakeiba_v2/services/user_session.dart';
import 'package:hetaumakeiba_v2/utils/url_generator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

// [追加] race_result_page.dartからViewModelへ移行 (v.13.41.0)
/// 画面表示に必要な各種データ（馬券・レース結果・展開予測）をまとめて保持するクラス
class PageData {
  final List<Map<String, dynamic>> parsedTickets;
  final RaceResult? raceResult;
  final RacePacePrediction? pacePrediction;

  PageData({
    required this.parsedTickets,
    this.raceResult,
    this.pacePrediction,
  });
}

// [追加] レース全体の収支サマリーを保持するクラス (v.13.41.0)
class RaceBalanceSummary {
  final int totalPurchase;
  final int totalPayout;
  final int totalRefund;

  const RaceBalanceSummary({
    required this.totalPurchase,
    required this.totalPayout,
    required this.totalRefund,
  });

  int get balance => (totalPayout + totalRefund) - totalPurchase;
}

// [追加] データ更新（プルリフレッシュ）の結果を保持するクラス (v.13.41.0)
class RefreshResult {
  final bool success;
  final String message;

  const RefreshResult({required this.success, required this.message});
}

// [追加] CSVメモインポートの結果を保持するクラス (v.13.41.0)
class ImportCsvResult {
  final bool success;
  final String message;

  const ImportCsvResult({required this.success, required this.message});
}

// [追加] CSVインポート時のメモ競合をUI側のダイアログで解決させるためのコールバック型 (v.13.41.0)
typedef ConflictResolver = Future<String?> Function(
    String title, MemoMergeResult conflict);

/// レース結果画面のUIロジックとビジネスロジックを分離するためのViewModel
class RaceResultViewModel extends ChangeNotifier {
  final String raceId;

  final RaceRepository _raceRepo = RaceRepository();
  final TicketRepository _ticketRepo = TicketRepository();
  final HorseRepository _horseRepo = HorseRepository();

  RaceResultViewModel({required this.raceId});

  bool isLoading = true;
  String? errorMessage;
  PageData? pageData;
  List<QrData> qrDataList = [];
  int currentTicketIndex = 0;

  // 初期化（遷移元から渡された馬券リストとインデックスを受け取り、データ読み込みを開始する）
  Future<void> initialize(List<QrData> initialQrDataList, int initialIndex) async {
    qrDataList = initialQrDataList;
    currentTicketIndex = initialIndex;
    await loadPageData();
  }

  // 表示中の馬券インデックスを更新する
  void setCurrentTicketIndex(int index) {
    if (currentTicketIndex == index) return;
    currentTicketIndex = index;
    notifyListeners();
  }

  // ページの表示に必要なデータ（馬券・レース結果・展開予測）を読み込む
  Future<void> loadPageData() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      if (qrDataList.isEmpty) {
        // Step3で追加した高速検索メソッドを使用
        final savedTickets = await _ticketRepo.getQrDataByRaceId(raceId);
        if (savedTickets.isNotEmpty) {
          qrDataList = savedTickets;
        }
      }
      // 全チケットをパース
      List<Map<String, dynamic>> parsedTickets = [];
      for (var qr in qrDataList) {
        try {
          final parsed = json.decode(qr.parsedDataJson) as Map<String, dynamic>;
          parsedTickets.add(parsed);
        } catch (e) {
          debugPrint('Error parsing ticket: $e');
        }
      }

      RaceResult? raceResult = await _raceRepo.getRaceResult(raceId);

      final userId = UserSession().localUserId;
      if (raceResult != null && userId != null) {
        final memos = await _horseRepo.getMemosForRace(userId, raceId);
        final memosMap = {for (var memo in memos) memo.horseId: memo};
        final List<PredictionHorseDetail> horseDetailsForPacePrediction = [];
        final Map<String, List<HorseRaceRecord>> allPastRecords = {};

        for (var horseResult in raceResult.horseResults) {
          if (memosMap.containsKey(horseResult.horseId)) {
            horseResult.userMemo = memosMap[horseResult.horseId];
          }
          final pastRecords = await _horseRepo.getHorsePerformanceRecords(horseResult.horseId);
          allPastRecords[horseResult.horseId] = pastRecords;
          final trainerText = horseResult.trainerName;
          String trainerAffiliation = '';
          String trainerName = trainerText;

          if (trainerText.startsWith('美') || trainerText.startsWith('栗')) {
            final parts = trainerText.split(' ');
            if (parts.length > 1) {
              trainerAffiliation = parts[0];
              trainerName = parts.sublist(1).join(' ');
            }
          }
          // 展開予測のためにPredictionHorseDetailのリストを作成
          horseDetailsForPacePrediction.add(
              PredictionHorseDetail(
                horseId: horseResult.horseId,
                horseNumber: int.tryParse(horseResult.horseNumber) ?? 0,
                gateNumber: int.tryParse(horseResult.frameNumber) ?? 0,
                horseName: horseResult.horseName,
                sexAndAge: horseResult.sexAndAge,
                jockey: horseResult.jockeyName,
                jockeyId: horseResult.jockeyId,
                carriedWeight: double.tryParse(horseResult.weightCarried) ?? 0.0,
                trainerName: trainerName,
                trainerAffiliation: trainerAffiliation,
                isScratched: false,
              )
          );
        }

        // 過去レースの結果を取得する
        final statisticsService = StatisticsService();
        final pastRaceResults = await statisticsService.fetchPastRacesForAnalysis(
            raceResult.raceTitle, raceId);

        final pacePrediction = RaceAnalyzer.predictRacePace(
            horseDetailsForPacePrediction, allPastRecords, pastRaceResults);

        pageData = PageData(
          parsedTickets: parsedTickets,
          raceResult: raceResult,
          pacePrediction: pacePrediction,
        );
      } else {
        pageData = PageData(
          parsedTickets: parsedTickets,
          raceResult: raceResult,
        );
      }
    } catch (e) {
      debugPrint('ページデータの読み込みに失敗しました: $e');
      errorMessage = 'データの表示に失敗しました。';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // プルリフレッシュ：レース結果の再スクレイピングと馬券リストの再取得を行う
  Future<RefreshResult> refreshData() async {
    bool success = true;
    String message;

    try {
      final userId = UserSession().localUserId;
      if (userId == null) {
        return const RefreshResult(success: false, message: 'ユーザー情報の取得に失敗しました。');
      }

      debugPrint('DEBUG: Refreshing race data for raceId: $raceId');

      // 1. レース結果のスクレイピング更新
      await RaceResultScraperService.scrapeRaceDetails(generateRaceResultUrl(raceId));

      final siblings = await _ticketRepo.getQrDataByRaceId(raceId);

      if (siblings.isNotEmpty) {
        // 既存のリストにあるものは除外して追加（ID重複防止）
        final existingIds = qrDataList.map((e) => e.id).toSet();
        for (var sib in siblings) {
          if (!existingIds.contains(sib.id)) {
            qrDataList.add(sib);
          }
        }
        // ID順にソート（保存順）
        qrDataList.sort((a, b) => (a.id ?? 0).compareTo(b.id ?? 0));
      }

      message = 'レース結果と馬券リストを更新しました。';
    } catch (e) {
      debugPrint('ERROR: Failed to refresh race data: $e');
      success = false;
      message = '更新に失敗しました: $e';
    }

    await loadPageData();
    return RefreshResult(success: success, message: message);
  }

  // レース総評・各馬の回顧/予想メモをCSVへ書き出して共有する
  Future<void> exportReviewsAsCsv() async {
    final raceResult = pageData?.raceResult;
    if (raceResult == null) return;

    final userId = UserSession().localUserId;
    if (userId == null) return;

    // レース総評を取得
    final raceMemo = await _raceRepo.getRaceMemo(userId, raceId);
    final raceMemoText = raceMemo?.memo ?? '';

    final List<List<dynamic>> rows = [];
    // ヘッダーに raceMemo を追加
    rows.add(['raceId', 'horseId', 'horseNumber', 'horseName', 'reviewMemo', 'predictionMemo', 'raceMemo']);

    for (int i = 0; i < raceResult.horseResults.length; i++) {
      final horse = raceResult.horseResults[i];
      rows.add([
        raceId,
        horse.horseId,
        horse.horseNumber,
        horse.horseName,
        horse.userMemo?.reviewMemo ?? '',
        horse.userMemo?.predictionMemo ?? '',
        // レース総評は長文になるため、最初のデータ行（i == 0）にのみ出力してスッキリさせる
        i == 0 ? raceMemoText : '',
      ]);
    }

    final String csv = const ListToCsvConverter().convert(rows);
    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/${raceId}_reviews.csv';
    final file = File(path);
    await file.writeAsString(csv);

    await Share.shareXFiles([XFile(path)], text: '${raceResult.raceTitle} の回顧メモ');
  }

  // CSVから回顧/予想メモ・レース総評を読み込み、競合があればresolveConflict経由でUIに解決させる
  Future<ImportCsvResult> importReviewsFromCsv(ConflictResolver resolveConflict) async {
    final userId = UserSession().localUserId;
    if (userId == null) {
      return const ImportCsvResult(success: false, message: 'ログインが必要です。');
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null || result.files.single.path == null) {
        return const ImportCsvResult(success: false, message: '');
      }

      final filePath = result.files.single.path!;
      final file = File(filePath);
      final csvString = await file.readAsString();
      final List<List<dynamic>> rows = const CsvToListConverter().convert(csvString);

      if (rows.length < 2) throw Exception('データがありません');

      final header = rows.first.map((e) => e.toString().trim()).toList();
      // 旧フォーマットのCSVでも読み込めるように後方互換性を持たせる
      final hasRaceMemoCol = header.length > 6 && header[6] == 'raceMemo';

      if (header[0] != 'raceId' || header[1] != 'horseId') {
        throw Exception('CSVヘッダーが正しくありません');
      }

      // === 既存データの取得 ===
      final existingHorseMemos = await _horseRepo.getMemosForRace(userId, raceId);
      final existingHorseMemosMap = {for (var m in existingHorseMemos) m.horseId: m};
      final existingRaceMemo = await _raceRepo.getRaceMemo(userId, raceId);

      final List<HorseMemo> memosToUpdate = [];
      bool updateRaceMemo = false;
      String finalRaceMemo = existingRaceMemo?.memo ?? '';
      int updatedHorseCount = 0;

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        final csvRaceId = row[0].toString();

        if (csvRaceId != raceId) continue;

        final horseId = row[1].toString();
        final horseName = row.length > 3 ? row[3].toString() : '馬番不明';
        final csvReview = row.length > 4 ? row[4].toString() : '';
        final csvPrediction = row.length > 5 ? row[5].toString() : '';

        final existingHorse = existingHorseMemosMap[horseId];
        String finalReview = existingHorse?.reviewMemo ?? '';
        String finalPrediction = existingHorse?.predictionMemo ?? '';
        bool isHorseUpdated = false;

        // 回顧メモの競合判定
        final reviewMerge = MemoImportLogic.determineMergeAction(existingHorse?.reviewMemo, csvReview);
        if (reviewMerge.action == MemoMergeAction.overwrite) {
          finalReview = reviewMerge.resultText;
          isHorseUpdated = true;
        } else if (reviewMerge.action == MemoMergeAction.conflict) {
          final resolved = await resolveConflict('$horseNameの回顧メモ', reviewMerge);
          if (resolved != null && resolved != finalReview) {
            finalReview = resolved;
            isHorseUpdated = true;
          }
        }

        // 予想メモの競合判定
        final predictionMerge = MemoImportLogic.determineMergeAction(existingHorse?.predictionMemo, csvPrediction);
        if (predictionMerge.action == MemoMergeAction.overwrite) {
          finalPrediction = predictionMerge.resultText;
          isHorseUpdated = true;
        } else if (predictionMerge.action == MemoMergeAction.conflict) {
          final resolved = await resolveConflict('$horseNameの予想メモ', predictionMerge);
          if (resolved != null && resolved != finalPrediction) {
            finalPrediction = resolved;
            isHorseUpdated = true;
          }
        }

        // 変更があった場合、または新規作成の場合のみ更新リストへ追加
        if (isHorseUpdated || existingHorse == null) {
          // 新規の場合でかつCSVのメモがどちらも空なら追加しない
          if (existingHorse != null || finalReview.isNotEmpty || finalPrediction.isNotEmpty) {
            memosToUpdate.add(HorseMemo(
              id: existingHorse?.id,
              userId: userId,
              raceId: csvRaceId,
              horseId: horseId,
              reviewMemo: finalReview,
              predictionMemo: finalPrediction,
              timestamp: DateTime.now(),
              odds: existingHorse?.odds,
              popularity: existingHorse?.popularity,
            ));
            updatedHorseCount++;
          }
        }

        // レース総評の競合判定
        if (hasRaceMemoCol && row.length > 6) {
          final csvRaceMemo = row[6].toString().trim();
          if (csvRaceMemo.isNotEmpty) {
            final raceMerge = MemoImportLogic.determineMergeAction(finalRaceMemo, csvRaceMemo);
            if (raceMerge.action == MemoMergeAction.overwrite) {
              finalRaceMemo = raceMerge.resultText;
              updateRaceMemo = true;
            } else if (raceMerge.action == MemoMergeAction.conflict) {
              final resolved = await resolveConflict('レース総評', raceMerge);
              if (resolved != null && resolved != finalRaceMemo) {
                finalRaceMemo = resolved;
                updateRaceMemo = true;
              }
            }
          }
        }
      }

      // 馬ごとのメモを一括保存
      if (memosToUpdate.isNotEmpty) {
        await _horseRepo.insertOrUpdateMultipleMemos(memosToUpdate);
      }

      // レース総評の保存
      if (updateRaceMemo) {
        final newRaceMemo = RaceMemo(
          id: existingRaceMemo?.id,
          userId: userId,
          raceId: raceId,
          memo: finalRaceMemo,
          timestamp: DateTime.now(),
        );
        await _raceRepo.insertOrUpdateRaceMemo(newRaceMemo);
      }

      // 画面を再読み込みして最新データを反映（RaceReviewCardも更新される）
      if (memosToUpdate.isNotEmpty || updateRaceMemo) {
        await loadPageData();
      }

      final message = '$updatedHorseCount頭のメモ${updateRaceMemo ? 'とレース総評' : ''}を更新・インポートしました';
      return ImportCsvResult(success: true, message: message);
    } catch (e) {
      return ImportCsvResult(success: false, message: 'インポートエラー: $e');
    }
  }

  // 1頭分の回顧メモを保存し、画面データを再読み込みする
  Future<void> saveHorseMemo(HorseMemo memo) async {
    await _horseRepo.insertOrUpdateHorseMemo(memo);
    await loadPageData();
  }

  // --- 表示用の集計データ（馬券画像PageView・収支サマリー用） ---

  // 全チケットの購入情報を券種別に集約（払戻表示の的中判定用）
  Map<String, List<List<int>>> get userCombinationsByType {
    final Map<String, List<List<int>>> result = {};
    final parsedTickets = pageData?.parsedTickets ?? [];

    for (var ticket in parsedTickets) {
      if (ticket['購入内容'] != null) {
        final purchaseDetails = ticket['購入内容'] as List;
        for (var detail in purchaseDetails) {
          final ticketTypeId = detail['式別'] as String?;
          if (ticketTypeId != null && detail['all_combinations'] != null) {
            result.putIfAbsent(ticketTypeId, () => []);
            final combinations = detail['all_combinations'] as List;
            for (var c in combinations) {
              if (c is List) {
                result[ticketTypeId]!.add(c.cast<int>());
              }
            }
          }
        }
      }
    }
    return result;
  }

  // 現在表示中のチケット
  Map<String, dynamic>? get currentTicket {
    final tickets = pageData?.parsedTickets ?? [];
    if (tickets.isEmpty) return null;
    return tickets[currentTicketIndex < tickets.length ? currentTicketIndex : 0];
  }

  // 現在表示中チケットの収支計算
  HitResult? get currentHitResult {
    final raceResult = pageData?.raceResult;
    final ticket = currentTicket;
    if (ticket == null || raceResult == null || raceResult.isIncomplete) return null;
    return HitChecker.check(parsedTicket: ticket, raceResult: raceResult);
  }

  // 指定インデックスの馬券が的中しているかどうか（払戻金が発生していれば的中とみなす）
  bool isTicketHit(int index) {
    final raceResult = pageData?.raceResult;
    final tickets = pageData?.parsedTickets ?? [];
    if (raceResult == null || raceResult.isIncomplete || index >= tickets.length) return false;
    final hitResult = HitChecker.check(parsedTicket: tickets[index], raceResult: raceResult);
    return hitResult.totalPayout > 0;
  }

  // レース全体の収支計算
  RaceBalanceSummary get raceBalanceSummary {
    final raceResult = pageData?.raceResult;
    final parsedTickets = pageData?.parsedTickets ?? [];

    int raceTotalPurchase = 0;
    int raceTotalPayout = 0;
    int raceTotalRefund = 0;

    for (var ticket in parsedTickets) {
      final amount = ticket['合計金額'] as int? ?? 0;
      raceTotalPurchase += amount;

      if (raceResult != null && !raceResult.isIncomplete) {
        final hit = HitChecker.check(parsedTicket: ticket, raceResult: raceResult);
        raceTotalPayout += hit.totalPayout;
        raceTotalRefund += hit.totalRefund;
      }
    }

    return RaceBalanceSummary(
      totalPurchase: raceTotalPurchase,
      totalPayout: raceTotalPayout,
      totalRefund: raceTotalRefund,
    );
  }
}
