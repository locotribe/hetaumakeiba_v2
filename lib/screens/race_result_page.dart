// lib/screens/race_result_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/logic/parse.dart';
import 'package:hetaumakeiba_v2/models/qr_data_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/services/scraper_service.dart';
import 'package:hetaumakeiba_v2/utils/url_generator.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart';
import 'package:hetaumakeiba_v2/widgets/purchase_details_card.dart';

// ▼▼▼ ステップ2で変更 ▼▼▼
// PageDataクラスを修正し、parsedTicketをnull許容にする
class PageData {
  final Map<String, dynamic>? parsedTicket; // 馬券データは存在しない場合がある
  final RaceResult? raceResult;

  PageData({
    this.parsedTicket,
    this.raceResult,
  });
}
// ▲▲▲ ステップ2で変更 ▲▲▲

class RaceResultPage extends StatefulWidget {
  // ▼▼▼ ステップ2で変更 ▼▼▼
  // raceIdを必須とし、qrDataを任意（null許容）にする
  final String raceId;
  final QrData? qrData;

  const RaceResultPage({
    super.key,
    required this.raceId,
    this.qrData,
  });
  // ▲▲▲ ステップ2で変更 ▲▲▲

  @override
  State<RaceResultPage> createState() => _RaceResultPageState();
}

class _RaceResultPageState extends State<RaceResultPage> {
  late Future<PageData> _pageDataFuture;
  final DatabaseHelper _dbHelper = DatabaseHelper();

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
    _pageDataFuture = _loadPageData();
  }

  // ▼▼▼ ステップ2で変更 ▼▼▼
  // データ読み込みロジックを修正
  Future<PageData> _loadPageData() async {
    try {
      // qrDataがnullかどうかで処理を分岐
      Map<String, dynamic>? parsedTicket;
      if (widget.qrData != null) {
        parsedTicket = json.decode(widget.qrData!.parsedDataJson) as Map<String, dynamic>;
      }

      // raceIdは常にwidgetから取得
      RaceResult? raceResult = await _dbHelper.getRaceResult(widget.raceId);

      return PageData(
        parsedTicket: parsedTicket,
        raceResult: raceResult,
      );
    } catch (e) {
      print('ページデータの読み込みに失敗しました: $e');
      throw Exception('データの表示に失敗しました。');
    }
  }

  /// ページが手動で更新されたときに呼び出される関数
  Future<void> _handleRefresh() async {
    try {
      // raceIdは常にwidgetから取得
      final raceId = widget.raceId;

      // 最新のレース結果をスクレイピング
      print('DEBUG: Refreshing race data for raceId: $raceId');
      final newRaceResult = await ScraperService.scrapeRaceDetails(
          'https://db.netkeiba.com/race/$raceId'
      );

      // データベースを更新（上書き）
      await _dbHelper.insertOrUpdateRaceResult(newRaceResult);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('レース結果を更新しました。')),
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

    // UIを再描画するために、再度DBからデータを読み込む
    setState(() {
      _pageDataFuture = _loadPageData();
    });
  }
  // ▲▲▲ ステップ2で変更 ▲▲▲


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // ▼▼▼ ステップ2でタイトルを汎用的なものに変更 ▼▼▼
        title: const Text('レース結果'),
        // ▲▲▲ ステップ2でタイトルを汎用的なものに変更 ▲▲▲
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: CustomBackground(
              overallBackgroundColor: Color.fromRGBO(231, 234, 234, 1.0),
              stripeColor: Color.fromRGBO(219, 234, 234, 0.6),
              fillColor: Color.fromRGBO(172, 234, 231, 1.0),
            ),
          ),
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
                final parsedTicket = pageData.parsedTicket;
                final raceResult = pageData.raceResult;

                // ▼▼▼ ステップ2で変更 ▼▼▼
                // parsedTicketがnullでない場合のみ組み合わせを計算
                final Set<String> userCombinations = {};
                if (parsedTicket != null && parsedTicket['購入内容'] != null) {
                  final purchaseDetails = parsedTicket['購入内容'] as List;
                  for (var detail in purchaseDetails) {
                    if (detail['all_combinations'] != null) {
                      final combinations = detail['all_combinations'] as List;
                      for (var c in combinations) {
                        if (c is List) {
                          final combinationString = c.join('-');
                          userCombinations.add(combinationString);
                        }
                      }
                    }
                  }
                }

                return RefreshIndicator(
                  onRefresh: _handleRefresh,
                  child: ListView(
                    padding: const EdgeInsets.all(8.0),
                    children: [
                      // parsedTicketがnullでない場合のみ購入内容カードを表示
                      if (parsedTicket != null)
                        _buildUserTicketCard(parsedTicket),
                      // ▲▲▲ ステップ2で変更 ▲▲▲
                      if (raceResult != null) ...[
                        if (raceResult.isIncomplete)
                          _buildIncompleteRaceDataCard()
                        else ...[
                          _buildRaceInfoCard(raceResult),
                          _buildFullResultsCard(raceResult),
                          _buildRefundsCard(raceResult, userCombinations),
                        ]
                      ] else ...[
                        _buildNoRaceDataCard(),
                      ]
                    ],
                  ),
                );
              }
              return const Center(child: Text('データがありません。'));
            },
          ),
        ],
      ),
    );
  }

  /// レース結果が不完全な場合に表示するカード
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

  // レース情報がなかった場合に表示するカード
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

  // ユーザーの購入内容カード
  Widget _buildUserTicketCard(Map<String, dynamic> parsedTicket) {
    final purchaseDetails = parsedTicket['購入内容'] as List;
    final totalAmount = parsedTicket['合計金額'] ?? 0;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'あなたの購入内容',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            PurchaseDetailsCard(
              parsedResult: parsedTicket,
              betType: parsedTicket['方式'] as String? ?? '',
            ),
            const Divider(height: 32),
            const Text(
              '全組み合わせリスト',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...purchaseDetails.map((detail) {
              final combination = (detail['all_combinations'] as List?)
                  ?.map((c) => (c as List).join('-'))
                  .join(', ');
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0, left: 8.0),
                child: Text(
                  '${detail['式別']}: ${combination ?? "組み合わせなし"}',
                  style: const TextStyle(fontSize: 14),
                ),
              );
            }).toList(),
            const Divider(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '合計購入金額: $totalAmount円',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // レース情報カード
  Widget _buildRaceInfoCard(RaceResult raceResult) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              raceResult.raceTitle,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(raceResult.raceDate),
            Text(raceResult.raceInfo),
            Text(raceResult.raceGrade),
          ],
        ),
      ),
    );
  }

  // レース全着順カード
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
                  DataColumn(label: Text('馬番')),
                  DataColumn(label: Text('馬名')),
                  DataColumn(label: Text('騎手')),
                  DataColumn(label: Text('単勝')),
                  DataColumn(label: Text('人気')),
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

  // 払戻情報カード
  Widget _buildRefundsCard(RaceResult raceResult, Set<String> userCombinations) {
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
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text(
                        refund.ticketType,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: refund.payouts.map((payout) {
                          // 的中しているか判定
                          final isHit = userCombinations.contains(payout.combination);

                          // 的中している場合のスタイル
                          final hitTextStyle = TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          );

                          // 的中している場合のデコレーション
                          final hitDecoration = BoxDecoration(
                            color: Colors.red.shade50,
                          );

                          return Container(
                            decoration: isHit ? hitDecoration : null,
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
            }).toList(),
          ],
        ),
      ),
    );
  }
}