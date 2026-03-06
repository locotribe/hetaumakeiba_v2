// lib/widgets/shutuba_tabs/info_tab.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/utils/gate_color_utils.dart';

// 1列目: 印・枠セル
class MarkAndGateCell extends StatelessWidget {
  final PredictionHorseDetail horse;
  final Widget Function(PredictionHorseDetail) buildMarkDropdown;

  const MarkAndGateCell({
    Key? key,
    required this.horse,
    required this.buildMarkDropdown,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // セル全体の背景色を枠色にする（発表前はグレー）
    final bgColor = horse.gateNumber > 0 ? horse.gateNumber.gateBackgroundColor : Colors.grey.shade200;

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: bgColor,
      child: Column(
        children: [
          // 1. 枠番・馬番の表示エリア (上半分)
          if (horse.gateNumber > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 「〇枠」テキスト
                  Text(
                    '${horse.gateNumber}枠',
                    style: TextStyle(
                      color: horse.gateNumber.gateTextColor,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // 馬番の正方形
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: horse.gateNumber.gateBackgroundColor,
                      border: Border.all(
                        // ▼ ここを変更: 2枠(黒)の時だけ白、それ以外は黒の縁取りにする ▼
                        color: horse.gateNumber == 2 ? Colors.white : Colors.black87,
                        width: 2.0,
                      ),
                    ),
                    child: Text(
                      horse.horseNumber.toString(),
                      style: TextStyle(
                        color: horse.gateNumber.gateTextColor,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            )
          // 枠順発表前（gateNumberが0以下）の表示
          else
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black87),
                ),
                child: Text(
                  horse.horseNumber.toString(),
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          // 2. 印（または取消）の表示エリア (下半分)
          Expanded(
            child: Center(
              child: horse.isScratched
                  ? const Text('取消', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold))
                  : buildMarkDropdown(horse),
            ),
          ),
        ],
      ),
    );
  }
}

// 2列目: 人気・オッズセル
class OddsCell extends StatelessWidget {
  final PredictionHorseDetail horse;

  const OddsCell({Key? key, required this.horse}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '${horse.popularity ?? '--'}',
                style: const TextStyle(fontSize: 20), // ここだけサイズ15
              ),
              const TextSpan(
                text: '\n人気',
                style: TextStyle(fontSize: 10), // ここはサイズ10
              ),
            ],
          ),
          textAlign: TextAlign.right, // 親が右寄せ(CrossAxisAlignment.end)なので、文字自体も右寄せにしておくと綺麗です
        ),
        const SizedBox(height: 8),
        Text(
          horse.odds?.toString() ?? '--',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: (horse.odds != null && horse.odds! <= 9.9) ? Colors.red : Colors.black87,
          ),
        ),
      ],
    );
  }
}