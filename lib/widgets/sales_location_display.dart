import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/widgets/app_styles.dart';

class SalesLocationDisplay extends StatelessWidget {
  final String salesLocation;

  const SalesLocationDisplay({
    Key? key,
    required this.salesLocation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '発売所',
              style: AppStyles.salesLocationLabelStyle,
            ),
          ),
          Expanded(
            child: Text(
              salesLocation,
              style: AppStyles.salesLocationTextStyle,
            ),
          ),
        ],
      ),
    );
  }
}
