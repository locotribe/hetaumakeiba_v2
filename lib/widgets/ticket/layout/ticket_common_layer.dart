// lib/widgets/ticket/layout/ticket_common_layer.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/parts/purchase_total_amount_card.dart';

List<Widget> buildTicketCommonLayer({
  required double w,
  required double h,
  required Map<String, dynamic> ticketData,
  RaceResult? raceResult,
}) {
  final leftPadding = w * 0.018; // 赤色縦線(QRコード左端)にインデントを正確に揃えるオフセット

  String? salesLocation;
  if (ticketData.containsKey('発売所')) {
    salesLocation = ticketData['発売所'] as String;
  }

  return [
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
      top: h * 0.09,
      width: w * 0.36 - leftPadding,
      height: h * 0.17,
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
                    fontSize: 30,
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
              padding: const EdgeInsets.symmetric(vertical: 1.0), // 黒枠内の微小なパディング
              child: FittedBox(
                fit: BoxFit.contain, // ★ 枠の高さに合わせて自動で限界まで拡大
                child: Text(
                  '${ticketData['レース']}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900, // ★ 極太にする
                    fontSize: 32, // ★ 基準サイズを大きくする
                    height: 1.0,  // ★ 上下の余白をカットして黒枠いっぱいに広げる
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'レース',
              style: GoogleFonts.notoSerifJp( // ★ 明朝体（GoogleFonts.notoSerifJp）に変更
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        )
            : const SizedBox.shrink(),
      ),
    ),

    // === 左列4: QRコード (0%, 37%, 36%, 26%) ===
    Positioned(
      left: 0,
      top: h * 0.38,
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
                        child: Text("$numberPart  ($gradePart)", style: GoogleFonts.notoSerifJp(fontSize: 15, color: Colors.black)),
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
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
      ),
    ),

    // === フッター1・右: 合計金額 (36%, 82%, 64%, 9%) ===
    Positioned(
      left: w * 0.36,
      top: h * 0.82,
      width: w * 0.64,
      height: h * 0.14,
      child: Align(
        alignment: Alignment.centerLeft,
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
                ? () {
              final match = RegExp(r'(\d{1,2})[月/\.-](\d{1,2})').firstMatch(raceResult!.raceDate);
              if (match != null) {
                final month = int.parse(match.group(1)!); // 02 -> 2 に変換
                final day = int.parse(match.group(2)!);   // 02 -> 2 に変換
                return '$month月$day日';                  // 2月2日 にして返す
              }
              return raceResult!.raceDate;
            }()
                : '',
            style: const TextStyle(color: Colors.black, fontSize: 13),
          ),
        ),
      ),
    ),
  ];
}
