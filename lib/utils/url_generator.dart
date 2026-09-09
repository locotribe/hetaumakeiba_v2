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

/// 競走馬の血統ページURLを生成します。
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
  // [修正] netkeibaの検索仕様変更に合わせてエンドポイントを/race/list.htmlへ変更し、部分一致(match=p)パラメータを追加 (v.1.0)
  return 'https://db.netkeiba.com/race/list.html?word=$encodedWord&match=p';
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

/// 競馬新聞ページのURLを生成します（ブリンカー/外/地の取得用）。
String generateNewspaperUrl({required String raceId}) {
  return 'https://race.netkeiba.com/race/newspaper.html?race_id=$raceId&rf=shutuba_submenu';
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

// [修正] 日次データ(過去7日分と予報)のパラメータを追加 (v.3.0)
String generateOpenMeteoUrl({
  required double latitude,
  required double longitude,
}) {
  return 'https://api.open-meteo.com/v1/forecast?'
      'latitude=$latitude&'
      'longitude=$longitude&'
      'current=temperature_2m,relative_humidity_2m,precipitation,wind_speed_10m,wind_direction_10m,weather_code&'
      'hourly=temperature_2m,relative_humidity_2m,precipitation_probability,precipitation,wind_speed_10m,wind_direction_10m,weather_code,apparent_temperature,shortwave_radiation,et0_fao_evapotranspiration,wind_gusts_10m,visibility,soil_moisture_0_to_1cm&'
      'daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,et0_fao_evapotranspiration&'
      'past_days=7&'
      'timezone=Asia%2FTokyo';
}

/// netkeibaのオッズ一覧ページのURLを生成します。
/// [raceId] 202606030311 などの12桁のレースID
/// [oddsType] 取得したい券種のタイプ。
///   - 'b1': 単勝・複勝
///   - 'b4': 馬連
///   - 'b5': ワイド
///   - 'b6': 馬単
String generateOddsUrl({
  required String raceId,
  required String oddsType,
}) {
  // housiki=c0 と rf=shutuba_submenu は現状の仕様に合わせて固定で付与
  return 'https://race.netkeiba.com/odds/index.html?type=$oddsType&race_id=$raceId&housiki=c0&rf=shutuba_submenu';
}

// [追加] 過去レース検索の複数ワード(スペース区切り)AND詳細検索対応 (v.2026.9.9+26090903)
const Map<String, String> _pastRaceSearchJyoCodeMap = {
  '札幌': '01',
  '函館': '02',
  '福島': '03',
  '新潟': '04',
  '東京': '05',
  '中山': '06',
  '中京': '07',
  '京都': '08',
  '阪神': '09',
  '小倉': '10',
};

// [追加] 過去レース検索の複数ワード(スペース区切り)AND詳細検索対応 (v.2026.9.9+26090903)
const Map<String, String> _pastRaceSearchTrackCodeMap = {
  '芝': '1',
  'ダート': '2',
  '障害': '3',
};

/// [追加] "芝"/"ダ"/"障"などの表記ゆれを検索用の正式表記に正規化します (v.2026.9.9+26090903)
String normalizeTrackTypeLabel(String? raw) {
  switch (raw) {
    case '芝':
      return '芝';
    case 'ダ':
    case 'ダート':
      return 'ダート';
    case '障':
    case '障害':
      return '障害';
    default:
      return '';
  }
}

/// [追加] スペース区切りの検索クエリを解析し、レース名/開催場/馬場/距離の
/// AND詳細検索URLを生成します。既存の [generateNetkeibaRaceSearchUrl] はレース名検索専用として維持し、
/// この関数はそれとは別の新規エンドポイントとして追加しています (v.2026.9.9+26090902)
Future<String> generateNetkeibaRaceSearchUrlFromQuery({
  required String query,
}) async {
  final tokens = query.split(RegExp(r'[\s　]+')).where((t) => t.isNotEmpty);

  final List<String> trackCodes = [];
  final List<String> jyoCodes = [];
  final List<String> kyoriValues = [];
  final List<String> raceNameTokens = [];

  for (final token in tokens) {
    if (RegExp(r'^\d{4}$').hasMatch(token)) {
      kyoriValues.add(token);
      continue;
    }

    final normalizedTrack = normalizeTrackTypeLabel(token);
    if (normalizedTrack.isNotEmpty && _pastRaceSearchTrackCodeMap.containsKey(normalizedTrack)) {
      trackCodes.add(_pastRaceSearchTrackCodeMap[normalizedTrack]!);
      continue;
    }

    final jyoKey = token.endsWith('競馬場')
        ? token.substring(0, token.length - '競馬場'.length)
        : token;
    if (_pastRaceSearchJyoCodeMap.containsKey(jyoKey)) {
      jyoCodes.add(_pastRaceSearchJyoCodeMap[jyoKey]!);
      continue;
    }

    raceNameTokens.add(token);
  }

  final String raceNameQuery = raceNameTokens.join(' ');
  final String encodedWord;
  if (raceNameQuery.isEmpty) {
    encodedWord = '';
  } else {
    final eucJpBytes = await CharsetConverter.encode("EUC-JP", raceNameQuery);
    encodedWord = eucJpBytes.map((byte) => '%${byte.toRadixString(16).toUpperCase().padLeft(2, '0')}').join('');
  }

  final buffer = StringBuffer('https://db.netkeiba.com/race/list.html?word=$encodedWord&match=p');

  for (final code in trackCodes) {
    buffer.write('&track%5B%5D=$code');
  }
  for (final code in jyoCodes) {
    buffer.write('&jyo%5B%5D=$code');
  }
  for (final value in kyoriValues) {
    buffer.write('&kyori%5B%5D=$value');
  }

  buffer.write('&sort=date-desc&limit=20');

  return buffer.toString();
}