// lib/screens/qr_scanner_page.dart

import 'package:hetaumakeiba_v2/logic/parse.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/models/qr_data_model.dart';
import 'dart:ui' as ui; // BackdropFilterのために必要
import 'dart:convert'; // JsonEncoderのために必要

// CustomBackgroundウィジェットをインポート
import 'package:hetaumakeiba_v2/widgets/custom_background.dart';
import 'package:hetaumakeiba_v2/screens/saved_tickets_list_page.dart'; // SavedTicketsListPageState のキーのためにインポート

class QRScannerPage extends StatefulWidget {
  final String scanMethod; // スキャン方法を受け取るためのプロパティ
  final GlobalKey<SavedTicketsListPageState> savedListKey; // Keyを受け取る

  const QRScannerPage({
    super.key,
    this.scanMethod = 'unknown',
    required this.savedListKey, // コンストラクタに追加
  });

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> with WidgetsBindingObserver {
  final List<String> _qrResults = [];
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late MobileScannerController _scannerController;

  bool _isShowingDuplicateMessage = false; // 重複メッセージ表示状態
  bool _isScannerActive = false; // スキャナーがアクティブかどうかを追跡

  Map<String, dynamic>? _parsedResultForOverlay; // オーバーレイ表示用の解析結果
  bool _showResultOverlay = false; // 結果オーバーレイの表示状態

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAndStartScanner();
  }

