// lib/screens/saved_ticket_detail_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/logic/parse.dart';
import 'package:hetaumakeiba_v2/models/qr_data_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/services/scraper_service.dart';
import 'package:hetaumakeiba_v2/utils/url_generator.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart';

// ページのロードに必要なデータをまとめるためのヘルパークラス（簡素化）
class PageData {
  final Map<String, dynamic> parsedTicket;
  final RaceResult? raceResult; // レース結果は存在しない場合もある

  PageData({
    required this.parsedTicket,
    this.raceResult,
  });
}

class SavedTicketDetailPage extends StatefulWidget {
  final QrData qrData;

  const SavedTicketDetailPage({super.key, required this.qrData});

  @override
  State<SavedTicketDetailPage> createState() => _SavedTicketDetailPageState();
}

class _SavedTicketDetailPageState extends State<SavedTicketDetailPage> {
  late Future<PageData> _pageDataFuture;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _pageDataFuture = _loadPageData();
  }

  // DBからデータを読み込むだけのシンプルな処理に変更
  Future<PageData> _loadPageData() async {
    try {
      // DBに保存されたJSON文字列をデコードして利用
      final parsedTicket = json.decode(widget.qrData.parsedDataJson) as Map<String, dynamic>;

      // QRコード読み取り時にレース結果も保存されているはずなので、DBから取得を試みる
      final url = generateNetkeibaUrl(
        year: parsedTicket['年'].toString(),
        racecourseCode: racecourseDict.entries
            .firstWhere((entry) => entry.value == parsedTicket['開催場'])
            .key,
        round: parsedTicket['回'].toString(),
        day: parsedTicket['日'].toString(),
        race: parsedTicket['レース'].toString(),
      );
      final raceId = ScraperService.getRaceIdFromUrl(url)!;

      RaceResult? raceResult = await _dbHelper.getRaceResult(raceId);

      // 的中判定は行わない
      return PageData(
        parsedTicket: parsedTicket,
        raceResult: raceResult,
      );
    } catch (e) {
      print('ページデータの読み込みに失敗しました: $e');
      // エラーをスローしてFutureBuilderでハンドリング
      throw Exception('データの表示に失敗しました。');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('購入馬券の詳細'),
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

                return ListView(
                  padding: const EdgeInsets.all(8.0),
                  children: [
                    // 的中結果カードは削除
                    _buildUserTicketCard(parsedTicket),
                    if (raceResult != null) ...[
                      _buildRaceInfoCard(raceResult),
                      _buildFullResultsCard(raceResult),
                      _buildRefundsCard(raceResult),
                    ] else ...[
                      _buildNoRaceDataCard(),
                    ]
                  ],
                );
              }
              return const Center(child: Text('データがありません。'));
            },
          ),
        ],
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
            const Divider(height: 20),
            ...purchaseDetails.map((detail) {
              final combination = (detail['all_combinations'] as List?)
                  ?.map((c) => (c as List).join('-'))
                  .join(', ');
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${detail['式別']} (${detail['方式']}) - ${detail['購入金額']}円 x ${detail['組合せ数']}点',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    if(combination != null && combination.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                        child: Text(
                          '組み合わせ: $combination',
                          style: const TextStyle(fontSize: 14, color: Colors.black54),
                        ),
                      ),
                  ],
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
                    DataCell(Text(horse.horseNumber)),
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
  Widget _buildRefundsCard(RaceResult raceResult) {
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
                          return Text(
                            '${payout.combination} : ${payout.amount}円 (${payout.popularity}人気)',
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
