// lib/screens/race_result_page.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/logic/hit_checker.dart';
import 'package:hetaumakeiba_v2/models/qr_data_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/services/analytics_service.dart';
import 'package:hetaumakeiba_v2/widgets/betting_ticket_card.dart';
import 'package:hetaumakeiba_v2/main.dart';
import 'package:hetaumakeiba_v2/models/horse_memo_model.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_analysis_model.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_race_data.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/logic/combination_calculator.dart';
import 'package:hetaumakeiba_v2/services/race_result_scraper_service.dart';
import 'package:hetaumakeiba_v2/widgets/race_header_card.dart';
import 'package:hetaumakeiba_v2/services/statistics_service.dart';
import 'package:hetaumakeiba_v2/logic/ai/race_analyzer.dart';

// 修正: 複数のチケット情報を保持できるように変更
class PageData {
  final List<Map<String, dynamic>> parsedTickets; // 変更: リスト化
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
  late Future<PageData> _pageDataFuture;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // 修正: 複数枚表示用の変数を追加
  late PageController _ticketPageController;
  List<QrData> _qrDataList = [];
  int _currentTicketIndex = 0;
  bool _isInitialized = false;

  final Map<String, Color> _frameColors = {
    '1': Colors.white,
    '2': Colors.black,
    '3': Colors.red,
    '4': Colors.blue,
    '5': Colors.yellow,
    '6': Colors.green,
    '7': Colors.orange,
    '8': Colors.pink.shade200,
  };

  Color _getTextColorForFrame(String frameNumber) {
    switch (frameNumber) {
      case '1':
      case '5':
        return Colors.black;
      default:
        return Colors.white;
    }
  }

