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

/// 競走馬の戦績ページURLを生成します（レース結果一覧用）。
/// [horseId] は競走馬のID（例: '2020101779'）です。
String generateNetkeibaHorseUrl({
  required String horseId,
}) {
  return 'https://db.netkeiba.com/horse/result/$horseId';
}

/// ★追加: 競走馬のプロフィール（トップ）ページURLを生成します。
/// 画像や基本情報はこちらのページから取得します。
String generateNetkeibaHorseProfileUrl({
  required String horseId,
}) {
  return 'https://db.netkeiba.com/horse/$horseId/';
}

/// netkeibaのレース名検索ページのURLを生成します。
/// [raceName] は検索したいレース名（例: "札幌記念"）です。
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

// ===========================================================================
// ▼ 新規追加: 調教データ取得(pakara-keiba)関連のURL/パラメータ生成ロジック
// ===========================================================================

// JRA場コード(01-10)からpakara-keibaの場コードへの変換マップ
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

/// pakara-keibaの調教API用リクエストパラメータ(body)を生成します。
/// [raceId] はJRA形式の12桁レースID
/// [raceDate] はYYYYMMDD形式の開催日
/// [horseIds] は対象レースに出走する全馬のIDリスト
Map<String, String> generatePakaraApiParams({
  required String raceId,
  required String raceDate,
  required List<String> horseIds,
}) {
  final jraPlaceCode = raceId.substring(4, 6); // 5〜6桁目がJRAの場コード
  final round = int.parse(raceId.substring(10, 12)).toString(); // 11〜12桁目がレース番号
  final sitePlaceCode = jraToPakaraPlaceMap[jraPlaceCode] ?? '0'; // デフォルトは0(東京)としてフォールバック

  final Map<String, String> params = {
    "date": raceDate,
    "place": sitePlaceCode,
    "round": round,
  };

  // 馬IDを name0, name1, name2... の形式でセット
  for (int i = 0; i < horseIds.length; i++) {
    params["name$i"] = horseIds[i];
  }

  return params;
}

/// pakara-keibaの坂路調教データ取得APIのエンドポイントURLを返します。
String getPakaraHanroApiUrl() {
  return 'https://pakara-keiba.com/ajax/race/get_cyoukyou.php';
}

/// pakara-keibaのウッド調教データ取得APIのエンドポイントURLを返します。
String getPakaraWoodApiUrl() {
  return 'https://pakara-keiba.com/ajax/race/get_cyoukyou_wc.php';
}