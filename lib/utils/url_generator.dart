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