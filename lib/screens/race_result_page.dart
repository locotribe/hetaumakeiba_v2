// lib/screens/race_result_page.dart

import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/repositories/horse_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/race_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/ticket_repository.dart';
import 'package:hetaumakeiba_v2/logic/ai/race_analyzer.dart';
import 'package:hetaumakeiba_v2/logic/combination_calculator.dart';
import 'package:hetaumakeiba_v2/logic/hit_checker.dart';
import 'package:hetaumakeiba_v2/main.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_analysis_model.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_race_data.dart';
import 'package:hetaumakeiba_v2/models/horse_memo_model.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/qr_data_model.dart';
import 'package:hetaumakeiba_v2/models/race_memo_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/screens/bulk_review_edit_page.dart';
import 'package:hetaumakeiba_v2/services/analytics_service.dart';
import 'package:hetaumakeiba_v2/services/race_result_scraper_service.dart';
import 'package:hetaumakeiba_v2/services/statistics_service.dart';
import 'package:hetaumakeiba_v2/utils/gate_color_utils.dart';
import 'package:hetaumakeiba_v2/widgets/betting_ticket_card.dart';
import 'package:hetaumakeiba_v2/widgets/race_header_card.dart';
import 'package:hetaumakeiba_v2/widgets/race_review_card.dart';
import 'package:hetaumakeiba_v2/logic/memo_import_logic.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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

class RaceResultPage extends StatefulWidget {
  final String raceId;
  final QrData? qrData;

  const RaceResultPage({
    super.key,
    required this.raceId,
    this.qrData,
  });

  @override
  State<RaceResultPage> createState() => _RaceResultPageState();
}

class _RaceResultPageState extends State<RaceResultPage> {
  final RaceRepository _raceRepo = RaceRepository();
  final TicketRepository _ticketRepo = TicketRepository();
  final HorseRepository _horseRepo = HorseRepository();

  late Future<PageData> _pageDataFuture;

