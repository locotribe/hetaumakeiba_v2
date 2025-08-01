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

class PageData {
  final Map<String, dynamic>? parsedTicket;
  final RaceResult? raceResult;

  PageData({
    this.parsedTicket,
    this.raceResult,
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

  Future<PageData> _loadPageData() async {
    try {
      Map<String, dynamic>? parsedTicket;
      if (widget.qrData != null) {
        parsedTicket = json.decode(widget.qrData!.parsedDataJson) as Map<String, dynamic>;
      }

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

  Future<void> _handleRefresh() async {
    try {
      final raceId = widget.raceId;
      print('DEBUG: Refreshing race data for raceId: $raceId');
      final newRaceResult = await ScraperService.scrapeRaceDetails(
          'https://db.netkeiba.com/race/$raceId'
      );
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

    setState(() {
      _pageDataFuture = _loadPageData();
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('レース結果'),
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

                // ▼▼▼ ユーザーの組み合わせを、式別ごとに分類して保持するMapに変更 ▼▼▼
                final Map<String, Set<String>> userCombinationsByType = {};
                if (parsedTicket != null && parsedTicket['購入内容'] != null) {
                  final purchaseDetails = parsedTicket['購入内容'] as List;
                  for (var detail in purchaseDetails) {
                    final ticketType = detail['式別'] as String?;
                    if (ticketType != null && detail['all_combinations'] != null) {
                      // この式別のセットがまだMapになければ初期化
                      userCombinationsByType.putIfAbsent(ticketType, () => <String>{});

                      final combinations = detail['all_combinations'] as List;
                      for (var c in combinations) {
                        if (c is List) {
                          // 組み合わせはソートされていないので、-で連結するだけ
                          final combinationString = c.join('-');
                          userCombinationsByType[ticketType]!.add(combinationString);
                        }
                      }
                    }
                  }
                }
                // ▲▲▲ 修正ここまで ▲▲▲

                return RefreshIndicator(
                  onRefresh: _handleRefresh,
                  child: ListView(
                    padding: const EdgeInsets.all(8.0),
                    children: [
                      if (parsedTicket != null)
                        _buildUserTicketCard(parsedTicket),
                      if (raceResult != null) ...[
                        if (raceResult.isIncomplete)
                          _buildIncompleteRaceDataCard()
                        else ...[
                          _buildRaceInfoCard(raceResult),
                          _buildFullResultsCard(raceResult),
                          _buildRefundsCard(raceResult, userCombinationsByType), // 修正したMapを渡す
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

  // ▼▼▼ 払戻情報カードの判定ロジックを全面的に修正 ▼▼▼
  Widget _buildRefundsCard(RaceResult raceResult, Map<String, Set<String>> userCombinationsByType) {
    // 文字列を正規化・ソートして比較可能な canonical（正準）形式にするヘルパー関数
    String createCanonicalString(String combo, String type) {
      // スペースを削除し、矢印をハイフンに統一
      String normalized = combo.replaceAll(' ', '').replaceAll('→', '-');
      // 馬連、ワイド、3連複、枠連は数字をソートして順序を不問にする
      if (type == '馬連' || type == 'ワイド' || type == '3連複' || type == '枠連') {
        var parts = normalized.split('-');
        // 数字として正しくソートするためにintに変換
        parts.sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));
        return parts.join('-');
      }
      return normalized;
    }

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
                          // 現在の払戻情報の式別に対応する、ユーザーの組み合わせセットを取得
                          final userCombosForThisType = userCombinationsByType[refund.ticketType] ?? const <String>{};

                          // 払戻情報の組み合わせを正準形式に変換
                          final canonicalPayoutCombination = createCanonicalString(payout.combination, refund.ticketType);

                          // ユーザーの組み合わせセットの中に、一致するものが存在するかチェック
                          bool isHit = userCombosForThisType.any((userCombo) {
                            final canonicalUserCombo = createCanonicalString(userCombo, refund.ticketType);
                            return canonicalUserCombo == canonicalPayoutCombination;
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
            }).toList(),
          ],
        ),
      ),
    );
  }
}