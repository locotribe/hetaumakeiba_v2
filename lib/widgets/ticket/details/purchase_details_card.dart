// lib/widgets/ticket/details/purchase_details_card.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/details/normal_details.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/details/box_details.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/details/nagashi_details.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/details/formation_details.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/details/ouen_baken_details.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/util/ticket_fonts.dart';

class PurchaseDetailsCard extends StatefulWidget {
  final Map<String, dynamic> parsedResult;
  final String betType;
  final RaceResult? raceResult;

  const PurchaseDetailsCard({
    super.key,
    required this.parsedResult,
    required this.betType,
    this.raceResult,
  });

  @override
  State<PurchaseDetailsCard> createState() => _PurchaseDetailsCardState();
}

class _PurchaseDetailsCardState extends State<PurchaseDetailsCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  /// 【リファクタリング】メインの分岐処理
  /// 投票種別に応じて、上記で作成した各レイアウト構築メソッドを呼び出すように変更
  List<Widget> _buildPurchaseDetailsInternal(dynamic purchaseData, String currentBetType) {
    List<Map<String, dynamic>> purchaseDetails = (purchaseData as List).cast<Map<String, dynamic>>();

    // 応援馬券は他の券種と構造が異なるため、ここで特別に処理する
    if (currentBetType == '応援馬券') {
      return buildOuenBakenDetails(purchaseDetails, widget.raceResult);
    }

    return purchaseDetails.map((detail) {
      Widget content;

      // 投票種別に応じて適切なレイアウト構築メソッドを呼び出す
      switch (currentBetType) {
        case 'ながし':
          content = NagashiDetails(detail: detail, betType: currentBetType);
          break;
        case 'フォーメーション':
          content = buildFormationDetails(detail, currentBetType);
          break;
        case 'ボックス':
          content = buildBoxDetails(detail, widget.raceResult);
          break;
        case '通常':
        default:
          // [追加] クイックピック(方式コード"4")は未対応。スマッピ非対応のため実券が発生しないため現状のまま通常経路に落とす (v.2026.9.13+26091301)
          content = buildNormalDetails(detail, currentBetType, widget.raceResult);
          break;
      }

      // 以下の部分は、どの投票種別にも共通するラッパー（囲い）の役割を果たす
      return Padding(
        padding: const EdgeInsets.only(bottom: 2.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            content,
            if (detail['ウラ'] == 'あり')
              Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: Text('ウラ: あり', style: ticketGothic(color: Colors.black)),
              ),
          ],
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.parsedResult.containsKey('購入内容')) {
      return const SizedBox.shrink();
    }

    // [追加] 単勝・複勝で馬名が表示される場合のみ、購入内容を表示枠の縦中央に寄せる
    // 式別コード "1"=単勝 / "2"=複勝。日本語名で入っている場合にも備えて両方を判定する (v.2026.9.14+26091401)
    bool isHorseNameLayout = false;
    if (widget.betType == '通常' && widget.raceResult != null) {
      final dynamic rawList = widget.parsedResult['購入内容'];
      if (rawList is List && rawList.isNotEmpty) {
        isHorseNameLayout = rawList.every((e) {
          if (e is! Map) return false;
          final String code = e['式別']?.toString() ?? '';
          return code == '1' || code == '2' || code == '単勝' || code == '複勝';
        });
      }
    }

    final bool isCenterAligned =
        widget.betType == 'ながし' ||
        widget.betType == 'フォーメーション' ||
        widget.betType == '応援馬券' ||
        isHorseNameLayout;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double? parentWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : null;
        final double? parentHeight = constraints.maxHeight.isFinite ? constraints.maxHeight : null;

        return SizedBox(
          width: parentWidth,
          height: parentHeight,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: isCenterAligned ? Alignment.center : Alignment.topLeft,
            // 【レイアウト調整】SizedBoxで親領域の横幅(parentWidth)を子要素へ伝播させる
            // これにより、応援馬券の「各◯円」などの右寄せ行が、馬名の幅に留まらず馬券の右端まで確実に配置されます
            child: SizedBox(
              // 応援馬券のみ幅固定(parentWidth)を適用し、それ以外は中身の自然な幅をとらせて FittedBox で自動縮小させる
              width: widget.betType == '応援馬券' ? parentWidth : null,
              child: Padding(
                padding: const EdgeInsets.only(top: 2.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _buildPurchaseDetailsInternal(widget.parsedResult['購入内容'], widget.betType),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
