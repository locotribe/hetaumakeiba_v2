// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'dart:io';
import 'dart:convert'; // JsonEncoder を使用するために追加

import 'package:hetaumakeiba_v2/screens/home_page.dart';
import 'package:hetaumakeiba_v2/screens/saved_tickets_list_page.dart';
import 'package:hetaumakeiba_v2/screens/qr_scanner_page.dart';
import 'package:hetaumakeiba_v2/screens/gallery_qr_scanner_page.dart';
import 'package:hetaumakeiba_v2/screens/result_page.dart';
import 'package:hetaumakeiba_v2/screens/saved_ticket_detail_page.dart';
import 'package:hetaumakeiba_v2/models/qr_data_model.dart';

// parse.dart をインポート
import 'package:hetaumakeiba_v2/logic/parse.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = await openDatabase(
    join(await getDatabasesPath(), 'ticket_database.db'),
    onCreate: (db, version) {
      return db.execute(
        'CREATE TABLE qr_data(id INTEGER PRIMARY KEY AUTOINCREMENT, qr_code TEXT, timestamp TEXT)',
      );
    },
    version: 1,
  );

  // デバッグ用: 問題のQRコード文字列を直接解析するテスト関数を呼び出す
//    testParsing();

  runApp(MyApp(database: database));
}

class MyApp extends StatefulWidget {
  final Database database;
  const MyApp({super.key, required this.database});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<SavedTicketsListPageState> _savedListKey =
  GlobalKey<SavedTicketsListPageState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'へたうま競馬',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color.fromRGBO(172, 234, 231, 1.0),
          foregroundColor: Colors.black87,
          elevation: 0,
        ),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ja', ''),
      ],
      home: HomePage(savedListKey: _savedListKey),
    );
  }
}

// デバッグ用のテスト関数

//  void testParsing() {
  // 問題のQRコード文字列をここに貼り付け
//    String testQrCode = "3050002404041120086036384286030330013355486100000010000000000000000000000000000000010101000100000000005456789012345678901234567890123456789012345678901234567890123456789012345678901234560510";
//
//   print('TEST_PARSING: Starting parseHorseracingTicketQr with: $testQrCode');
//   try {
//      Map<String, dynamic> parsedData = parseHorseracingTicketQr(testQrCode);
//      print('TEST_PARSING: Parsed Data:');
    // JsonEncoderを使って整形して表示すると見やすいです
//      print(JsonEncoder.withIndent('  ').convert(parsedData));
// ここから組み合わせ数のプリントを追加
// print('\nTEST_PARSING: Combination Counts:');

// クイックピックの場合の「組合せ数」
// if (parsedData.containsKey('式別') && parsedData['式別'] == 'クイックピック') {
// if (parsedData.containsKey('組合せ数')) {
// print('  Overall (クイックピック) 組合せ数: ${parsedData['組合せ数']}');
// }
// }

// 各購入内容の「組み合わせ数」または「組合せ数」
// if (parsedData.containsKey('購入内容') && parsedData['購入内容'] is List) {
// List<dynamic> purchaseContents = parsedData['購入内容'];
// for (int i = 0; i < purchaseContents.length; i++) {
// var detail = purchaseContents[i];
// if (detail is Map<String, dynamic>) {
// String shikibetsu = detail['式別'] ?? '不明な式別';
// if (detail.containsKey('組み合わせ数')) {
// print('  購入内容 ${i + 1} (${shikibetsu}) 組み合わせ数: ${detail['組み合わせ数']}');
// } else if (detail.containsKey('組合せ数')) { // 念のため「組合せ数」も確認
// print('  購入内容 ${i + 1} (${shikibetsu}) 組合せ数: ${detail['組合せ数']}');
// } else {
// print('  購入内容 ${i + 1} (${shikibetsu}) 組み合わせ数情報なし');
// }
// }
// }
// }
// ここまで組み合わせ数のプリントを追加

//    } catch (e) {
//      print('TEST_PARSING: Parsing Error: $e');
//      if (e is StateError) {
//        print('TEST_PARSING: StateError details: ${e.message}');
//      } else if (e is ArgumentError) {
//        print('TEST_PARSING: ArgumentError details: ${e.message}');
//      } else if (e is RangeError) {
//        print('TEST_PARSING: RangeError details: ${e.message}');
//      }
//    }
//    print('TEST_PARSING: Finished parseHorseracingTicketQr test.');
//  }
