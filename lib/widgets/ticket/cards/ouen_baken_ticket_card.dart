// lib/widgets/ticket/cards/ouen_baken_ticket_card.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/details/purchase_details_card.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/util/ticket_format.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/util/ticket_fonts.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/layout/ticket_common_layer.dart';

/// 応援馬券専用のJRAの馬券を模したUIを表示するウィジェット
class OuenBakenTicketCard extends StatelessWidget {
  final Map<String, dynamic> ticketData;
  final RaceResult? raceResult;

  const OuenBakenTicketCard({
    super.key,
    required this.ticketData,
    this.raceResult,
  });

  @override
  Widget build(BuildContext context) {
    String hoshikiToDisplay = 'が　ん　ば　れ！';
    String overallMethod = '';
    Widget topWidget = SizedBox(
      height: 15.0,
      child: FittedBox(
        fit: BoxFit.contain,
        child: Text('WIN', textAlign: TextAlign.center, style: ticketGothic(color: Colors.black)),
      ),
    );
    Widget bottomWidget = SizedBox(
      height: 30.0,
      child: FittedBox(
        fit: BoxFit.contain,
        child: Text('PLACE\nSHOW', textAlign: TextAlign.center, style: ticketGothic(color: Colors.white)),
      ),
    );
    Color topContainerColor = Colors.transparent;
    Color bottomContainerColor = Colors.black;
    Color middleContainerColor = Colors.transparent;
    Color middleTextColor = Colors.black;

    // [修正] 式別「単勝✙複勝」の漢字用スタイル。ループをやめて直接並べるため共通化 (v.2026.9.16+XXXXXXXX)
    final TextStyle kanjiStyle = ticketMincho(
      color: middleTextColor,
      fontSize: 36, // ← 基準サイズを 36 など大きめにする
      fontWeight: FontWeight.bold,
      height: 1.2, // フォントの上下余白を削り、文字間の隙間を詰める
      leadingDistribution: TextLeadingDistribution.even,
    );

    if (ticketData.containsKey('方式')) {
      overallMethod = ticketData['方式'] ?? '';
    }

    return AspectRatio(
      aspectRatio: 86 / 53,
      child: DefaultTextStyle.merge(
        style: ticketMincho(),
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

              return Stack(
                children: [
                  ...buildTicketCommonLayer(
                    w: w,
                    h: h,
                    ticketData: ticketData,
                    raceResult: raceResult,
                  ),

                  // === 中央列: 式別 (36%, 0%, 11%, 82%) ===
                  Positioned(
                    left: w * 0.36,
                    top: 0,
                    width: w * 0.11,
                    height: h * 0.82,
                    child: Container(
                      decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 1.0)),
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            color: topContainerColor,
                            padding: const EdgeInsets.symmetric(vertical: 0.5),
                            child: Center(child: topWidget),
                          ),
                          Expanded(
                            child: Container(
                              alignment: Alignment.center,
                              color: middleContainerColor,
                              padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 1.0),
                              child: (ticketData.containsKey('方式'))
                                  ? FittedBox(
                                fit: BoxFit.fill, // ← 横幅いっぱいにフィットさせる設定
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text('単', style: kanjiStyle),
                                    Text('勝', style: kanjiStyle),
                                    // [修正] 実物馬券に合わせ「✙」を白抜き十字の図形で描画する (v.2026.9.16+XXXXXXXX)
                                    SizedBox(
                                      width: 26,
                                      height: 26,
                                      child: CustomPaint(
                                        painter: OutlinedCrossPainter(strokeColor: middleTextColor),
                                      ),
                                    ),
                                    Text('複', style: kanjiStyle),
                                    Text('勝', style: kanjiStyle),
                                  ],
                                ),
                              )
                                  : const SizedBox.shrink(),
                            ),
                          ),
                          Container(
                            width: double.infinity,
                            color: bottomContainerColor,
                            padding: const EdgeInsets.symmetric(vertical: 0.5),
                            child: Center(child: bottomWidget),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ★【右列1】「が　ん　ば　れ！」枠の配置領域 (横幅: 53%, 高さ: 18%)
                  Positioned(
                    left: w * 0.47,   // 左端から 47% の位置
                    top: 0,           // 最上部
                    width: w * 0.53,  // 横幅 53%
                    height: h * 0.18, // 高さ 18%
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6.0, right: 2.0, top: 1.0),
                      child: Column(
                        children: [
                          if (hoshikiToDisplay.isNotEmpty)
                            DecoratedBox(
                              decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 1.5)), // 「がんばれ！」の黒い囲み枠
                              child: SizedBox(
                                height: h * 0.12, // 枠の高さ
                                child: Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      hoshikiToDisplay,
                                      style: ticketGothic(
                                        color: Colors.black,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 24, // ★「が　ん　ば　れ！」の文字サイズ (24pt)
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // ★【右列2】「購入内容（馬番・馬名・各100円）」の大元表示領域 (下寄りにシフト: h * 0.22〜)
                  Positioned(
                    left: w * 0.47,  // 左端から 47% の位置
                    top: hoshikiToDisplay.isNotEmpty ? h * 0.22 : h * 0.02, // [修正] 全体を下寄りに繰り下げ (h * 0.22) (v.2026.9.15+26091501)
                    width: w * 0.53, // 横幅 53%
                    height: hoshikiToDisplay.isNotEmpty ? h * 0.37 : h * 0.53, // ★大元の表示箱の高さ (37%)
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: PurchaseDetailsCard(
                        parsedResult: ticketData,
                        betType: overallMethod,
                        raceResult: raceResult,
                      ),
                    ),
                  ),

                  // ★【右列3】「単勝 100円」「複勝 100円」の配置領域 (下端を中央列の下端 h * 0.82 に一致させる)
                  Positioned(
                    left: w * 0.47,  // 左端から 47% の位置
                    top: h * 0.58,   // [修正] 開始位置 h * 0.58
                    width: w * 0.53, // 横幅 53%
                    height: h * 0.24, // [修正] 高さ h * 0.24 (下端が h * 0.82 に達する)
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: _buildOuenAmountDisplay(ticketData),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        ),
      ),
    );
  }
}

/// 応援馬券の「単勝◯円」「複勝◯円」2行表示の描画関数
Widget _buildOuenAmountDisplay(Map<String, dynamic> ticketData) {
  if (!ticketData.containsKey('購入内容')) {
    return const SizedBox.shrink();
  }
  List<Map<String, dynamic>> purchaseDetails = (ticketData['購入内容'] as List).cast<Map<String, dynamic>>();
  if (purchaseDetails.length < 2) {
    return const SizedBox.shrink();
  }
  final detail = purchaseDetails.first;

  // ★各パーツごとの個別フォントスタイル（それぞれ独立してサイズを変更可能）
  // 1. 「単勝」「複勝」の文字サイズ
  final TextStyle labelStyle = ticketMincho(
    color: Colors.black,
    fontWeight: FontWeight.bold,
    fontSize: 20, // ★「単勝」「複勝」の文字サイズ (18pt)
    height: 1.0,
  );

  // 2. 伏せ字「☆」の文字サイズ
  final TextStyle starStyle = ticketMincho(
    color: Colors.black,
    fontWeight: FontWeight.bold,
    fontSize: 10, // ★「☆」の文字サイズ (10pt)
  );

  // 3. 金額数値（例: 100）の文字サイズ
  final TextStyle numberStyle = ticketGothic(
    color: Colors.black,
    fontWeight: FontWeight.bold,
    fontSize: 26, // ★金額数値の文字サイズ (18pt)
    height: 1.0,
  );

  // 4. 単位「円」の文字サイズ
  final TextStyle unitStyle = ticketMincho(
    color: Colors.black,
    fontWeight: FontWeight.bold,
    fontSize: 14, // ★単位「円」の文字サイズ (18pt)
    height: 1.0,
  );

  int kingaku = detail['購入金額'] as int;
  String starsForAmount = getStars(kingaku);
  String amountValue = kingaku.toString();
  return Column(
    mainAxisAlignment: MainAxisAlignment.end,  // ★「下揃え」にして、中央帯最下端(PLACE SHOW)の高さラインにぴったり揃える
    crossAxisAlignment: CrossAxisAlignment.end, // 右寄せ
    children: [
      // 1行目: 単勝
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('単勝 ', style: labelStyle),

            // ★「☆」だけを Y軸方向（マイナス＝上方向）に少し持ち上げて縦中央に寄せる
            Transform.translate(
              offset: const Offset(0, -3.5), // ★ ここの -3.5 (px) の数値を変更して「☆」の高さを微調整できます
              child: Text(starsForAmount, style: starStyle),
            ),

            Text(amountValue, style: numberStyle),
            Text('円', style: unitStyle),
          ],
        ),
      ),
      // 2行目: 複勝
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('複勝 ', style: labelStyle),
            // ★「☆」だけを Y軸方向（マイナス＝上方向）に少し持ち上げて縦中央に寄せる
            Transform.translate(
              offset: const Offset(0, -3.5), // ★ ここの -3.5 (px) の数値を変更して「☆」の高さを微調整できます
              child: Text(starsForAmount, style: starStyle),
            ),
            Text(amountValue, style: numberStyle),
            Text('円', style: unitStyle),
          ],
        ),
      ),
    ],
  );
}
/// 応援馬券の式別帯に表示する白抜きの十字（✙）を描画する
class OutlinedCrossPainter extends CustomPainter {
  final Color strokeColor;
  final Color fillColor;
  final double armRatio;     // 腕の太さ（全体幅に対する割合）
  final double strokeWidth;  // 輪郭線の太さ

