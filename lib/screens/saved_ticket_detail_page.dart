// lib/screens/saved_ticket_detail_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/logic/hit_checker.dart';
import 'package:hetaumakeiba_v2/logic/parse.dart';
import 'package:hetaumakeiba_v2/models/qr_data_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/services/scraper_service.dart';
import 'package:hetaumakeiba_v2/utils/url_generator.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart';

// ページのロードに必要なデータをまとめるためのヘルパークラス
class PageData {
  final Map<String, dynamic> parsedTicket;
  final RaceResult raceResult;
  final HitResult hitResult;

  PageData({
    required this.parsedTicket,
    required this.raceResult,
    required this.hitResult,
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

  Future<PageData> _loadPageData() async {
    try {
      // DBに保存されたJSON文字列をデコードして利用
      final parsedTicket = json.decode(widget.qrData.parsedDataJson) as Map<String, dynamic>;

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

      if (raceResult == null) {
        print('DBにデータがないため、スクレイピングを実行します: $url');
        raceResult = await ScraperService.scrapeRaceDetails(url);
        await _dbHelper.insertOrUpdateRaceResult(raceResult);
        print('スクレイピング結果をDBに保存しました。');
      } else {
        print('DBからレース結果を読み込みました。');
      }

      final hitResult = HitChecker.check(
        parsedTicket: parsedTicket,
        raceResult: raceResult,
      );

      return PageData(
        parsedTicket: parsedTicket,
        raceResult: raceResult,
        hitResult: hitResult,
      );
    } catch (e) {
      print('ページデータの読み込みに失敗しました: $e');
      throw Exception('レース結果の取得に失敗しました。\n時間をおいて再度お試しください。');
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
          Positioned.fill(
            child: CustomBackground(
              overallBackgroundColor: const Color.fromRGBO(231, 234, 234, 1.0),
              stripeColor: const Color.fromRGBO(219, 234, 234, 0.6),
              fillColor: const Color.fromRGBO(172, 234, 231, 1.0),
            ),
          ),
          FutureBuilder<PageData>(
            future: _pageDataFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('レース結果を取得・判定中...'),
                    ],
                  ),
                );
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
                final raceResult = pageData.raceResult;
                final parsedTicket = pageData.parsedTicket;
                final hitResult = pageData.hitResult;

                return ListView(
                  padding: const EdgeInsets.all(8.0),
                  children: [
                    _buildHitResultCard(hitResult),
                    _buildRaceInfoCard(raceResult),
                    _buildUserTicketCard(parsedTicket),
                    _buildFullResultsCard(raceResult),
                    _buildRefundsCard(raceResult),
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

  /// 的中結果を表示するカード
  Widget _buildHitResultCard(HitResult hitResult) {
    final bool isHit = hitResult.isHit;
    final Color cardColor = isHit ? Colors.green.shade50 : Colors.grey.shade200;
    final Color textColor = isHit ? Colors.green.shade800 : Colors.black87;

    return Card(
      elevation: 4,
      color: cardColor,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              isHit ? '🎉 的中！ 🎉' : 'はずれ',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            if (isHit) ...[
              const SizedBox(height: 16),
              Text(
                '総払戻金額',
                style: TextStyle(fontSize: 16, color: textColor),
              ),
              Text(
                '${hitResult.totalPayout} 円',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const Divider(height: 24),
              const Text(
                '的中内容',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...hitResult.hitDetails.map((detail) => Text(detail)),
            ],
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

  // ユーザーの購入内容カード
  Widget _buildUserTicketCard(Map<String, dynamic> parsedTicket) {
    final purchaseDetails = parsedTicket['購入内容'] as List;
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
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  '${detail['式別']} ${detail['馬番']} - ${detail['購入金額']}円',
                  style: const TextStyle(fontSize: 16),
                ),
              );
            }).toList(),
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