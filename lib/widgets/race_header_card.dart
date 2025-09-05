// lib/widgets/race_header_card.dart

import 'package:flutter/material.dart';

class RaceHeaderCard extends StatelessWidget {
  final String title;
  final String detailsLine1;
  final String detailsLine2;

  const RaceHeaderCard({
    super.key,
    required this.title,
    required this.detailsLine1,
    required this.detailsLine2,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 10,
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
      color: const Color(0xFF1A4314), // 濃い背景色
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.white),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(detailsLine1),
              Text(detailsLine2),
            ],
          ),
        ),
      ),
    );
  }
}