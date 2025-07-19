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
//   testParsing();

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
// void testParsing() {
  // 問題のQRコード文字列をここに貼り付け
//   String testQrCode = "5070001903070500336919478614070700051359887091100000109120902000019120906000019120910000019120911000010000123456789012345678901234567890123456789012345678901234567890123456789012345678960635";
//
//  print('TEST_PARSING: Starting parseHorseracingTicketQr with: $testQrCode');
//  try {
//     Map<String, dynamic> parsedData = parseHorseracingTicketQr(testQrCode);
//     print('TEST_PARSING: Parsed Data:');
    // JsonEncoderを使って整形して表示すると見やすいです
//     print(JsonEncoder.withIndent('  ').convert(parsedData));
//   } catch (e) {
//     print('TEST_PARSING: Parsing Error: $e');
//     if (e is StateError) {
//       print('TEST_PARSING: StateError details: ${e.message}');
//     } else if (e is ArgumentError) {
//       print('TEST_PARSING: ArgumentError details: ${e.message}');
//     } else if (e is RangeError) {
//       print('TEST_PARSING: RangeError details: ${e.message}');
//     }
//   }
//   print('TEST_PARSING: Finished parseHorseracingTicketQr test.');
// }
