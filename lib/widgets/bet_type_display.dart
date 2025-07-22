import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/widgets/app_styles.dart';

class BetTypeDisplay extends StatelessWidget {
  final String betType;

  const BetTypeDisplay({
    Key? key,
    required this.betType,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 縦書き風に 1 文字ずつ改行して表示
    final String verticalText = betType.split('').join('\n');

    return Container(
      width: 30.0,
      alignment: Alignment.topCenter,
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Text(
        verticalText,
        style: AppStyles.betTypeVerticalTextStyle,
        textAlign: TextAlign.center,
      ),
    );
  }
}
