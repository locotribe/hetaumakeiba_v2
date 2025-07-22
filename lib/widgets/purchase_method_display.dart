import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/widgets/app_styles.dart';

class PurchaseMethodDisplay extends StatelessWidget {
  final Map<String, dynamic> parsedResult;

  const PurchaseMethodDisplay({
    Key? key,
    required this.parsedResult,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String overallMethod = parsedResult['式別'] ?? '';
    String displayMethod = '';

    if (overallMethod == '通常') {
      displayMethod = '';
    } else if (overallMethod == '応援馬券') {
      displayMethod = '応援馬券';
    } else if (overallMethod == 'ながし' &&
        parsedResult.containsKey('購入内容') &&
        (parsedResult['購入内容'] as List).isNotEmpty &&
        (parsedResult['購入内容'] as List)[0].containsKey('ながし')) {
      final List<Map<String, dynamic>> purchaseDetails =
      (parsedResult['購入内容'] as List).cast<Map<String, dynamic>>();
      displayMethod = '${purchaseDetails[0]['ながし']}';
    } else {
      displayMethod = overallMethod;
    }

    if (displayMethod.isNotEmpty) {
      return Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: 140.0,
                height: 35.0,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                decoration: AppStyles.purchaseMethodBoxDecoration,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Text(
                    displayMethod,
                    style: AppStyles.shikibetsuMethodTextStyle,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      return const SizedBox.shrink();
    }
  }
}
