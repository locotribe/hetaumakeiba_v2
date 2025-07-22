import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:hetaumakeiba_v2/screens/qr_scanner_page.dart';
import 'package:hetaumakeiba_v2/screens/gallery_qr_scanner_page.dart';
import 'package:hetaumakeiba_v2/screens/saved_tickets_list_page.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart';
import 'package:hetaumakeiba_v2/widgets/app_styles.dart';
import 'package:hetaumakeiba_v2/widgets/race_info_display.dart';
import 'package:hetaumakeiba_v2/widgets/bet_type_display.dart';
import 'package:hetaumakeiba_v2/widgets/purchase_method_display.dart';
import 'package:hetaumakeiba_v2/widgets/purchase_details_summary.dart';
import 'package:hetaumakeiba_v2/widgets/sales_location_display.dart';

class ResultPage extends StatefulWidget {
  final Map<String, dynamic>? parsedResult;
  final GlobalKey<SavedTicketsListPageState> savedListKey;

  const ResultPage({
    super.key,
    this.parsedResult,
    required this.savedListKey,
  });

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  Map<String, dynamic>? _parsedResult;

  @override
  void initState() {
    super.initState();
    _parsedResult = widget.parsedResult;
  }

  @override
  void didUpdateWidget(covariant ResultPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.parsedResult != oldWidget.parsedResult) {
      setState(() {
        _parsedResult = widget.parsedResult;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String displayMessage;
    bool isErrorOrNotTicket = false;

    if (_parsedResult == null) {
      displayMessage = '馬券の読み取りに失敗しました';
      isErrorOrNotTicket = true;
    } else if (_parsedResult!.containsKey('isNotTicket') && _parsedResult!['isNotTicket'] == true) {
      displayMessage = '馬券ではありませんでした';
      isErrorOrNotTicket = true;
    } else if (_parsedResult!.containsKey('エラー')) {
      displayMessage = 'エラー: ${_parsedResult!['エラー']}\n詳細: ${_parsedResult!['詳細']}';
      isErrorOrNotTicket = true;
    } else {
      displayMessage = JsonEncoder.withIndent('  ').convert(_parsedResult);
    }

    String? salesLocation;
    if (_parsedResult != null && _parsedResult!.containsKey('発売所')) {
      salesLocation = _parsedResult!['発売所'] as String;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('解析結果'),
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
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: isErrorOrNotTicket
                        ? Center(
                      child: Text(
                        displayMessage,
                        style: _parsedResult != null && _parsedResult!.containsKey('エラー')
                            ? AppStyles.errorMessageStyle
                            : AppStyles.normalMessageStyle,
                        textAlign: TextAlign.center,
                      ),
                    )
                        : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RaceInfoDisplay(parsedResult: _parsedResult!),
                        const SizedBox(height: 8),
                        if (_parsedResult!.containsKey('式別'))
                          BetTypeDisplay(betType: _parsedResult!['式別']),
                        const SizedBox(height: 8),
                        PurchaseMethodDisplay(parsedResult: _parsedResult!),
                        const SizedBox(height: 8),
                        if (_parsedResult!.containsKey('購入内容'))
                          PurchaseDetailsSummary(
                            parsedResult: _parsedResult!,
                            betType: _parsedResult!['式別'] ?? '',
                          ),
                        if (salesLocation != null && salesLocation!.isNotEmpty)
                          SalesLocationDisplay(salesLocation: salesLocation!),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30.0),
                child: Column(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => QRScannerPage(
                              scanMethod: 'camera',
                              savedListKey: widget.savedListKey,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                        textStyle: const TextStyle(fontSize: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('続けてカメラで登録'),
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => GalleryQrScannerPage(
                              scanMethod: 'gallery',
                              savedListKey: widget.savedListKey,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                        textStyle: const TextStyle(fontSize: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        backgroundColor: Colors.blueGrey,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('ギャラリーから登録'),
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                        textStyle: const TextStyle(fontSize: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('ホームに戻る'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