  @override
  void initState() {
    super.initState();
    // 初期化ロジックを didChangeDependencies に移動
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

  // ★追加: QRコードの生文字列からレースIDを生成するヘルパーメソッド
  // parse.dartのロジックに基づき、所定の位置からコードを抽出して連結する
  String? _generateRaceIdFromQr(String qrContent) {
    try {
      if (qrContent.length < 14) return null;

      // parse.dartのイテレータロジックに基づく抽出位置
      // index 0: format (1 char)
      // index 1-2: racecourseCode (2 chars)
      // index 3-4: skip (2 chars)
      // index 5: alternativeCode (1 char)
      // index 6-7: year (2 chars)
      // index 8-9: kai/round (2 chars)
      // index 10-11: nichime/day (2 chars)
      // index 12-13: race (2 chars)

      final place = qrContent.substring(1, 3);
      final year = qrContent.substring(6, 8);
      final kai = qrContent.substring(8, 10);
      final nichime = qrContent.substring(10, 12);
      final race = qrContent.substring(12, 14);

      // 20xx年と仮定してID生成 (YYYY + Place + Kai + Nichime + Race)
      return "20$year$place$kai$nichime$race";
    } catch (e) {
      print('Failed to generate Race ID from QR: $e');
      return null;
    }
  }

  Future<PageData> _loadPageData() async {
    try {
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

      RaceResult? raceResult = await _dbHelper.getRaceResult(widget.raceId);

      final userId = localUserId;
      if (raceResult != null && userId != null) {
        final memos = await _dbHelper.getMemosForRace(userId, widget.raceId);
        final memosMap = {for (var memo in memos) memo.horseId: memo};
        final List<PredictionHorseDetail> horseDetailsForPacePrediction = [];
        final Map<String, List<HorseRaceRecord>> allPastRecords = {};

        for (var horseResult in raceResult.horseResults) {
          if (memosMap.containsKey(horseResult.horseId)) {
            horseResult.userMemo = memosMap[horseResult.horseId];
          }
          final pastRecords = await _dbHelper.getHorsePerformanceRecords(horseResult.horseId);
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
      await _dbHelper.insertOrUpdateRaceResult(newRaceResult);
      await AnalyticsService().updateAggregatesOnResultConfirmed(newRaceResult.raceId, userId);

      // 2. ★修正: DBから同一レースの他の馬券（兄弟馬券）を検索してリストを更新
      // QRコードの生データからレースIDを生成し、現在のIDと一致するものを抽出する
      final allQrData = await _dbHelper.getAllQrData(userId);
      final List<QrData> siblings = [];

      final currentRaceId = widget.raceId;

      for (var qr in allQrData) {
        // ヘルパーメソッドでID生成
        final generatedId = _generateRaceIdFromQr(qr.qrCode);
        if (generatedId == currentRaceId) {
          siblings.add(qr);
        }
      }

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

  Future<void> _showMemoDialog(HorseResult horse) async {
    final userId = localUserId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインが必要です。')),
      );
      return;
    }

    final memoController = TextEditingController(text: horse.userMemo?.reviewMemo);
    final formKey = GlobalKey<FormState>();
    final predictionMemo = horse.userMemo?.predictionMemo;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('${horse.horseName} - メモ'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (predictionMemo != null && predictionMemo.isNotEmpty) ...[
                    const Text('予想メモ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8.0),
                      margin: const EdgeInsets.only(top: 4.0, bottom: 16.0),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: Text(predictionMemo),
                    ),
                  ],
                  const Text('総評メモ', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: memoController,
                    autofocus: true,
                    maxLines: null,
                    decoration: const InputDecoration(
                      hintText: 'ここに総評メモを入力...',
                      border: OutlineInputBorder(),
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
                  final newMemo = HorseMemo(
                    id: horse.userMemo?.id,
                    userId: userId,
                    raceId: widget.raceId,
                    horseId: horse.horseId,
                    predictionMemo: horse.userMemo?.predictionMemo,
                    reviewMemo: memoController.text,
                    timestamp: DateTime.now(),
                  );
                  await _dbHelper.insertOrUpdateHorseMemo(newMemo);
                  Navigator.of(context).pop();
                  _loadPageData();
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
                    // ★修正: 複数の馬券をPageViewで表示
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

  // ★追加: 馬券のPageViewと収支サマリーを表示
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
          height: 240, // BettingTicketCardの高さ(230) + マージン
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
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: BettingTicketCard(ticketData: ticket, raceResult: raceResult),
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
                      child: Text('🎯 $detail', style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold)),
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

  Widget _buildUserTicketCard(Map<String, dynamic> parsedTicket, RaceResult? raceResult, HitResult? hitResult) {
    final totalAmount = parsedTicket['合計金額'] as int? ?? 0;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BettingTicketCard(ticketData: parsedTicket, raceResult: raceResult),
            if (hitResult != null) ...[
              const SizedBox(height: 8),
              _buildResultRow('払戻合計', '${hitResult.totalPayout}円'),
              _buildResultRow('返還合計', '${hitResult.totalRefund}円'),
              _buildResultRow(
                '収支',
                '${(hitResult.totalPayout + hitResult.totalRefund - totalAmount) >= 0 ? '+' : ''}${hitResult.totalPayout + hitResult.totalRefund - totalAmount}円',
                isProfit: true,
                profit: hitResult.totalPayout + hitResult.totalRefund - totalAmount,
              ),
              if (hitResult.hitDetails.isNotEmpty) ...[
                ...hitResult.hitDetails.map((detail) => Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2.0, left: 8.0),
                    child: Text('🎯 $detail', style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold)),
                  ),
                )),
              ],
              if (hitResult.refundDetails.isNotEmpty) ...[
                ...hitResult.refundDetails.map((detail) => Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2.0, left: 8.0),
                    child: Text('↩️ $detail', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
                  ),
                )),
              ],
            ],
          ],
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
            const Text(
              'レース結果',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 16,
                columns: const [
                  DataColumn(label: Text('着')),
                  DataColumn(label: Text('メモ')),
                  DataColumn(label: Text('馬番')),
                  DataColumn(label: Text('馬名')),
                  DataColumn(label: Text('騎手')),
                  DataColumn(label: Text('単勝')),
                  DataColumn(label: Text('人気')),
                ],
                rows: raceResult.horseResults.map((horse) {
                  return DataRow(cells: [
                    DataCell(Text(horse.rank)),
                    DataCell(_buildMemoCell(horse)),
                    DataCell(
                      Center(
                        child: Container(
                          width: 32,
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          decoration: BoxDecoration(
                            color: _frameColors[horse.frameNumber] ?? Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                            border: horse.frameNumber == '1' ? Border.all(color: Colors.grey.shade400) : null,
                          ),
                          child: Text(
                            horse.horseNumber,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _getTextColorForFrame(horse.frameNumber),
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
    bool hasPredictionMemo = horse.userMemo?.predictionMemo != null && horse.userMemo!.predictionMemo!.isNotEmpty;
    bool hasReviewMemo = horse.userMemo?.reviewMemo != null && horse.userMemo!.reviewMemo!.isNotEmpty;

    return InkWell(
      onTap: () => _showMemoDialog(horse),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.description_outlined,
            color: hasPredictionMemo ? Colors.blueAccent : Colors.grey,
            size: 20,
          ),
          const SizedBox(width: 2),
          Icon(
            Icons.rate_review_outlined,
            color: hasReviewMemo ? Colors.orange.shade700 : Colors.grey,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value, {bool isProfit = false, int profit = 0}) {
    Color valueColor = Colors.black87;
    if (isProfit) {
      if (profit > 0) valueColor = Colors.blue.shade700;
      if (profit < 0) valueColor = Colors.red.shade700;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 15)),
          Text(
            value,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: valueColor),
          ),
        ],
      ),
    );
  }
}