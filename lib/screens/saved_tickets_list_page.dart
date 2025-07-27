// lib/screens/saved_tickets_list_page.dart
import 'dart:convert'; // JSONのデコードに必要
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/models/qr_data_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/logic/parse.dart'; // racecourseDictを利用するためにインポート
import 'package:hetaumakeiba_v2/screens/saved_ticket_detail_page.dart';
import 'package:hetaumakeiba_v2/services/scraper_service.dart';
import 'package:hetaumakeiba_v2/utils/url_generator.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart';

// リストアイテムのデータを保持するためのヘルパークラス
class TicketListItem {
  final QrData qrData;
  final Map<String, dynamic> parsedTicket;
  final RaceResult? raceResult;
  final String displayTitle;
  final String displaySubtitle;

  TicketListItem({
    required this.qrData,
    required this.parsedTicket,
    this.raceResult,
    required this.displayTitle,
    required this.displaySubtitle,
  });
}

class SavedTicketsListPage extends StatefulWidget {
  const SavedTicketsListPage({super.key});

  @override
  State<SavedTicketsListPage> createState() => SavedTicketsListPageState();
}

class SavedTicketsListPageState extends State<SavedTicketsListPage> {
  List<TicketListItem> _ticketListItems = [];
  bool _isLoading = true;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    loadData();
  }

  /// データベースからデータを読み込み、リスト表示用に整形する
  Future<void> loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    final allQrData = await _dbHelper.getAllQrData();
    final List<TicketListItem> tempItems = [];

    for (final qrData in allQrData) {
      try {
        final parsedTicket = jsonDecode(qrData.parsedDataJson) as Map<String, dynamic>;

        if (parsedTicket.isEmpty) {
          print('解析済みデータが空です: ${qrData.id}');
          continue;
        }

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
        final raceResult = await _dbHelper.getRaceResult(raceId);

        tempItems.add(TicketListItem(
          qrData: qrData,
          parsedTicket: parsedTicket,
          raceResult: raceResult,
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
      String line2; // 2行目
      String line3; // 3行目

      if (item.raceResult != null) {
        title = item.raceResult!.raceTitle;
        line2 = item.raceResult!.raceDate;
      } else {
        final venue = item.parsedTicket['開催場'] ?? '不明';
        final raceNum = item.parsedTicket['レース'] ?? '??';
        title = '$venue ${raceNum}R';
        line2 = 'タップしてレース結果を取得';
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
          .map((p) => p['式別'])
          .where((p) => p != null)
          .toSet()
          .join(', ');

      line2 += ' / $purchaseDetails $purchaseMethodDisplay';

      final key = _generatePurchaseKey(item.parsedTicket);
      if (duplicateCounter[key]! > 1) {
        final index = (currentDuplicateIndex[key] ?? 0) + 1;
        line2 += ' ($index)';
        currentDuplicateIndex[key] = index;
      }

      line3 = _formatPurchaseSummary(item.parsedTicket['購入内容'] as List<dynamic>);

      final combinedSubtitle = '$line2\n$line3';

      finalItems.add(TicketListItem(
        qrData: item.qrData,
        parsedTicket: item.parsedTicket,
        raceResult: item.raceResult,
        displayTitle: title,
        displaySubtitle: combinedSubtitle,
      ));
    }

    if (mounted) {
      setState(() {
        _ticketListItems = finalItems;
        _isLoading = false;
      });
    }
  }

  /// 購入内容のリストから、表示用の概要文字列を生成する
  String _formatPurchaseSummary(List<dynamic> purchases) {
    if (purchases.isEmpty) return '';

    try {
      final firstPurchase = purchases.first as Map<String, dynamic>;
      final ticketType = firstPurchase['式別'] ?? '';
      final amount = firstPurchase['購入金額'] ?? 0;
      String horseNumbersStr = '';

      if (firstPurchase.containsKey('馬番')) {
        final horseNumbers = firstPurchase['馬番'];
        if (horseNumbers is List && horseNumbers.isNotEmpty) {
          if (horseNumbers.first is List) {
            final listOfLists = horseNumbers.map((e) => (e as List).map((num) => num.toString()).toList()).toList();
            horseNumbersStr = listOfLists
                .map((group) => group.join(','))
                .join(' → ');
          }
          else {
            final simpleList = horseNumbers.map((e) => e.toString()).toList();
            horseNumbersStr = simpleList.join(',');
          }
        }
      }
      else if (firstPurchase.containsKey('軸')) {
        final axis = firstPurchase['軸'];
        final opponents = firstPurchase['相手'];

        final axisList = (axis is List) ? axis.map((e) => e.toString()).toList() : [axis.toString()];
        final opponentsList = (opponents is List) ? opponents.map((e) => e.toString()).toList() : [opponents.toString()];

        horseNumbersStr = '軸:${axisList.join(',')} 相手:${opponentsList.join(',')}';
      }

      String summary = '$ticketType: $horseNumbersStr / ${amount}円';
      if (purchases.length > 1) {
        summary += ' ...他';
      }
      return summary;
    } catch (e) {
      print('Error in _formatPurchaseSummary: $e');
      return '購入内容の表示に失敗しました';
    }
  }


  /// 購入内容から一意のキーを生成する
  String _generatePurchaseKey(Map<String, dynamic> parsedTicket) {
    try {
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

      final purchaseMethod = parsedTicket['方式'] ?? '';
      final purchaseDetails = (parsedTicket['購入内容'] as List);

      final detailsString = purchaseDetails.map((p) {
        final detailMap = p as Map<String, dynamic>;
        final sortedKeys = detailMap.keys.toList()..sort();
        return sortedKeys.map((key) => '$key:${detailMap[key]}').join(';');
      }).join('|');

      return '$raceId-$purchaseMethod-$detailsString';
    } catch (e) {
      final qrContent = parsedTicket['QR'] ?? parsedTicket.toString();
      return qrContent;
    }
  }

  /// 全データを削除する
  Future<void> _deleteAllData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('全データ削除'),
        content: const Text('本当にすべての保存データを削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _dbHelper.deleteAllData();
      await loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('すべてのデータが削除されました。')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('購入履歴'),
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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: _deleteAllData,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text("全データを削除", style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(height: 16),
                const Text('購入履歴:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : (_ticketListItems.isEmpty
                      ? const Center(
                    child: Text(
                      'まだ読み込まれた馬券はありません。',
                      style: TextStyle(color: Colors.black54),
                    ),
                  )
                      : ListView.builder(
                    itemCount: _ticketListItems.length,
                    itemBuilder: (context, index) {
                      final item = _ticketListItems[index];
                      final totalAmount = item.parsedTicket['合計金額'] as int? ?? 0;

                      return Dismissible(
                        key: ValueKey(item.qrData.id),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (direction) async {
                          return await showDialog<bool>(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: const Text('削除の確認'),
                                content: const Text('この項目を本当に削除しますか？'),
                                actions: <Widget>[
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(false),
                                    child: const Text('キャンセル'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(true),
                                    child: const Text('削除', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              );
                            },
                          ) ?? false;
                        },
                        onDismissed: (direction) async {
                          await _dbHelper.deleteQrData(item.qrData.id!);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('「${item.displayTitle}」を削除しました。')),
                            );
                            loadData();
                          }
                        },
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        child: Card(
                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                          elevation: 2.0,
                          child: ListTile(
                            isThreeLine: true,
                            title: Text(
                              item.displayTitle,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(item.displaySubtitle),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${totalAmount}円',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 16.0),
                                const SizedBox(height: 16.0),
                              ],
                            ),
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => SavedTicketDetailPage(qrData: item.qrData)),
                              );
                              loadData();
                            },
                          ),
                        ),
                      );
                    },
                  )),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
