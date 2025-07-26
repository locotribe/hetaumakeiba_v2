// lib/screens/saved_tickets_list_page.dart
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/models/qr_data_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/logic/parse.dart';
import 'package:hetaumakeiba_v2/screens/saved_ticket_detail_page.dart';
import 'package:hetaumakeiba_v2/services/scraper_service.dart';
import 'package:hetaumakeiba_v2/utils/url_generator.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart';

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

  Future<void> loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    final allQrData = await _dbHelper.getAllQrData();
    final List<TicketListItem> tempItems = [];

    for (final qrData in allQrData) {
      try {
        final parsedTicket = parseHorseracingTicketQr(qrData.qrCode);
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
        print('購入履歴の解析中にエラーが発生しました: ${qrData.id} - $e');
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
      String subtitle;

      if (item.raceResult != null) {
        title = item.raceResult!.raceTitle;
        subtitle = item.raceResult!.raceDate;
      } else {
        final venue = item.parsedTicket['開催場'] ?? '不明';
        final raceNum = item.parsedTicket['レース'] ?? '??';
        title = '$venue ${raceNum}R';
        subtitle = 'タップしてレース結果を取得';
      }

      final purchaseMethod = item.parsedTicket['方式'] ?? '';
      final purchaseDetails = (item.parsedTicket['購入内容'] as List)
          .map((p) => p['式別'])
          .where((p) => p != null)
          .join(', ');

      subtitle += ' / $purchaseDetails $purchaseMethod';

      final key = _generatePurchaseKey(item.parsedTicket);
      if (duplicateCounter[key]! > 1) {
        final index = (currentDuplicateIndex[key] ?? 0) + 1;
        subtitle += ' ($index)';
        currentDuplicateIndex[key] = index;
      }

      finalItems.add(TicketListItem(
        qrData: item.qrData,
        parsedTicket: item.parsedTicket,
        raceResult: item.raceResult,
        displayTitle: title,
        displaySubtitle: subtitle,
      ));
    }

    if (mounted) {
      setState(() {
        _ticketListItems = finalItems.reversed.toList(); // ★修正：新しいものが上に来るようにリストを逆順にする
        _isLoading = false;
      });
    }
  }

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
      return parsedTicket['QR'] ?? DateTime.now().toIso8601String();
    }
  }

  void _deleteQrData(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('データ削除'),
        content: const Text('このデータを削除しますか？'),
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
      await _dbHelper.deleteQrData(id);
      await loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('データが削除されました。')),
        );
      }
    }
  }

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
      // ★★★★★ 修正箇所：新しい全削除メソッドを呼び出す ★★★★★
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

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        elevation: 2.0,
                        child: ListTile(
                          title: Text(
                            item.displayTitle,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(item.displaySubtitle),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteQrData(item.qrData.id!),
                          ),
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => SavedTicketDetailPage(qrData: item.qrData)),
                            );
                            loadData();
                          },
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
