// lib/widgets/dual_betting_ticket_card.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hetaumakeiba_v2/logic/combination_calculator.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/widgets/purchase_details_card.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// 1枚の馬券に2種類の式別（例: ワイド + 3連複）が含まれる通常馬券用カードウィジェット
class DualBettingTicketCard extends StatelessWidget {
  final Map<String, dynamic> ticketData;
  final RaceResult? raceResult;

  const DualBettingTicketCard({
    super.key,
    required this.ticketData,
    this.raceResult,
  });

  @override
  Widget build(BuildContext context) {
    String? salesLocation;
    if (ticketData.containsKey('発売所')) {
      salesLocation = ticketData['発売所'] as String;
    }

    List<Map<String, dynamic>> purchaseDetails = [];
    if (ticketData.containsKey('購入内容')) {
      final rawList = ticketData['購入内容'];
      if (rawList is List) {
        purchaseDetails = rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    }

    // 式別コードごとにグループ分け
    final Map<String, List<Map<String, dynamic>>> groupedDetails = {};
    for (var detail in purchaseDetails) {
      final rawCode = detail['式別']?.toString() ?? '';
      String code = rawCode;
      if (rawCode.isNotEmpty) {
        try {
          code = int.parse(rawCode).toString();
        } catch (_) {}
      }
      groupedDetails.putIfAbsent(code, () => []).add(detail);
    }

    final List<String> betCodes = groupedDetails.keys.toList();
    final String code1 = betCodes.isNotEmpty ? betCodes[0] : '';
    final String code2 = betCodes.length > 1 ? betCodes[1] : '';

    final List<Map<String, dynamic>> group1Details = groupedDetails[code1] ?? [];
    final List<Map<String, dynamic>> group2Details = groupedDetails[code2] ?? [];

    return AspectRatio(
      aspectRatio: 86 / 53,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey),
          image: const DecorationImage(
            image: AssetImage('assets/images/baken_bg.png'),
            fit: BoxFit.cover,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.2),
              spreadRadius: 1,
              blurRadius: 4,
              offset: Offset(2, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;
              final leftPadding = w * 0.018;

              return Stack(
                children: [
                  // === 左列1: 年月日 (0%, 0%, 36%, 11%) ===
                  Positioned(
                    left: leftPadding,
                    top: 0,
                    width: w * 0.36 - leftPadding,
                    height: h * 0.11,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: ticketData.containsKey('年') && ticketData.containsKey('回') && ticketData.containsKey('日')
                            ? Text(
                                '20${ticketData['年']}年${ticketData['回']}回${ticketData['日']}日',
                                style: GoogleFonts.notoSerifJp(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),

                  // === 左列2: 開催場 (0%, 11%, 36%, 14%) ===
                  Positioned(
                    left: leftPadding,
                    top: h * 0.11,
                    width: w * 0.36 - leftPadding,
                    height: h * 0.14,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: ticketData.containsKey('開催場')
                            ? Text(
                                '${ticketData['開催場']}',
                                style: GoogleFonts.notoSerifJp(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 28,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),

                  // === 左列3: レース番号 (0%, 25%, 36%, 12%) ===
                  Positioned(
                    left: leftPadding,
                    top: h * 0.25,
                    width: w * 0.36 - leftPadding,
                    height: h * 0.12,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ticketData.containsKey('レース')
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: w * 0.13,
                                  height: h * 0.11,
                                  alignment: Alignment.center,
                                  color: Colors.black,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      '${ticketData['レース']}',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Text('レース', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),

                  // === 左列4: QRコード (0%, 37%, 36%, 26%) ===
                  Positioned(
                    left: 0,
                    top: h * 0.37,
                    width: w * 0.36,
                    height: h * 0.26,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(1.0),
                            child: Image.asset('assets/images/QR_JRA.png', fit: BoxFit.contain),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(1.0),
                            child: Builder(builder: (context) {
                              if (raceResult != null && raceResult!.raceId.isNotEmpty) {
                                final url = 'https://db.netkeiba.com/race/${raceResult!.raceId}';
                                return QrImageView(
                                  data: url,
                                  version: QrVersions.auto,
                                  backgroundColor: Colors.transparent,
                                  padding: EdgeInsets.zero,
                                );
                              } else {
                                return Image.asset('assets/images/QR_JRA.png', fit: BoxFit.contain);
                              }
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // === 左列5: 第86回 菊花賞 (0%, 63%, 36%, 19%) ===
                  Positioned(
                    left: leftPadding,
                    top: h * 0.63,
                    width: w * 0.36 - leftPadding,
                    height: h * 0.19,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: raceResult != null && raceResult!.raceTitle.isNotEmpty
                          ? Builder(builder: (context) {
                              final RegExp regExp = RegExp(r"^(第.+?回)(.+?)\((.+?)\)$");
                              final match = regExp.firstMatch(raceResult!.raceTitle);

                              if (match != null && match.groupCount >= 3) {
                                final String numberPart = match.group(1)!;
                                final String namePart = match.group(2)!;
                                final String gradePart = match.group(3)!;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text("$numberPart  ($gradePart)", style: GoogleFonts.notoSerifJp(fontSize: 11, color: Colors.black)),
                                    ),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(namePart, style: GoogleFonts.notoSerifJp(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black)),
                                    ),
                                  ],
                                );
                              } else {
                                return FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(raceResult!.raceTitle, style: GoogleFonts.notoSerifJp(fontSize: 13, color: Colors.black)),
                                );
                              }
                            })
                          : const SizedBox.shrink(),
                    ),
                  ),

                  // === 上段（第1式別ブロック: Y 0% 〜 41%）===
                  _buildSingleShikibetsuBand(
                    left: w * 0.36,
                    top: 0,
                    width: w * 0.11,
                    height: h * 0.41,
                    shikibetsuCode: code1,
                  ),
                  Positioned(
                    left: w * 0.47,
                    top: 0,
                    width: w * 0.53,
                    height: h * 0.41,
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: _buildDetailsListForGroup(group1Details, h * 0.41),
                    ),
                  ),

                  // === 下段（第2式別ブロック: Y 41% 〜 82%）===
                  _buildSingleShikibetsuBand(
                    left: w * 0.36,
                    top: h * 0.41,
                    width: w * 0.11,
                    height: h * 0.41,
                    shikibetsuCode: code2,
                  ),
                  Positioned(
                    left: w * 0.47,
                    top: h * 0.41,
                    width: w * 0.53,
                    height: h * 0.41,
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: _buildDetailsListForGroup(group2Details, h * 0.41),
                    ),
                  ),

                  // === フッター1・左: 発券場所 (0%, 82%, 36%, 9%) ===
                  Positioned(
                    left: leftPadding,
                    top: h * 0.82,
                    width: w * 0.36 - leftPadding,
                    height: h * 0.09,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          salesLocation != null && salesLocation.startsWith('JRA') && !salesLocation.startsWith('JRA ')
                              ? salesLocation.replaceFirst('JRA', 'JRA ')
                              : (salesLocation ?? ''),
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ),
                  ),

                  // === フッター1・右: 合計金額 (36%, 82%, 64%, 9%) ===
                  Positioned(
                    left: w * 0.36,
                    top: h * 0.82,
                    width: w * 0.64,
                    height: h * 0.09,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: PurchaseTotalAmountCard(parsedResult: ticketData),
                    ),
                  ),

                  // === フッター2・左: 日付 (0%, 91%, 36%, 9%) ===
                  Positioned(
                    left: leftPadding,
                    top: h * 0.91,
                    width: w * 0.36 - leftPadding,
                    height: h * 0.09,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          raceResult != null && raceResult!.raceDate.isNotEmpty
                              ? raceResult!.raceDate
                              : '',
                          style: const TextStyle(color: Colors.black, fontSize: 11),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// 既存の帯の分岐スタイルを100%保持したまま、指定された領域(高さ)に帯を描画するヘルパー
  Widget _buildSingleShikibetsuBand({
    required double left,
    required double top,
    required double width,
    required double height,
    required String shikibetsuCode,
  }) {
    String normalizedCode = shikibetsuCode;
    if (int.tryParse(shikibetsuCode) != null) {
      normalizedCode = int.parse(shikibetsuCode).toString();
    }
    final String shikibetsuName = bettingDict[normalizedCode] ?? bettingDict[shikibetsuCode] ?? '';
    Widget topWidget = const SizedBox.shrink();
    Widget bottomWidget = const SizedBox.shrink();
    Color topBg = Colors.black;
    Color bottomBg = Colors.black;
    Color middleBg = Colors.transparent;
    Color middleTextColor = Colors.black;

    switch (shikibetsuName) {
      case '単勝':
        topWidget = bottomWidget = const FittedBox(fit: BoxFit.contain, child: Text('WIN', style: TextStyle(color: Colors.black)));
        topBg = bottomBg = Colors.transparent;
        break;
      case '複勝':
        topWidget = bottomWidget = const FittedBox(fit: BoxFit.contain, child: Text('PLACE\nSHOW', style: TextStyle(color: Colors.white)));
        topBg = bottomBg = Colors.black;
        break;
      case '馬連':
        topWidget = bottomWidget = const FittedBox(fit: BoxFit.contain, child: Text('QUINELLA', style: TextStyle(color: Colors.black)));
        topBg = bottomBg = Colors.transparent;
        break;
      case '馬単':
        topWidget = bottomWidget = const FittedBox(fit: BoxFit.contain, child: Text('EXACTA', style: TextStyle(color: Colors.white)));
        topBg = bottomBg = Colors.black;
        break;
      case 'ワイド':
        topWidget = bottomWidget = const FittedBox(fit: BoxFit.contain, child: Text('QUINELLA\nPLACE', style: TextStyle(color: Colors.white)));
        topBg = bottomBg = Colors.black;
        break;
      case '枠連':
        topWidget = bottomWidget = const FittedBox(fit: BoxFit.contain, child: Text('BRACKET\nQUINELLA', style: TextStyle(color: Colors.white)));
        topBg = bottomBg = Colors.black;
        middleBg = Colors.black;
        middleTextColor = Colors.white;
        break;
      case '3連複':
        topWidget = bottomWidget = const FittedBox(fit: BoxFit.contain, child: Text('TRIO', style: TextStyle(color: Colors.black)));
        topBg = bottomBg = Colors.transparent;
        break;
      case '3連単':
        topWidget = bottomWidget = const FittedBox(fit: BoxFit.contain, child: Text('TRIFECTA', style: TextStyle(color: Colors.white)));
        topBg = bottomBg = Colors.black;
        break;
    }

    final String fullWidthName = _convertHalfWidthNumbersToFullWidth(shikibetsuName);

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Container(
        decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 1.0)),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: topBg,
              padding: const EdgeInsets.symmetric(vertical: 0.5),
              child: SizedBox(height: height * 0.22, child: Center(child: topWidget)),
            ),
            Expanded(
              child: Container(
                alignment: Alignment.center,
                color: middleBg,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int i = 0; i < fullWidthName.characters.length; i++) ...[
                        if (i > 0) const SizedBox(height: 1),
                        Text(
                          fullWidthName.characters.elementAt(i),
                          style: GoogleFonts.notoSerifJp(color: middleTextColor, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              color: bottomBg,
              padding: const EdgeInsets.symmetric(vertical: 0.5),
              child: SizedBox(height: height * 0.22, child: Center(child: bottomWidget)),
            ),
          ],
        ),
      ),
    );
  }

  /// 1つの式別グループ内の購入リストを描画するヘルパー
  Widget _buildDetailsListForGroup(List<Map<String, dynamic>> groupDetails, double availableHeight) {
    if (groupDetails.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var detail in groupDetails) ...[
          _buildGroupItemRow(detail),
        ]
      ],
    );
  }

  Widget _buildGroupItemRow(Map<String, dynamic> detail) {
    final String rawCode = detail['式別']?.toString() ?? '';
    String normalizedCode = rawCode;
    if (int.tryParse(rawCode) != null) {
      normalizedCode = int.parse(rawCode).toString();
    }
    final String shikibetsu = bettingDict[normalizedCode] ?? bettingDict[rawCode] ?? '';
    final horseNumbers = detail['馬番'];
    final int? amount = detail['購入金額'];

    String symbol = '━';
    if (shikibetsu == '馬単' || shikibetsu == '3連単') symbol = '▶';
    if (shikibetsu == 'ワイド') symbol = '◆';

    List<int> numbers = [];
    if (horseNumbers is List) {
      numbers = horseNumbers.cast<int>();
    } else if (horseNumbers is int) {
      numbers = [horseNumbers];
    }

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (int i = 0; i < numbers.length; i++) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 1.0)),
              child: Text(
                '${numbers[i]}',
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            if (i < numbers.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                child: Text(symbol, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
          ],
          const SizedBox(width: 8),
          if (amount != null) ...[
            Text(_getStars(amount), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10)),
            Text('$amount円', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ],
      ),
    );
  }
}

String _convertHalfWidthNumbersToFullWidth(String text) {
  return text
      .replaceAll('0', '０')
      .replaceAll('1', '１')
      .replaceAll('2', '２')
      .replaceAll('3', '３')
      .replaceAll('4', '４')
      .replaceAll('5', '５')
      .replaceAll('6', '６')
      .replaceAll('7', '７')
      .replaceAll('8', '８')
      .replaceAll('9', '９');
}

String _getStars(int amount) {
  String amountStr = amount.toString();
  int numDigits = amountStr.length;
  if (numDigits >= 6) return '';
  if (numDigits == 5) return '☆';
  if (numDigits == 4) return '☆☆';
  if (numDigits == 3) return '☆☆☆';
  return '';
}
