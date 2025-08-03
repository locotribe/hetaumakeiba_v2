// lib/utils/url_generator.dart

const Map<String, String> umaXVenueCodes = {
  '札幌': '1',
  '函館': '2',
  '福島': '3',
  '新潟': '4',
  '東京': '5',
  '中山': '6',
  '中京': '7',
  '京都': '8',
  '阪神': '9',
  '小倉': '10',
};

String generateNetkeibaUrl({
  required String year,
  required String racecourseCode,
  required String round,
  required String day,
  required String race,
}) {
  final suffix = [year, racecourseCode, round, day, race]
      .map((e) => e.toString().padLeft(2, '0'))
      .join();
  return 'https://db.netkeiba.com/race/20$suffix';
}

/// 競走馬のデータベースページURLを生成します。
/// [horseId] は競走馬のID（例: '2020101779'）です。
String generateNetkeibaHorseUrl({
  required String horseId,
}) {
  return 'https://db.netkeiba.com/horse/result/$horseId';
}

String generateUmaXShutubaUrl({
  required String raceId,
  required String raceDate, // "2025年8月3日" の形式
  required String venue,    // "新潟" の形式
}) {
  final venueCode = umaXVenueCodes[venue] ?? '';
  // "2025年8月3日" -> "20250803"
  final formattedDate = raceDate.replaceAll(RegExp(r'[年月]'), '').replaceAll('日', '').padLeft(8, '0');

  final umaXRaceId = '$venueCode$raceId$formattedDate';
  return 'https://uma-x.jp/race_result/$umaXRaceId';
}