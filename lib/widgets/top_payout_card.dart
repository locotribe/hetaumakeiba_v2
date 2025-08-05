// lib/widgets/top_payout_card.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/analytics_data_model.dart';
import 'package:intl/intl.dart';

class TopPayoutCard extends StatelessWidget {
  final TopPayoutInfo topPayout;

  const TopPayoutCard({
    super.key,
    required this.topPayout,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.decimalPattern('ja');

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Text(
                    '${currencyFormatter.format(topPayout.payout)}円',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    topPayout.raceName,
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    topPayout.raceDate,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}