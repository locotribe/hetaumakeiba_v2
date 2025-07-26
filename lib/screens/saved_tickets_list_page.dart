// lib/screens/saved_tickets_list_page.dart
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/models/qr_data_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart'; // ★追加
import 'package:hetaumakeiba_v2/logic/parse.dart';
import 'package:hetaumakeiba_v2/screens/saved_ticket_detail_page.dart';
import 'package:hetaumakeiba_v2/services/scraper_service.dart'; // ★追加
import 'package:hetaumakeiba_v2/utils/url_generator.dart'; // ★追加
import 'package:hetaumakeiba_v2/widgets/custom_background.dart';

// ★追加：リストに表示する情報をまとめるためのヘルパークラス
class TicketListItem {
  final QrData qrData;
  final Map<String, dynamic> parsedTicket; // QRを簡易解析したデータ
  final RaceResult? raceResult; // DBから取得したレース結果（存在しない場合もある）

  TicketListItem({
    required this.qrData,
    required this.parsedTicket,
    this.raceResult,
  });
}

class SavedTicketsListPage extends StatefulWidget {
  const SavedTicketsListPage({super.key});

  @override
  State<SavedTicketsListPage> createState() => SavedTicketsListPageState();
}

class SavedTicketsListPageState extends State<SavedTicketsListPage> {
  // ★修正：保持するデータの型を変更
  List<TicketListItem> _ticketListItems = [];
  bool _isLoading = true; // ★追加：ロード中の状態を管理
  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    loadData();
  }

  // ★★★★★ 修正箇所：リスト表示用のデータを準備するロジックを全面的に改修 ★★★★★
  Future<void> loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    final allQrData = await _dbHelper.getAllQrData();
    final List<TicketListItem> items = [];

    for (final qrData in allQrData) {
      try {
        // QRコードを解析して、レースIDの元になる情報を取得
        final parsedTicket = parseHorseracingTicketQr(qrData.qrCode);

        // URLとレースIDを生成
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

        // DBからレース結果を取得（なければnull）
        final raceResult = await _dbHelper.getRaceResult(raceId);

        items.add(TicketListItem(
          qrData: qrData,
          parsedTicket: parsedTicket,
          raceResult: raceResult,
        ));
      } catch (e) {
        print('購入履歴の解析中にエラーが発生しました: ${qrData.id} - $e');
        // 解析エラーが発生した項目はリストに追加しない、などのハンドリングも可能
      }
    }

    if (mounted) {
      setState(() {
        _ticketListItems = items;
        _isLoading = false;
      });
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
      await _dbHelper.deleteAllQrData();
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
                  // ★★★★★ 修正箇所：ListView.builderの表示ロジックを刷新 ★★★★★
                      : ListView.builder(
                    itemCount: _ticketListItems.length,
                    itemBuilder: (context, index) {
                      final item = _ticketListItems[index];

                      String title;
                      String subtitle;

                      // DBにレース結果があれば、その情報を表示
                      if (item.raceResult != null) {
                        title = item.raceResult!.raceTitle;
                        subtitle = item.raceResult!.raceDate;
                      } else {
                        // なければ、QRの解析情報から簡易的な表示を作成
                        final venue = item.parsedTicket['開催場'] ?? '不明';
                        final raceNum = item.parsedTicket['レース'] ?? '??';
                        title = '$venue ${raceNum}R';
                        subtitle = 'タップしてレース結果を取得';
                      }

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        elevation: 2.0,
                        child: ListTile(
                          title: Text(
                            title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(subtitle),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteQrData(item.qrData.id!),
                          ),
                          onTap: () async {
                            // 詳細ページに遷移し、戻ってきたらリストを更新
                            await Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => SavedTicketDetailPage(qrData: item.qrData)),
                            );
                            loadData(); // 戻ってきたときに再読み込み
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
