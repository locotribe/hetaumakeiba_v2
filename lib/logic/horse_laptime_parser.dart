// lib/logic/horse_laptime_parser.dart

import 'package:html/parser.dart' as html_parser;
import 'package:hetaumakeiba_v2/models/horse_past_race_extra_model.dart';

// [追加] 個別ラップ取得: db.sp.netkeiba の個別ラップページ（horse_laptime.html）の読み取り。
// HTML 文字列を受け取り結果を返すだけの純粋関数（通信・DB 保存はしない） (v.2026.9.23+26092304)

class HorseLapTimeParser {
  HorseLapTimeParser._();

  /// 個別ラップのカード（通常は [前走] の1枚）を読み、1走ごとの追加情報にする。
  /// 伏せ字（ラップがすべて 0.0）・race_id が読めないカードは入れない。
  static List<HorsePastRaceExtra> parse(String htmlText, String horseId,
      {String? fetchedAt}) {
    final document = html_parser.parse(htmlText);
    final result = <HorsePastRaceExtra>[];
    for (final card in document.querySelectorAll('[data-horse-lap-card]')) {
      final href =
          card.querySelector('a.HorseLapCard_RaceName')?.attributes['href'] ?? '';
      final raceId = RegExp(r'/race/(\d{12})').firstMatch(href)?.group(1);
      if (raceId == null) continue;
      final individualLaps = parseLaps(card.attributes['data-individual-laps']);
      if (individualLaps == null) continue;

      final splits = <String, double?>{};
      for (final dl in card.querySelectorAll('.LapCard_Splits dl')) {
        final label = (dl.querySelector('dt')?.text ?? '').trim();
        final value = double.tryParse(
            (dl.querySelector('.LapCard_SplitTime')?.text ?? '').trim());
        splits[label] = (value != null && value > 0) ? value : null;
      }
      final raceType = HorsePastRaceExtra.normalizeScrapedText(
          card.querySelector('.HorseLapCard_RaceType')?.text);

      result.add(HorsePastRaceExtra(
        horseId: horseId,
        raceId: raceId,
        individualFirst3f: splits['前半3F'],
        individualLast3f: splits['後半3F'],
        individualFirst5f: splits['前半5F'],
        individualLast5f: splits['後半5F'],
        individualLaps: individualLaps,
        raceLaps: parseLaps(card.attributes['data-race-laps']),
        lapRaceType: raceType,
        lapPageFetchedAt: fetchedAt,
      ));
    }
    return result;
  }

  /// 「12.7,11.4,…」をラップの配列にする。空・数字でない値を含む・すべて 0 のときは null。
  static List<double>? parseLaps(String? csv) {
    if (csv == null || csv.trim().isEmpty) return null;
    final laps = <double>[];
    for (final part in csv.split(',')) {
      final lap = double.tryParse(part.trim());
      if (lap == null) return null;
      laps.add(lap);
    }
    if (laps.isEmpty || laps.every((l) => l <= 0)) return null;
    return laps;
  }
}
