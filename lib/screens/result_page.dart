// lib/screens/result_page.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/screens/qr_scanner_page.dart';
import 'package:hetaumakeiba_v2/screens/gallery_qr_scanner_page.dart';
import 'package:hetaumakeiba_v2/screens/saved_tickets_list_page.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart';
import 'package:hetaumakeiba_v2/widgets/betting_ticket_card.dart';

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
    String displayMessage = '';
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
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('解析結果'),
      ),
      body: Stack(
        children: [
          const Positioned.fill(
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
                  child: isErrorOrNotTicket
                      ? Center(
                    child: Text(
                      displayMessage,
                      style: TextStyle(
                        fontSize: 16,
                        color: _parsedResult != null && _parsedResult!.containsKey('エラー') ? Colors.red : Colors.black54,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  )
                      : BettingTicketCard(ticketData: _parsedResult!),
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
