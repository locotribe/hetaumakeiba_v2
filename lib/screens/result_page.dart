// lib/screens/result_page.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/screens/qr_scanner_page.dart';
import 'package:hetaumakeiba_v2/screens/gallery_qr_scanner_page.dart';
import 'package:hetaumakeiba_v2/screens/saved_tickets_list_page.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart';
import 'package:hetaumakeiba_v2/widgets/betting_ticket_card.dart';
import 'package:hetaumakeiba_v2/widgets/dual_betting_ticket_card.dart';
import 'package:hetaumakeiba_v2/logic/parse.dart';

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
              overallBackgroundColor: Color.fromRGBO(231, 234, 234, 1.0),
              stripeColor: Color.fromRGBO(219, 234, 234, 0.6),
              fillColor: Color.fromRGBO(172, 234, 231, 1.0),
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
                      : _buildTicketCard(_parsedResult!),
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

  Widget _buildTicketCard(Map<String, dynamic> ticketData) {
    Map<String, dynamic> activeTicketData = Map<String, dynamic>.from(ticketData);

    String foundQr = '';
    for (var entry in ticketData.entries) {
      if (entry.value is String && (entry.value as String).length >= 190) {
        foundQr = entry.value as String;
        break;
      }
    }
    if (foundQr.isNotEmpty) {
      try {
        activeTicketData = parseHorseracingTicketQr(foundQr);
      } catch (_) {}
    }

    List<dynamic> rawList = [];
    if (activeTicketData.containsKey('購入内容') && activeTicketData['購入内容'] is List) {
      rawList = activeTicketData['購入内容'] as List;
    } else if (activeTicketData.containsKey('purchase_details') && activeTicketData['purchase_details'] is List) {
      rawList = activeTicketData['purchase_details'] as List;
    } else if (activeTicketData.containsKey('purchaseDetails') && activeTicketData['purchaseDetails'] is List) {
      rawList = activeTicketData['purchaseDetails'] as List;
    }

    List<Map<String, dynamic>> purchaseDetails = [];
    for (var item in rawList) {
      if (item is Map) {
        purchaseDetails.add(Map<String, dynamic>.from(item));
      }
    }

    final String method = (activeTicketData['方式'] ?? '').toString();
    final bool isOuenBaken = (method == '応援馬券' || method == '5');

    final Set<String> shikibetsuTypes = {};
    for (var p in purchaseDetails) {
      final code = p['式別']?.toString() ?? '';
      if (code.isNotEmpty) {
        shikibetsuTypes.add(code);
      }
    }

    final bool isDual = !isOuenBaken && shikibetsuTypes.length >= 2;

    if (isDual) {
      return DualBettingTicketCard(ticketData: activeTicketData);
    } else {
      return BettingTicketCard(ticketData: activeTicketData);
    }
  }
}
