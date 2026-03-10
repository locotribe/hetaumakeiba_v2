// lib/utils/url_generator.dart

import 'package:charset_converter/charset_converter.dart';

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

/// レース結果詳細ページ（DB）のURLを生成します。
String generateRaceResultUrl(String raceId) {
  return 'https://db.netkeiba.com/race/$raceId';
}

/// 競走馬の戦績ページURLを生成します（レース結果一覧用）。
String generateNetkeibaHorseUrl({
  required String horseId,
}) {
  return 'https://db.netkeiba.com/horse/result/$horseId';
}

/// 競走馬のプロフィール（トップ）ページURLを生成します。
String generateNetkeibaHorseProfileUrl({
  required String horseId,
}) {
  return 'https://db.netkeiba.com/horse/$horseId/';
}

/// ★追加: 競走馬の血統ページURLを生成します。
String generateNetkeibaHorsePedigreeUrl({
  required String horseId,
}) {
  return 'https://db.netkeiba.com/horse/ped/$horseId/';
}

/// netkeibaのレース名検索ページのURLを生成します。
Future<String> generateNetkeibaRaceSearchUrl({
  required String raceName,
}) async {
  final eucJpBytes = await CharsetConverter.encode("EUC-JP", raceName);
  final encodedWord = eucJpBytes.map((byte) => '%${byte.toRadixString(16).toUpperCase().padLeft(2, '0')}').join('');
  return 'https://db.netkeiba.com/?pid=race_list&word=$encodedWord';
}

String generateRaceListUrl(DateTime date) {
  final year = date.year.toString();
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  final yyyymmdd = '$year$month$day';
  return 'https://race.netkeiba.com/top/race_list.html?kaisai_date=$yyyymmdd';
}

String generateShutubaUrl({required String raceId, String type = 'shutuba'}) {
  return 'https://race.netkeiba.com/race/$type.html?race_id=$raceId';
}

const Map<String, String> jraToPakaraPlaceMap = {
  '05': '0', // 東京
  '06': '1', // 中山
  '08': '2', // 京都
  '09': '3', // 阪神
  '04': '4', // 新潟
  '02': '5', // 函館
  '03': '6', // 福島
  '07': '7', // 中京
  '10': '8', // 小倉
  '01': '9', // 札幌
};

Map<String, String> generatePakaraApiParams({
  required String raceId,
  required String raceDate,
  required List<String> horseIds,
}) {
  final jraPlaceCode = raceId.substring(4, 6);
  final round = int.parse(raceId.substring(10, 12)).toString();
  final sitePlaceCode = jraToPakaraPlaceMap[jraPlaceCode] ?? '0';

  final Map<String, String> params = {
    "date": raceDate,
    "place": sitePlaceCode,
    "round": round,
  };

  for (int i = 0; i < horseIds.length; i++) {
    params["name$i"] = horseIds[i];
  }

  return params;
}

String getPakaraHanroApiUrl() {
  return 'https://pakara-keiba.com/ajax/race/get_cyoukyou.php';
}

String getPakaraWoodApiUrl() {
  return 'https://pakara-keiba.com/ajax/race/get_cyoukyou_wc.php';
}

String generateOpenMeteoUrl({
  required double latitude,
  required double longitude,
}) {
  return 'https://api.open-meteo.com/v1/forecast?'
      'latitude=$latitude&'
      'longitude=$longitude&'
      'current=temperature_2m,relative_humidity_2m,precipitation,wind_speed_10m,wind_direction_10m,weather_code&'
      'hourly=temperature_2m,relative_humidity_2m,precipitation_probability,precipitation,wind_speed_10m,wind_direction_10m,weather_code,apparent_temperature,shortwave_radiation,et0_fao_evapotranspiration,wind_gusts_10m,visibility,soil_moisture_0_to_1cm&'
      'timezone=Asia%2FTokyo';
}