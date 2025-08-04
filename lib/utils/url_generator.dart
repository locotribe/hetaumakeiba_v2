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
  final dateParts = RegExp(r'(\d+)年(\d+)月(\d+)日').firstMatch(raceDate);
  String formattedDate = '';
  if (dateParts != null) {
    final year = dateParts.group(1)!;
    final month = dateParts.group(2)!.padLeft(2, '0');
    final day = dateParts.group(3)!.padLeft(2, '0');
    formattedDate = '$year$month$day';
  }

  // netkeibaの12桁IDからround部分(7-8文字目)を削除して10桁にする
  final raceIdWithoutRound = raceId.length == 12
      ? raceId.substring(0, 6) + raceId.substring(8)
      : raceId; // Fallback in case the ID format is unexpected

  final umaXRaceId = '$venueCode$raceIdWithoutRound$formattedDate';
  return 'https://uma-x.jp/race_card/$umaXRaceId';
}
