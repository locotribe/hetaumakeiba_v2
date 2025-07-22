import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/widgets/app_styles.dart';

class RaceInfoDisplay extends StatelessWidget {
  final Map<String, dynamic> parsedResult;

  const RaceInfoDisplay({
    Key? key,
    required this.parsedResult,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (parsedResult.containsKey('年') &&
            parsedResult.containsKey('回') &&
            parsedResult.containsKey('日'))
          Text(
            '20${parsedResult['年']}年${parsedResult['回']}回${parsedResult['日']}日',
            style: AppStyles.dateTextStyle,
          ),
        const SizedBox(height: 4),
        if (parsedResult.containsKey('開催場') &&
            parsedResult.containsKey('レース'))
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${parsedResult['開催場']}',
                style: AppStyles.racecourseTextStyle,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    width: 50.0,
                    height: 30.0,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.all(Radius.circular(0)),
                    ),
                    child: Text(
                      '${parsedResult['レース']}',
                      style: AppStyles.raceNumberTextStyle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'レース',
                    style: AppStyles.raceLabelTextStyle,
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }
}
