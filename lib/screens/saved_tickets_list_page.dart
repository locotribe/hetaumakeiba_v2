// lib/screens/saved_tickets_list_page.dart
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/models/qr_data_model.dart';
import 'package:hetaumakeiba_v2/logic/parse.dart';
import 'package:hetaumakeiba_v2/screens/result_page.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart'; // 背景もここで管理

// クラス名を SavedTicketsListPage に変更
class SavedTicketsListPage extends StatefulWidget {
  const SavedTicketsListPage({super.key});

  @override
  // Stateクラスの名前も SavedTicketsListPageState に変更
  State<SavedTicketsListPage> createState() => SavedTicketsListPageState();
}

// Stateクラスの名前も SavedTicketsListPageState に変更
class SavedTicketsListPageState extends State<SavedTicketsListPage> {
  List<QrData> _qrDataList = [];
  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    loadData(); // 初期ロード
  }

  // データをロードする公開メソッド
  Future<void> loadData() async {
    print('DEBUG: SavedTicketsListPage: loadData called');
    final data = await _dbHelper.getAllQrData();
    print('DEBUG: SavedTicketsListPage: Loaded ${data.length} QR data items.');
    setState(() {
      _qrDataList = data;
    });
  }

  // 個別のQRデータを削除する
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
      await loadData(); // 削除後にデータを再ロード
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('データが削除されました。')),
      );
    }
  }

  // 全データを削除する
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
      await loadData(); // 削除後にデータを再ロード
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('すべてのデータが削除されました。')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    print('DEBUG: SavedTicketsListPage: build called. _qrDataList.length: ${_qrDataList.length}');
    return Scaffold( // Scaffoldを追加して独立したページにする
      appBar: AppBar(
        title: const Text('保存された馬券'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
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
    Positioned.fill(
    child: Padding(
    padding: const EdgeInsets.all(16.0),
    child: Column(
    children: [
    ElevatedButton(
    onPressed: _deleteAllData,
    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
    child: const Text("全データを削除", style: TextStyle(color: Colors.white)),
    ),
    const SizedBox(height: 16),
    const Text('保存された馬券:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
    Expanded(
    child: _qrDataList.isEmpty
    ? const Center(
    child: Text(
    'まだ読み込まれた馬券はありません。',
    style: TextStyle(color: Colors.black54),
    ),
    )
        : ListView.builder(
    itemCount: _qrDataList.length,
    itemBuilder: (context, index) {
    final qrData = _qrDataList[index];
    print('DEBUG: SavedTicketsListPage: Rendering QR Data: ${qrData.qrCode}');
    return Card(
    margin: const EdgeInsets.symmetric(vertical: 8.0),
    elevation: 2.0,
    child: ListTile(
    title: Text(
    qrData.qrCode.length > 50
    ? '${qrData.qrCode.substring(0, 50)}...'
        : qrData.qrCode,
    style: const TextStyle(fontWeight: FontWeight.bold),
    ),
    subtitle: Text(
    '読み込み日時: ${qrData.timestamp.toLocal().toString().split('.')[0]}',
    ),
    trailing: IconButton(
    icon: const Icon(Icons.delete, color: Colors.red),
    onPressed: () => _deleteQrData(qrData.id!),
    ),
    onTap: () async {
    final result = parseHorseracingTicketQr(qrData.qrCode);
    Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => ResultPage(parsedResult: result)),
    );
    },
    ),
    );
    },
    ),
    ),
    ],
    ),
    ),
    ),
    ], // ここに閉じ括弧を追加しました
    )
    );
  }
}
