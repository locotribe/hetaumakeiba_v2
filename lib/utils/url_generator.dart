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

/// 競走馬のデータベースページURLを生成します。
/// [horseId] は競走馬のID（例: '2020101779'）です。
String generateNetkeibaHorseUrl({
  required String horseId,
}) {
  return 'https://db.netkeiba.com/horse/result/$horseId';
}

/// netkeibaのレース名検索ページのURLを生成します。
/// [raceName] は検索したいレース名（例: "札幌記念"）です。
Future<String> generateNetkeibaRaceSearchUrl({
  required String raceName,
}) async {
  // netkeiba.comの検索クエリはEUC-JPでエンコードする必要がある
  final eucJpBytes = await CharsetConverter.encode("EUC-JP", raceName);
  // バイトリストをパーセントエンコーディング形式の文字列に変換
  final encodedWord = eucJpBytes.map((byte) => '%${byte.toRadixString(16).toUpperCase().padLeft(2, '0')}').join('');
  return 'https://db.netkeiba.com/?pid=race_list&word=$encodedWord';
}