// lib/main.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hetaumakeiba_v2/screens/qr_scanner_page.dart';
import 'package:hetaumakeiba_v2/screens/result_page.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/models/qr_data_model.dart';

// CustomBackgroundウィジェットをインポート
import 'package:hetaumakeiba_v2/widgets/custom_background.dart';
// parse.dart をインポート
import 'package:hetaumakeiba_v2/logic/parse.dart'; // この行を追加しました！

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const MyHomePage(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale("ja", "JP")],
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.green,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
        ),
        textTheme: const TextTheme(bodyMedium: TextStyle(color: Colors.white)),
        colorScheme: const ColorScheme.dark(primary: Colors.green),
      ),
      themeMode: ThemeMode.system,
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Map<String, dynamic>? parsedResult;
  List<QrData> _qrDataList = [];
  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _loadQrData();
  }

  Future<void> _loadQrData() async {
    final data = await _dbHelper.getAllQrData();
    setState(() {
      _qrDataList = data;
    });
  }

  void _openQRScanner() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const QRScannerPage()),
    );
    if (result != null) {
      await _loadQrData();
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ResultPage(parsedResult: result)),
      );
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
      await _loadQrData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('データが削除されました。')),
      );
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
      await _loadQrData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('すべてのデータが削除されました。')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("馬券QRリーダー")),
      backgroundColor: Colors.transparent,
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
                    onPressed: _openQRScanner,
                    child: const Text("QRコード読み取り"),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _deleteAllData,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text("全データを削除", style: TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(height: 16),
                  const Text('保存されたQRコードデータ:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  Expanded(
                    child: _qrDataList.isEmpty
                        ? const Center(
                      child: Text(
                        'まだ読み込まれたQRコードはありません。',
                        style: TextStyle(color: Colors.black54),
                      ),
                    )
                        : ListView.builder(
                      itemCount: _qrDataList.length,
                      itemBuilder: (context, index) {
                        final qrData = _qrDataList[index];
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
                              // parseHorseracingTicketQr 関数を呼び出す際に、
                              // その関数が定義されているファイル (logic/parse.dart) をインポートする必要がある
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
        ],
      ),
    );
  }
}