  void _initializeAndStartScanner() {
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
    );
    // UIが完全に描画された後にスキャナーを開始
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isScannerActive) {
        _scannerController.start().then((_) {
          if (mounted) {
            setState(() {
              _isScannerActive = true;
            });
          }
        }).catchError((error) {
          print('Error starting scanner: $error');
          // エラーメッセージを表示するなどの処理
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopScanner(); // コントローラーを停止
    _scannerController.dispose(); // コントローラーを破棄
    super.dispose();
  }

  void _stopScanner() {
    if (_isScannerActive) {
      _scannerController.stop();
      if (mounted) {
        setState(() {
          _isScannerActive = false;
        });
      }
    }
  }

  void _startScanner() {
    if (mounted && !_isScannerActive) {
      _scannerController.start().then((_) {
        if (mounted) {
          setState(() {
            _isScannerActive = true;
          });
        }
      }).catchError((error) {
        print('Error starting scanner: $error');
        // エラーメッセージを表示するなどの処理
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startScanner();
    } else if (state == AppLifecycleState.paused) {
      _stopScanner();
    }
  }

  int _countSequence(String s) {
    const sequence = "0123456789";
    return RegExp(sequence).allMatches(s).length;
  }

  void _onDetect(BarcodeCapture capture) async {
    // メッセージ表示中または結果オーバーレイ表示中は新たな検出を無視
    if (_isShowingDuplicateMessage || _showResultOverlay) {
      return;
    }

    final List<String> detectedRawValues = capture.barcodes
        .map((b) => b.rawValue)
        .where((rv) => rv != null && rv.isNotEmpty)
        .cast<String>()
        .toList();

    for (final rawValue in detectedRawValues) {
      if (_qrResults.contains(rawValue)) {
        continue;
      }

      print('DEBUG: rawValue from scanner: $rawValue');

      final bool existsSingle = await _dbHelper.qrCodeExists(rawValue);
      if (existsSingle) {
        print('DEBUG: Duplicate single QR code detected (rawValue): $rawValue');
        setState(() {
          _isShowingDuplicateMessage = true;
        });
        _stopScanner();
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _isShowingDuplicateMessage = false;
            });
            _startScanner();
          }
        });
        return;
      }

      _qrResults.add(rawValue);

      if (_qrResults.length == 2) {
        String firstPart = _qrResults[0];
        String secondPart = _qrResults[1];

        String combinedQrCode;
        int count1 = _countSequence(firstPart);
        int count2 = _countSequence(secondPart);

        if (count1 > count2) {
          combinedQrCode = secondPart + firstPart;
        } else {
          combinedQrCode = firstPart + secondPart;
        }

        print('DEBUG: Combined QR string for duplicate check: $combinedQrCode');

        final bool existsCombined = await _dbHelper.qrCodeExists(combinedQrCode);
        if (existsCombined) {
          print('DEBUG: Duplicate QR code detected (combined): $combinedQrCode');
          setState(() {
            _isShowingDuplicateMessage = true;
            _qrResults.clear();
          });
          _stopScanner();
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() {
                _isShowingDuplicateMessage = false;
              });
              _startScanner();
            }
          });
          return;
        } else {
          _stopScanner();
          await _processTwoQRs(combinedQrCode); // await を追加
          _qrResults.clear();
          return;
        }
      }
    }
  }

  Future<void> _processTwoQRs(String qrCode) async { // Future<void> を明示
    Map<String, dynamic> parsedData;

    try {
      parsedData = parseHorseracingTicketQr(qrCode);
      if (parsedData['QR'] != null) {
        final qrDataToSave = QrData(
          qrCode: parsedData['QR'] as String,
          timestamp: DateTime.now(),
        );
        print('DEBUG: 馬券データが保存されました: ${qrDataToSave.qrCode}');
        await _dbHelper.insertQrData(qrDataToSave);
        print('馬券データが保存されました: ${qrDataToSave.qrCode}');

        widget.savedListKey.currentState?.loadData();
      }
    } catch (e) {
      parsedData = {'エラー': '解析に失敗しました', '詳細': e.toString()};
    }

    if (mounted) {
      setState(() {
        _parsedResultForOverlay = parsedData;
        _showResultOverlay = true;
      });
    }
  }

  void _hideResultOverlayAndResumeScanner() {
    setState(() {
      _showResultOverlay = false;
      _parsedResultForOverlay = null;
      _qrResults.clear();
    });
    _startScanner();
  }

  // ResultPageから移動したヘルパーメソッド群
  String _getStars(int amount) {
    String amountStr = amount.toString();
    int numDigits = amountStr.length;
    if (numDigits >= 6) {
      return '';
    } else if (numDigits == 5) {
      return '☆';
    } else if (numDigits == 4) {
      return '☆☆';
    } else if (numDigits == 3) {
      return '☆☆☆';
    }
    return '';
  }

  String _getHorseNumberSymbol(String shikibetsu, String betType) {
    if (betType == '通常') {
      if (shikibetsu == '馬単' || shikibetsu == '3連単') {
        return '→';
      } else if (shikibetsu == '馬連' || shikibetsu == '3連複' || shikibetsu == '枠連') {
        return '-';
      } else if (shikibetsu == 'ワイド') {
        return '◆';
      }
    }
    return '';
  }

  List<Widget> _buildHorseNumberDisplay(List<int> horseNumbers, {String symbol = ''}) {
    List<Widget> widgets = [];
    const double fixedWidth = 30.0;

    for (int i = 0; i < horseNumbers.length; i++) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0),
          child: Container(
            width: fixedWidth,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black54),
              borderRadius: BorderRadius.circular(4.0),
            ),
            child: Text(
              horseNumbers[i].toString(),
              style: TextStyle(color: Colors.black54),
            ),
          ),
        ),
      );
      if (symbol.isNotEmpty && i < horseNumbers.length - 1) {
        widgets.add(
          Text(symbol, style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
        );
      }
    }
    return widgets;
  }

  List<Widget> _buildPurchaseDetails(dynamic purchaseData, String betType) {
    List<Map<String, dynamic>> purchaseDetails = (purchaseData as List).cast<Map<String, dynamic>>();

    const double labelWidth = 80.0;

    if (betType == '応援馬券' && purchaseDetails.length >= 2) {
      final firstDetail = purchaseDetails[0];
      List<int> umanbanList = (firstDetail['馬番'] as List).cast<int>();
      int kingaku = firstDetail['購入金額'] as int;

      return [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: labelWidth,
              child: Text(
                '馬番',
                style: TextStyle(color: Colors.black54),
                textAlign: TextAlign.end,
              ),
            ),
            Expanded(
              child: Wrap(
                children: [..._buildHorseNumberDisplay(umanbanList, symbol: '')],
              ),
            ),
          ],
        ),
        Text(
          '各${_getStars(kingaku)}${kingaku}円',
          style: TextStyle(color: Colors.black54),
        ),
        Text(
          '単勝 ${_getStars(kingaku)}${kingaku}円',
          style: TextStyle(color: Colors.black54),
        ),
        Text(
          '複勝 ${_getStars(kingaku)}${kingaku}円',
          style: TextStyle(color: Colors.black54),
        ),
      ];
    } else {
      return purchaseDetails.map((detail) {
        String shikibetsu = detail['式別'] ?? '';
        int? kingaku = detail['購入金額'];
        String kingakuDisplay = kingaku != null ? '${kingaku}円' : '';
        String uraDisplay = (detail['ウラ'] != null) ? 'ウラ: ${detail['ウラ']}' : '';

        List<Widget> detailWidgets = [];
        int combinations = 0;

        if (betType == 'ボックス') {
          List<int> horseNumbers = (detail['馬番'] as List).cast<int>();
          int n = horseNumbers.length;
          if (shikibetsu == '馬連' || shikibetsu == '馬単') {
            combinations = n * (n - 1) ~/ (shikibetsu == '馬連' ? 2 : 1);
          } else if (shikibetsu == '3連複') {
            combinations = n * (n - 1) * (n - 2) ~/ 6;
          } else if (shikibetsu == '3連単') {
            combinations = n * (n - 1) * (n - 2);
          }
        } else if (betType == 'フォーメーション') {
          List<List<int>> horseGroups = (detail['馬番'] as List).cast<List<int>>();
          if (shikibetsu == '3連単') {
            if (horseGroups.length >= 3) {
              combinations = horseGroups[0].length * horseGroups[1].length * horseGroups[2].length;
            }
          } else if (shikibetsu == '3連複') {
            if (horseGroups.length >= 3) {
              combinations = horseGroups[0].length * horseGroups[1].length * horseGroups[2].length;
            }
          }
        } else if (betType == 'ながし') {
          int axisCount = 0;
          if (detail.containsKey('軸') && detail['軸'] is List) {
            axisCount = (detail['軸'] as List).length;
          } else if (detail.containsKey('軸') && detail['軸'] != null) {
            axisCount = 1;
          }

          int opponentCount = 0;
          if (detail.containsKey('相手') && detail['相手'] is List) {
            opponentCount = (detail['相手'] as List).length;
          }
          combinations = axisCount * opponentCount;
        }

        bool isComplexCombinationForPrefix =
            (detail['式別'] == '3連単' && detail['馬番'] is List && (detail['馬番'] as List).isNotEmpty && (detail['馬番'] as List)[0] is List) ||
                detail.containsKey('ながし') ||
                (betType == 'ボックス');

        String prefixForAmount = '';
        if (kingaku != null) {
          if (isComplexCombinationForPrefix) {
            prefixForAmount = '各組${_getStars(kingaku)}';
          } else {
            prefixForAmount = '${_getStars(kingaku)}';
          }
        }

        if (combinations > 0) {
          detailWidgets.add(
            Text(
              '組合せ数 $combinations',
              style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold),
            ),
          );
        }

        bool amountHandledInline = false;

        if (detail['式別'] == '3連単' && detail['馬番'] is List && (detail['馬番'] as List).isNotEmpty && (detail['馬番'] as List)[0] is List) {
          final List<List<int>> horseGroups = (detail['馬番'] as List).cast<List<int>>();
          if (horseGroups.length >= 1) {
            detailWidgets.add(Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: labelWidth, child: Text('1着', style: TextStyle(color: Colors.black54), textAlign: TextAlign.end)),
                  Expanded(child: Wrap(children: [..._buildHorseNumberDisplay(horseGroups[0], symbol: '')])),
                ],
              ),
            ));
          }
          if (horseGroups.length >= 2) {
            detailWidgets.add(Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: labelWidth, child: Text('2着', style: TextStyle(color: Colors.black54), textAlign: TextAlign.end)),
                  Expanded(child: Wrap(children: [..._buildHorseNumberDisplay(horseGroups[1], symbol: '')])),
                ],
              ),
            ));
          }
          if (horseGroups.length >= 3) {
            detailWidgets.add(Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: labelWidth, child: Text('3着', style: TextStyle(color: Colors.black54), textAlign: TextAlign.end)),
                  Expanded(child: Wrap(children: [..._buildHorseNumberDisplay(horseGroups[2], symbol: '')])),
                ],
              ),
            ));
          }
        } else if (detail.containsKey('ながし')) {
          if (detail.containsKey('軸')) {
            List<int> axisHorses = detail['軸'] is List ? (detail['軸'] as List).cast<int>() : [(detail['軸'] as int)];
            detailWidgets.add(Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: labelWidth, child: Text('軸', style: TextStyle(color: Colors.black54), textAlign: TextAlign.end)),
                  Expanded(child: Wrap(children: [..._buildHorseNumberDisplay(axisHorses, symbol: '')])),
                ],
              ),
            ));
          }
          if (detail.containsKey('相手') && detail['相手'] is List) {
            detailWidgets.add(Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: labelWidth, child: Text('相手', style: TextStyle(color: Colors.black54), textAlign: TextAlign.end)),
                  Expanded(child: Wrap(children: [..._buildHorseNumberDisplay((detail['相手'] as List).cast<int>(), symbol: '')])),
                ],
              ),
            ));
          }
        } else if (detail.containsKey('馬番') && detail['馬番'] is List && (detail['馬番'] as List).isNotEmpty && (detail['馬番'] as List)[0] is List) {
          List<List<int>> formationHorseNumbers = (detail['馬番'] as List).cast<List<int>>();
          for (int i = 0; i < formationHorseNumbers.length; i++) {
            detailWidgets.add(Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: labelWidth, child: Text('${i + 1}組', style: TextStyle(color: Colors.black54), textAlign: TextAlign.end)),
                  Expanded(child: Wrap(children: [..._buildHorseNumberDisplay(formationHorseNumbers[i], symbol: '')])),
                ],
              ),
            ));
          }
        } else if (detail.containsKey('馬番') && detail['馬番'] is List) {
          String currentSymbol = _getHorseNumberSymbol(shikibetsu, betType);

          if (!isComplexCombinationForPrefix) {
            detailWidgets.add(Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: labelWidth,
                    child: Text(
                      '馬番',
                      style: TextStyle(color: Colors.black54),
                      textAlign: TextAlign.end,
                    ),
                  ),
                  Expanded(
                    child: Wrap(
                      spacing: 4.0,
                      runSpacing: 4.0,
                      children: [
                        ..._buildHorseNumberDisplay((detail['馬番'] as List).cast<int>(), symbol: currentSymbol),
                        if (kingaku != null)
                          Text(
                            '$prefixForAmount$kingakuDisplay',
                            style: TextStyle(color: Colors.black54),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ));
            amountHandledInline = true;
          } else {
            detailWidgets.add(Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: labelWidth,
                    child: Text(
                      '馬番',
                      style: TextStyle(color: Colors.black54),
                      textAlign: TextAlign.end,
                    ),
                  ),
                  Expanded(
                    child: Wrap(
                      children: [..._buildHorseNumberDisplay((detail['馬番'] as List).cast<int>(), symbol: '')],
                    ),
                  ),
                ],
              ),
            ));
          }
        }

        if (kingaku != null && !amountHandledInline) {
          detailWidgets.add(Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Text('$prefixForAmount$kingakuDisplay', style: TextStyle(color: Colors.black54)),
          ));
        }

        if (uraDisplay.isNotEmpty) {
          detailWidgets.add(Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Text(uraDisplay, style: TextStyle(color: Colors.black54)),
          ));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: detailWidgets,
        );
      }).toList();
    }
  }

  // ResultPageのbuildメソッドの内容をウィジェットとして返す新しいメソッド
  Widget _buildResultContent(Map<String, dynamic>? parsedResult) {
    // parsedResult が null の場合のハンドリング
    final prettyJson = parsedResult != null
        ? JsonEncoder.withIndent('  ').convert(parsedResult)
        : '馬券の読み取りに失敗しました';

    int totalAmount = 0;
    if (parsedResult != null && parsedResult.containsKey('購入内容')) {
      List<Map<String, dynamic>> purchaseDetails = (parsedResult['購入内容'] as List).cast<Map<String, dynamic>>();
      for (var detail in purchaseDetails) {
        if (detail.containsKey('購入金額')) {
          totalAmount += (detail['購入金額'] as int);
        }
      }
    }

    String? salesLocation;
    if (parsedResult != null && parsedResult.containsKey('発売所')) {
      salesLocation = parsedResult['発売所'] as String;
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '読み込んだ馬券',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: parsedResult == null
                    ? Center(
                  child: Text(
                    prettyJson,
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                )
                    : (parsedResult.containsKey('エラー')
                    ? Text(
                  'エラー: ${parsedResult['エラー']}\n詳細: ${parsedResult['詳細']}',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.red,
                  ),
                )
                    : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (parsedResult.containsKey('年') && parsedResult.containsKey('回') && parsedResult.containsKey('日'))
                      Text(
                        '${parsedResult['年']}年${parsedResult['回']}回${parsedResult['日']}日',
                        style: TextStyle(color: Colors.black54, fontSize: 16),
                      ),
                    const SizedBox(height: 4),
                    if (parsedResult.containsKey('開催場') && parsedResult.containsKey('レース'))
                      Text(
                        '${parsedResult['開催場']}${parsedResult['レース']}レース',
                        style: TextStyle(color: Colors.black54, fontSize: 16),
                      ),
                    const SizedBox(height: 8),
                    if (parsedResult.containsKey('購入内容') && parsedResult.containsKey('方式'))
                      Builder(builder: (context) {
                        final List<Map<String, dynamic>> purchaseDetails =
                        (parsedResult['購入内容'] as List).cast<Map<String, dynamic>>();
                        String betType = parsedResult['方式'] ?? '';
                        String shikibetsu = '';
                        if (purchaseDetails.isNotEmpty && purchaseDetails[0].containsKey('式別')) {
                          shikibetsu = purchaseDetails[0]['式別'];
                        }

                        String displayString = shikibetsu;

                        if (betType == '応援馬券') {
                          displayString = '応援馬券 単勝+複勝';
                        } else if (betType == 'ながし') {
                          if (purchaseDetails.isNotEmpty && purchaseDetails[0].containsKey('ながし')) {
                            displayString += ' ${purchaseDetails[0]['ながし']}';
                          } else {
                            displayString += ' ながし';
                          }
                        } else {
                          displayString += ' $betType';
                        }

                        return Text(
                          displayString,
                          style: TextStyle(color: Colors.black54, fontSize: 16),
                        );
                      }),
                    const SizedBox(height: 8),
                    if (parsedResult.containsKey('購入内容'))
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '購入内容',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                              fontSize: 16,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _buildPurchaseDetails(parsedResult['購入内容'], parsedResult['方式']),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 100,
                            child: Text(
                              '合計金額',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '$totalAmount円',
                              style: TextStyle(
                                color: Colors.black54,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (salesLocation != null && salesLocation.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 100,
                              child: Text(
                                '発売所',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                salesLocation,
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                )),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('馬券スキャナー'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenHeight = constraints.maxHeight;
          final screenWidth = constraints.maxWidth;

          final cameraHeight = screenHeight * 0.7;
          final cameraWidth = cameraHeight * (16 / 9);

          final actualCameraWidth = (cameraWidth > screenWidth) ? screenWidth : cameraWidth;
          final actualCameraHeight = actualCameraWidth * (9 / 16);

          final cameraTopOffset = screenHeight * 0.3;

          final scanAreaSize = actualCameraWidth * 0.8;

          return Stack(
            children: [
              Positioned.fill(
                child: CustomBackground(
                  overallBackgroundColor: const Color.fromRGBO(231, 234, 234, 1.0),
                  stripeColor: const Color.fromRGBO(219, 234, 234, 0.6),
                  fillColor: const Color.fromRGBO(172, 234, 231, 1.0),
                ),
              ),

              Positioned(
                top: cameraTopOffset,
                left: (screenWidth - actualCameraWidth) / 2,
                width: actualCameraWidth,
                height: actualCameraHeight,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRect(
                    child: MobileScanner(
                      controller: _scannerController,
                      onDetect: _onDetect,
                    ),
                  ),
                ),
              ),

              Positioned(
                top: cameraTopOffset,
                left: (screenWidth - actualCameraWidth) / 2,
                width: actualCameraWidth,
                height: actualCameraHeight,
                child: Center(
                  child: SizedBox(
                    width: scanAreaSize,
                    height: scanAreaSize,
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: const Color.fromRGBO(255, 255, 255, 0.3),
                            borderRadius: BorderRadius.circular(16.0),
                          ),
                        ),
                        const Center(
                          child: Text(
                            '馬券を読み込んでください',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              if (_isShowingDuplicateMessage)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.6),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(20.0),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        child: const Text(
                          'この馬券はすでに読み込みました',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),

              if (_showResultOverlay)
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                    child: Container(
                      color: Colors.black.withOpacity(0.5),
                      child: Center(
                        child: SingleChildScrollView(
                          child: AlertDialog(
                            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
                            title: Text(
                              'スキャン結果',
                              style: TextStyle(
                                color: Theme.of(context).textTheme.bodyLarge?.color,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            content: SizedBox(
                              width: MediaQuery.of(context).size.width * 0.8,
                              height: MediaQuery.of(context).size.height * 0.6,
                              child: _buildResultContent(_parsedResultForOverlay), // 統合されたResultPageの内容を表示
                            ),
                            actions: [
                              TextButton(
                                onPressed: _hideResultOverlayAndResumeScanner,
                                child: const Text('次の馬券を読み込む'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).popUntil((route) => route.isFirst);
                                },
                                child: const Text('トップ画面に戻る'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
