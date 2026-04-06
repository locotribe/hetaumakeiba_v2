// lib/widgets/rating/components/rating_level_badge.dart
import 'package:flutter/material.dart';

class RatingLevelBadge extends StatelessWidget {
  final String level;

  const RatingLevelBadge({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    if (level == 'None' || level == 'Mid') return const SizedBox.shrink();

    Color color = level == "High" ? Colors.red : Colors.blue;
    String label = level == "High" ? "▲激走" : "▼凡走";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }
}