  OutlinedCrossPainter({
    required this.strokeColor,
    this.fillColor = Colors.white,
    this.armRatio = 0.36,
    this.strokeWidth = 2.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double inset = strokeWidth / 2;
    final double w = size.width - strokeWidth;
    final double h = size.height - strokeWidth;
    final double a = w * armRatio;         // 腕の太さ
    final double x1 = inset + (w - a) / 2; // 縦棒の左端
    final double x2 = x1 + a;              // 縦棒の右端
    final double y1 = inset + (h - a) / 2; // 横棒の上端
    final double y2 = y1 + a;              // 横棒の下端
    final double l = inset, t = inset, r = inset + w, b = inset + h;

    final path = Path()
      ..moveTo(x1, t)
      ..lineTo(x2, t)
      ..lineTo(x2, y1)
      ..lineTo(r, y1)
      ..lineTo(r, y2)
      ..lineTo(x2, y2)
      ..lineTo(x2, b)
      ..lineTo(x1, b)
      ..lineTo(x1, y2)
      ..lineTo(l, y2)
      ..lineTo(l, y1)
      ..lineTo(x1, y1)
      ..close();

    canvas.drawPath(path, Paint()..color = fillColor..style = PaintingStyle.fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeJoin = StrokeJoin.miter,
    );
  }

  @override
  bool shouldRepaint(covariant OutlinedCrossPainter oldDelegate) =>
      oldDelegate.strokeColor != strokeColor ||
          oldDelegate.fillColor != fillColor ||
          oldDelegate.armRatio != armRatio ||
          oldDelegate.strokeWidth != strokeWidth;
}
