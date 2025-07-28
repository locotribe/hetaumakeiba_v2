// lib/widgets/venue_races_card.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/home_page_data_model.dart';

class VenueRacesCard extends StatelessWidget {
  final VenueRaces venueRaces;

  const VenueRacesCard({super.key, required this.venueRaces});

  @override
  Widget build(BuildContext context) {
    // 競馬場名から頭文字1文字を取得
    final String venueInitial = venueRaces.venueName.isNotEmpty ? venueRaces.venueName.substring(0, 1) : '?';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      elevation: 2.0,
      clipBehavior: Clip.antiAlias, // ExpansionTileの境界線を綺麗に見せるため
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: ExpansionTile(
        // ヘッダー部分
        title: Row(
          children: [
            // 競馬場の頭文字アイコン
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  venueInitial,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 競馬場名と日付
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  venueRaces.venueName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  venueRaces.date,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
        // 展開されるレースリスト
        children: venueRaces.races.map((race) {
          return ListTile(
            dense: true,
            leading: SizedBox(
              width: 40,
              child: Text(
                race.raceNumber,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
            ),
            title: Text(race.raceName),
            subtitle: Text('${race.distance} / ${race.conditions}'),
            onTap: () {
              // TODO: レース詳細ページへの遷移ロジックを実装
              print('Tapped on race: ${race.raceName} (ID: ${race.raceId})');
            },
          );
        }).toList(),
      ),
    );
  }
}