  late PageController _ticketPageController;
  List<QrData> _qrDataList = [];
  int _currentTicketIndex = 0;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _initializeData();
      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    _ticketPageController.dispose();
    super.dispose();
  }

  // 初期データ設定（RouteSettingsからの引数受け取り含む）
  void _initializeData() {
    // 遷移元から渡された引数をチェック
    final args = ModalRoute.of(context)?.settings.arguments;
    int initialIndex = 0;

    if (args is Map && args.containsKey('siblingTickets')) {
      // 保存済みリストから遷移した場合
      final siblingTickets = args['siblingTickets'] as List<QrData>;
      _qrDataList = siblingTickets;
      initialIndex = args['initialIndex'] as int? ?? 0;
    } else {
      // QR読み取りや直接遷移の場合（単一）
      if (widget.qrData != null) {
        _qrDataList = [widget.qrData!];
      }
    }

    // データがない場合のフォールバック（通常ありえない）
    if (_qrDataList.isEmpty && widget.qrData != null) {
      _qrDataList = [widget.qrData!];
    }

    _currentTicketIndex = initialIndex;
    _ticketPageController = PageController(initialPage: initialIndex, viewportFraction: 0.92); // 少し隣が見えるように
    _pageDataFuture = _loadPageData();
  }

  Future<PageData> _loadPageData() async {
    try {
      if (_qrDataList.isEmpty) {
        // Step3で追加した高速検索メソッドを使用
        final savedTickets = await _ticketRepo.getQrDataByRaceId(widget.raceId);
        if (savedTickets.isNotEmpty) {
          _qrDataList = savedTickets;
        }
      }
      // 全チケットをパース
      List<Map<String, dynamic>> parsedTickets = [];
      for (var qr in _qrDataList) {
        try {
          final parsed = json.decode(qr.parsedDataJson) as Map<String, dynamic>;
          parsedTickets.add(parsed);
        } catch (e) {
          print('Error parsing ticket: $e');
        }
      }

      RaceResult? raceResult = await _raceRepo.getRaceResult(widget.raceId);

      final userId = localUserId;
      if (raceResult != null && userId != null) {
        final memos = await _horseRepo.getMemosForRace(userId, widget.raceId);
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
            raceResult.raceTitle, widget.raceId);

        final pacePrediction = RaceAnalyzer.predictRacePace(
            horseDetailsForPacePrediction, allPastRecords, pastRaceResults);

        return PageData(
          parsedTickets: parsedTickets,
          raceResult: raceResult,
          pacePrediction: pacePrediction,
        );
      }

      return PageData(
        parsedTickets: parsedTickets,
        raceResult: raceResult,
      );
    } catch (e) {
      print('ページデータの読み込みに失敗しました: $e');
      throw Exception('データの表示に失敗しました。');
    }
  }

  Future<void> _handleRefresh() async {
    try {
      final userId = localUserId;
      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ユーザー情報の取得に失敗しました。')),
          );
        }
        return;
      }

      final raceId = widget.raceId;
      print('DEBUG: Refreshing race data for raceId: $raceId');

      // 1. レース結果のスクレイピング更新
      final newRaceResult = await RaceResultScraperService.scrapeRaceDetails(
          'https://db.netkeiba.com/race/$raceId'
      );
      await AnalyticsService().updateAggregatesOnResultConfirmed(newRaceResult.raceId, userId);

      final siblings = await _ticketRepo.getQrDataByRaceId(widget.raceId);

      if (siblings.isNotEmpty) {
        // 既存のリストにあるものは除外して追加（ID重複防止）
        final existingIds = _qrDataList.map((e) => e.id).toSet();
        for (var sib in siblings) {
          if (!existingIds.contains(sib.id)) {
            _qrDataList.add(sib);
          }
        }
        // ID順にソート（保存順）
        _qrDataList.sort((a, b) => (a.id ?? 0).compareTo(b.id ?? 0));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('レース結果と馬券リストを更新しました。')),
        );
      }
    } catch (e) {
      print('ERROR: Failed to refresh race data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新に失敗しました: $e')),
        );
      }
    }

    setState(() {
      _pageDataFuture = _loadPageData();
    });
  }

  Future<void> _openBulkReviewEdit(RaceResult raceResult) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => BulkReviewEditPage(
          raceId: widget.raceId,
          horseResults: raceResult.horseResults,
        ),
      ),
    );
    if (result == true) {
      _handleRefresh(); // 保存されたら画面を更新
    }
  }

  Future<void> _exportReviewsAsCsv(RaceResult raceResult) async {
    final userId = localUserId;
    if (userId == null) return;

    // レース総評を取得
    final raceMemo = await _raceRepo.getRaceMemo(userId, widget.raceId);
    final raceMemoText = raceMemo?.memo ?? '';

    final List<List<dynamic>> rows = [];
    // ヘッダーに raceMemo を追加
    rows.add(['raceId', 'horseId', 'horseNumber', 'horseName', 'reviewMemo', 'predictionMemo', 'raceMemo']);

    for (int i = 0; i < raceResult.horseResults.length; i++) {
      final horse = raceResult.horseResults[i];
      rows.add([
        widget.raceId,
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
    final path = '${directory.path}/${widget.raceId}_reviews.csv';
    final file = File(path);
    await file.writeAsString(csv);

    await Share.shareXFiles([XFile(path)], text: '${raceResult.raceTitle} の回顧メモ');
  }

  Future<void> _importReviewsFromCsv() async {
    final userId = localUserId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインが必要です。')),
      );
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null || result.files.single.path == null) return;

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
      final existingHorseMemos = await _horseRepo.getMemosForRace(userId, widget.raceId);
      final existingHorseMemosMap = {for (var m in existingHorseMemos) m.horseId: m};
      final existingRaceMemo = await _raceRepo.getRaceMemo(userId, widget.raceId);

      final List<HorseMemo> memosToUpdate = [];
      bool updateRaceMemo = false;
      String finalRaceMemo = existingRaceMemo?.memo ?? '';
      int updatedHorseCount = 0;

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        final csvRaceId = row[0].toString();

        if (csvRaceId != widget.raceId) continue;

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
          final resolved = await _resolveConflictDialog('$horseNameの回顧メモ', reviewMerge);
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
          final resolved = await _resolveConflictDialog('$horseNameの予想メモ', predictionMerge);
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
              final resolved = await _resolveConflictDialog('レース総評', raceMerge);
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
          raceId: widget.raceId,
          memo: finalRaceMemo,
          timestamp: DateTime.now(),
        );
        await _raceRepo.insertOrUpdateRaceMemo(newRaceMemo);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '$updatedHorseCount頭のメモ' +
                      (updateRaceMemo ? 'とレース総評' : '') +
                      'を更新・インポートしました'
              )
          ),
        );

        // 画面を再読み込みして最新データを反映（RaceReviewCardも更新される）
        setState(() {
          _pageDataFuture = _loadPageData();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('インポートエラー: $e')),
        );
      }
    }
  }

  /// 競合発生時にユーザーに解決アクションを選択させるダイアログ
  Future<String?> _resolveConflictDialog(String title, MemoMergeResult conflict) async {
    return await showDialog<String>(
      context: context,
      barrierDismissible: false, // 誤タップで閉じるのを防ぎ、必ず選択させる
      builder: (context) => AlertDialog(
        title: Text('競合の解決: $title', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('【現在のデータ】', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(top: 4, bottom: 12),
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                child: Text(conflict.existingText.isEmpty ? '(なし)' : conflict.existingText),
              ),
              const Text('【インポートデータ】', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(top: 4, bottom: 16),
                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4)),
                child: Text(conflict.newText.isEmpty ? '(なし)' : conflict.newText),
              ),
              const Text('このデータをどのように処理しますか？', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, conflict.existingText),
            child: const Text('スキップ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, conflict.newText),
            child: const Text('CSVで上書き', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, '${conflict.existingText}\n\n${conflict.newText}'),
            child: const Text('追記する'),
          ),
        ],
      ),
    );
  }

  Future<void> _showMemoDialog(HorseResult horse) async {
    final userId = localUserId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインが必要です。')),
      );
      return;
    }

    final existingReviewMemo = horse.userMemo?.reviewMemo ?? '';
    final predictionMemo = horse.userMemo?.predictionMemo;

    // 既存メモ編集用のコントローラー
    final existingMemoController = TextEditingController(text: existingReviewMemo);
    // 新規追記用のコントローラー
    final appendController = TextEditingController();

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('${horse.horseName} - 回顧メモ'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. 予想メモ（完全読み取り専用）
                  if (predictionMemo != null && predictionMemo.isNotEmpty) ...[
                    const Text('【当時の予想】', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue)),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8.0),
                      margin: const EdgeInsets.only(top: 4.0, bottom: 16.0),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(4.0),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Text(predictionMemo, style: const TextStyle(fontSize: 13)),
                    ),
                  ],

                  // 2. 既存の回顧メモ（タップで修正可能だが、見た目は表示欄風）
                  if (existingReviewMemo.isNotEmpty) ...[
                    const Text('【これまでの回顧】 (タップで修正可)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.orange)),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: existingMemoController,
                      maxLines: null,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.orange.shade50,
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.orange.shade200),
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.orange.shade200),
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        contentPadding: const EdgeInsets.all(8.0),
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 3. 追記用フォーム（ここに最初からフォーカスが当たるため、誤消去を防げる）
                  const Text('【追記】', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green)),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: appendController,
                    autofocus: true, // 開いた瞬間ここにカーソルが合う
                    maxLines: null,
                    minLines: 3,
                    decoration: const InputDecoration(
                      hintText: '新たな気づきや次走へのメモを追記...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  // 既存のメモ（編集反映）と、新しく追記したメモを結合
                  String finalMemo = existingMemoController.text.trim();
                  final appendedText = appendController.text.trim();

                  if (appendedText.isNotEmpty) {
                    if (finalMemo.isNotEmpty) {
                      finalMemo += '\n\n'; // 既存のメモがあれば改行を挟む
                    }
                    finalMemo += appendedText;
                  }

                  final newMemo = HorseMemo(
                    id: horse.userMemo?.id,
                    userId: userId,
                    raceId: widget.raceId,
                    horseId: horse.horseId,
                    predictionMemo: horse.userMemo?.predictionMemo, // 維持
                    reviewMemo: finalMemo, // 結合したメモを保存
                    timestamp: DateTime.now(),
                  );
                  await _horseRepo.insertOrUpdateHorseMemo(newMemo);
                  Navigator.of(context).pop();

                  // 画面を再読み込みして最新データを反映
                  setState(() {
                    _pageDataFuture = _loadPageData();
                  });
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FutureBuilder<PageData>(
          future: _pageDataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'エラー: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            if (snapshot.hasData) {
              final pageData = snapshot.data!;
              final parsedTickets = pageData.parsedTickets;
              final raceResult = pageData.raceResult;

              final Map<String, List<List<int>>> userCombinationsByType = {};

              // 全チケットの購入情報を集約（払戻表示用）
              for (var ticket in parsedTickets) {
                if (ticket['購入内容'] != null) {
                  final purchaseDetails = ticket['購入内容'] as List;
                  for (var detail in purchaseDetails) {
                    final ticketTypeId = detail['式別'] as String?;
                    if (ticketTypeId != null && detail['all_combinations'] != null) {
                      userCombinationsByType.putIfAbsent(ticketTypeId, () => []);
                      final combinations = detail['all_combinations'] as List;
                      for (var c in combinations) {
                        if (c is List) {
                          userCombinationsByType[ticketTypeId]!.add(c.cast<int>());
                        }
                      }
                    }
                  }
                }
              }

              return RefreshIndicator(
                onRefresh: _handleRefresh,
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  children: [
                    if (parsedTickets.isNotEmpty)
                      _buildTicketPageView(parsedTickets, raceResult),

                    if (raceResult != null) ...[
                      if (raceResult.isIncomplete)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: _buildIncompleteRaceDataCard(),
                        )
                      else ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: _buildRaceInfoCard(raceResult, pageData.pacePrediction),
                        ),
                        // 【新規追加】レース総評カードをここに挿入
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: RaceReviewCard(
                            raceId: widget.raceId,
                            userId: localUserId ?? '',
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: _buildFullResultsCard(raceResult),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: _buildRefundsCard(raceResult, userCombinationsByType),
                        ),
                      ]
                    ] else ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: _buildNoRaceDataCard(),
                      ),
                    ]
                  ],
                ),
              );
            }
            return const Center(child: Text('データがありません。'));
          },
        ),
      ],
    );
  }

  Widget _buildTicketPageView(List<Map<String, dynamic>> parsedTickets, RaceResult? raceResult) {
    // 現在表示中のチケット
    final currentTicket = parsedTickets.isNotEmpty
        ? parsedTickets[_currentTicketIndex < parsedTickets.length ? _currentTicketIndex : 0]
        : null;

    // 現在のチケットの収支計算
    HitResult? currentHitResult;
    if (currentTicket != null && raceResult != null && !raceResult.isIncomplete) {
      currentHitResult = HitChecker.check(parsedTicket: currentTicket, raceResult: raceResult);
    }

    // レース全体の収支計算
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
    final raceBalance = (raceTotalPayout + raceTotalRefund) - raceTotalPurchase;

    return Column(
      children: [
        // 1. 馬券イメージ（横スワイプ可能）
        SizedBox(
          height: 240,
          child: PageView.builder(
            controller: _ticketPageController,
            itemCount: parsedTickets.length,
            onPageChanged: (index) {
              setState(() {
                _currentTicketIndex = index;
              });
            },
            itemBuilder: (context, index) {
              final ticket = parsedTickets[index];

              // 的中判定ロジック
              bool isHit = false;
              if (raceResult != null && !raceResult.isIncomplete) {
                final hitResult = HitChecker.check(parsedTicket: ticket, raceResult: raceResult);
                // 払戻金が発生していれば的中とみなす
                isHit = hitResult.totalPayout > 0;
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Stack(
                  children: [
                    // 1層目: 馬券カード本体
                    BettingTicketCard(ticketData: ticket, raceResult: raceResult),

                    // 2層目: 的中画像 (的中時のみ表示)
                    if (isHit)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Image.asset(
                            'assets/images/hit.png',
                            fit: BoxFit.fill,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),

        // 2. インジケーター (複数枚ある場合のみ)
        if (parsedTickets.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(parsedTickets.length, (index) {
                return Container(
                  width: 8.0,
                  height: 8.0,
                  margin: const EdgeInsets.symmetric(horizontal: 4.0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentTicketIndex == index ? Colors.blue.shade700 : Colors.grey.shade300,
                  ),
                );
              }),
            ),
          ),

        // 3. 表示中チケットの詳細結果（的中情報など）
        if (currentHitResult != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                if (currentHitResult.hitDetails.isNotEmpty) ...[
                  ...currentHitResult.hitDetails.map((detail) => Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Text('$detail', style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold)),
                    ),
                  )),
                ],
                if (currentHitResult.refundDetails.isNotEmpty) ...[
                  ...currentHitResult.refundDetails.map((detail) => Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Text('↩️ $detail', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
                    ),
                  )),
                ],
              ],
            ),
          ),

        // 4. レース全体の収支サマリーカード
        if (raceResult != null && !raceResult.isIncomplete)
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            color: raceBalance > 0 ? Colors.blue.shade50 : (raceBalance < 0 ? Colors.red.shade50 : Colors.white),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text('レース合計購入', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text('${raceTotalPurchase}円', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Column(
                    children: [
                      const Text('払戻・返還計', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text('${raceTotalPayout + raceTotalRefund}円', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Column(
                    children: [
                      const Text('レース収支', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text(
                        '${raceBalance >= 0 ? '+' : ''}${raceBalance}円',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: raceBalance > 0 ? Colors.blue.shade800 : (raceBalance < 0 ? Colors.red.shade800 : Colors.black),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildIncompleteRaceDataCard() {
    return Card(
      elevation: 2,
      color: Colors.amber.shade50,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.amber.shade700, size: 32),
              const SizedBox(height: 12),
              const Text(
                'このレースはまだ結果を取得していません。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'レース確定後に、画面を下に引っ張って更新してください。',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoRaceDataCard() {
    return Card(
      elevation: 2,
      color: Colors.orange.shade50,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(
          child: Text(
            'レース結果のデータはまだありません。\nレース確定後に再度ご確認ください。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildRaceInfoCard(RaceResult raceResult, RacePacePrediction? pacePrediction) {
    return RaceHeaderCard(
      title: raceResult.raceTitle,
      detailsLine1: raceResult.raceDate,
      detailsLine2: '${raceResult.raceInfo}\n${raceResult.raceGrade}',
    );
  }

  Widget _buildFullResultsCard(RaceResult raceResult) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー部分：枠線付きのボタン（OutlinedButton）に変更し、ラベルを明確化
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'レース結果',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () => _openBulkReviewEdit(raceResult),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4.0), // 少し角丸のカード風
                        ),
                      ),
                      child: const Text('一括編集', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8), // ボタン間の隙間
                    OutlinedButton(
                      onPressed: _importReviewsFromCsv,
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                      ),
                      child: const Text('CSV入力', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => _exportReviewsAsCsv(raceResult),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                      ),
                      child: const Text('CSV出力', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16,
                columns: const [
                  DataColumn(label: Text('着')),
                  DataColumn(label: Text('馬番')),
                  DataColumn(label: Text('馬名')),
                  DataColumn(label: Text('騎手')),
                  DataColumn(label: Text('単勝')),
                  DataColumn(label: Text('人気')),
                  DataColumn(label: Text('メモ')),
                ],
                rows: raceResult.horseResults.map((horse) {
                  return DataRow(cells: [
                    DataCell(Text(horse.rank)),
                    DataCell(
                      Center(
                        child: Container(
                          width: 32,
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          decoration: BoxDecoration(
                            color: horse.frameNumber.gateBackgroundColor,
                            borderRadius: BorderRadius.circular(4),
                            border: horse.frameNumber == '1' ? Border.all(color: Colors.grey.shade400) : null,
                          ),
                          child: Text(
                            horse.horseNumber,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: horse.frameNumber.gateTextColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    DataCell(Text(horse.horseName)),
                    DataCell(Text(horse.jockeyName)),
                    DataCell(Text(horse.odds)),
                    DataCell(Text(horse.popularity)),
                    DataCell(_buildMemoCell(horse)),
                  ]);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRefundsCard(RaceResult raceResult, Map<String, List<List<int>>> userCombinationsByType) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '払戻',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...raceResult.refunds.map((refund) {
              final ticketTypeName = bettingDict[refund.ticketTypeId] ?? '';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text(
                        ticketTypeName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: refund.payouts.map((payout) {
                          final userCombosForThisType = userCombinationsByType[refund.ticketTypeId] ?? [];
                          bool isHit = userCombosForThisType.any((userCombo) {
                            switch (ticketTypeName) {
                              case '馬連':
                              case 'ワイド':
                              case '3連複':
                              case '枠連':
                                return setEquals(userCombo.toSet(), payout.combinationNumbers.toSet());
                              default:
                                return listEquals(userCombo, payout.combinationNumbers);
                            }
                          });

                          final hitTextStyle = TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade700);
                          final hitDecoration = BoxDecoration(color: Colors.red.shade50);

                          return Container(
                            decoration: isHit ? hitDecoration : null,
                            padding: isHit ? const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.0) : null,
                            child: Text(
                              '${payout.combination} : ${payout.amount}円 (${payout.popularity}人気)',
                              style: isHit ? hitTextStyle : null,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMemoCell(HorseResult horse) {
    final reviewText = horse.userMemo?.reviewMemo ?? '';
    final hasReview = reviewText.isNotEmpty;

    return InkWell(
      onTap: () => _showMemoDialog(horse),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 200), // 右端なので少し広めに許容
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Text(
                hasReview ? reviewText : 'メモなし',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: hasReview ? Colors.black87 : Colors.grey,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.edit,
              size: 16,
              color: hasReview ? Colors.orange.shade800 : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}