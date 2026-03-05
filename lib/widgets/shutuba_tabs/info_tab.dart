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
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.grey.shade200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          horse.isScratched
              ? const Text('取消', style: TextStyle(color: Colors.red, fontSize: 12))
              : buildMarkDropdown(horse),
          const SizedBox(height: 6),
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: horse.gateNumber > 0 ? horse.gateNumber.gateBackgroundColor : Colors.white,
              border: Border.all(color: horse.gateNumber > 0 ? horse.gateNumber.gateBackgroundColor : Colors.grey),
            ),
            child: Text(
              horse.horseNumber.toString(),
              style: TextStyle(
                color: (horse.gateNumber.gateBackgroundColor == Colors.black) ? Colors.white : Colors.black87,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
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