// lib/widgets/analyzed_races_tab.dart

import 'package:flutter/material.dart';

class AnalyzedRacesTab extends StatelessWidget {
  final List<Map<String, dynamic>> analyzedRaces;

  const AnalyzedRacesTab({
    Key? key,
    required this.analyzedRaces,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (analyzedRaces.isEmpty) {
      return const Center(child: Text('データがありません'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: analyzedRaces.length,
      itemBuilder: (context, index) {
        final race = analyzedRaces[index];
        final date = race['date'] ?? '';
        final title = race['raceName'] ?? '';
        final info = race['raceInfo'] ?? '';
        final winner = race['winner'] ?? '-';

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4.0),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blueGrey.shade100,
              child: Text(
                date.split('年').first, // 年だけ表示 (例: 2024)
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(info, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 2),
                Text('1着: $winner', style: const TextStyle(color: Colors.redAccent)),
              ],
            ),
            dense: true,
          ),
        );
      },
    );
  }
}