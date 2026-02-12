// lib/services/horse_performance_scraper_service.dart

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html;
import 'package:html/dom.dart' as dom;
import 'package:charset_converter/charset_converter.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/utils/url_generator.dart';
import 'package:hetaumakeiba_v2/services/race_result_scraper_service.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/models/horse_profile_model.dart';

class HorsePerformanceScraperService {
  static const Map<String, String> _headers = {
    'User-Agent':
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/108.0.0.0 Safari/537.36',
    'x-requested-with': 'XMLHttpRequest',
  };

  /// netkeiba.comの競走馬データベースページをスクレイピングし、競走成績のリストを返します。
  static Future<List<HorseRaceRecord>> scrapeHorsePerformance(String horseId) async {
    try {
      final url = generateNetkeibaHorseUrl(horseId: horseId);
      final response = await http.get(Uri.parse(url), headers: _headers);

      if (response.statusCode != 200) {
        throw Exception(
            'HTTPリクエストに失敗しました: Status code ${response.statusCode} for horse ID $horseId');
      }

      final decodedBody =
      await CharsetConverter.decode('EUC-JP', response.bodyBytes);
      final document = html.parse(decodedBody);
      // プロフィール情報の取得と保存 (エラーが起きても戦績取得は継続する)
      try {
        await _scrapeAndSaveProfile(horseId, document);
      } catch (e) {
        print('プロフィール保存エラー: $e');
      }

      final List<HorseRaceRecord> records = [];
      final table =
      document.querySelector('table.db_h_race_results.nk_tb_common');

      if (table == null) {
        print('警告: 競走馬ID $horseId の競走成績テーブルが見つかりませんでした。');
        return [];
      }

      final rows = table.querySelectorAll('tbody tr');

      for (final row in rows) {
        final cells = row.querySelectorAll('td');
        if (cells.length < 29) {
          continue;
        }

        final raceNameLink = cells[4].querySelector('a');
        final raceHref = raceNameLink?.attributes['href'];
        final raceId = raceHref != null
            ? RaceResultScraperService.getRaceIdFromUrl(raceHref) ?? ''
            : '';
        final jockeyLink = cells[12].querySelector('a');
        final jockeyHref = jockeyLink?.attributes['href'];
        final jockeyId = jockeyHref != null
            ? jockeyHref.split('/').firstWhere(
                (s) => RegExp(r'^\d{5}$').hasMatch(s), orElse: () => '')
            : '';
        records.add(HorseRaceRecord(
          horseId: horseId,
          raceId: raceId,
          date: cells[0].text.trim(),
          venue: cells[1].text.trim(),
          weather: cells[2].text.trim(),
          raceNumber: cells[3].text.trim(),
          raceName: raceNameLink?.text.trim() ?? '',
          numberOfHorses: cells[6].text.trim(),
          frameNumber: cells[7].text.trim(),
          horseNumber: cells[8].text.trim(),
          odds: cells[9].text.trim(),
          popularity: cells[10].text.trim(),
          rank: cells[11].text.trim(),
          jockey: jockeyLink?.text.trim() ?? '',
          jockeyId: jockeyId,
          carriedWeight: cells[13].text.trim(),
          distance: cells[14].text.trim(),
          trackCondition: cells[16].text.trim(),
          time: cells[18].text.trim(),
          margin: cells[19].text.trim(),
          cornerPassage: cells[21].text.trim(),
          pace: cells[22].text.trim(),
          agari: cells[23].text.trim(),
          horseWeight: cells[24].text.trim(),
          winnerOrSecondHorse: cells[27].querySelector('a')?.text.trim() ?? '',
          prizeMoney: cells[28].text.trim(),
        ));
      }
      return records;
    } catch (e) {
      print('[ERROR]競走馬ID $horseId の競走成績スクレイピング中にエラーが発生しました: $e');
      rethrow;
    }
  }
// プロフィール取得・保存ロジック
  static Future<void> _scrapeAndSaveProfile(String horseId, dom.Document document) async {
    // 1. プロフィールテーブルの解析
    final profTable = document.querySelector('table.db_prof_table');
    String horseName = document.querySelector('div.horse_title h1')?.text.trim() ?? '';
    // 全角スペースなどを削除
    horseName = horseName.replaceAll(RegExp(r'\s+'), '');

    String birthday = '';
    String trainerId = '';
    String trainerName = '';
    String ownerId = '';
    String ownerName = '';
    String breederName = '';
    String ownerImageUrl = '';

    if (profTable != null) {
      final rows = profTable.querySelectorAll('tr');
      for (final row in rows) {
        final th = row.querySelector('th')?.text.trim();
        final td = row.querySelector('td');
        if (th == null || td == null) continue;

        if (th == '生年月日') {
          birthday = td.text.trim();
        } else if (th == '調教師') {
          trainerName = td.querySelector('a')?.text.trim() ?? td.text.trim();
          final href = td.querySelector('a')?.attributes['href'];
          if (href != null) {
            final match = RegExp(r'/trainer/(\d+)/').firstMatch(href);
            if (match != null) trainerId = match.group(1)!;
          }
        } else if (th == '馬主') {
          ownerName = td.querySelector('a')?.text.trim() ?? td.text.trim();
          final href = td.querySelector('a')?.attributes['href'];
          if (href != null) {
            final match = RegExp(r'/owner/(\d+)/').firstMatch(href);
            if (match != null) ownerId = match.group(1)!;
          }
          final img = td.querySelector('img');
          if (img != null) {
            ownerImageUrl = img.attributes['src'] ?? '';
          }
        } else if (th == '生産者') {
          breederName = td.text.trim();
        }
      }
    }

    // 2. 勝負服画像のダウンロードと保存
    String ownerImageLocalPath = '';
    if (ownerImageUrl.isNotEmpty && ownerId.isNotEmpty) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final saveDir = Directory('${dir.path}/owner_images');
        if (!await saveDir.exists()) {
          await saveDir.create(recursive: true);
        }
        final filePath = '${saveDir.path}/owner_$ownerId.gif';
        final file = File(filePath);

        // ファイルが既に存在する場合はダウンロードをスキップ（更新頻度は低いため）
        if (!await file.exists()) {
          final imageResponse = await http.get(Uri.parse(ownerImageUrl), headers: _headers);
          if (imageResponse.statusCode == 200) {
            await file.writeAsBytes(imageResponse.bodyBytes);
            ownerImageLocalPath = filePath;
          }
        } else {
          ownerImageLocalPath = filePath;
        }
      } catch (e) {
        print('勝負服画像保存エラー: $e');
      }
    }

    // 3. 血統テーブルの解析 (5代血統表を想定: 32行)
    final bloodTable = document.querySelector('table.blood_table');
    String fatherId = '';
    String fatherName = '';
    String motherId = '';
    String motherName = '';
    String ffName = '';
    String fmName = '';
    String mfName = '';
    String mmName = '';

    if (bloodTable != null) {
      final rows = bloodTable.querySelectorAll('tr');
      // 行数が足りない場合のガード
      if (rows.isNotEmpty) {
        // 父: 1行目 1列目
        final fTd = rows[0].querySelector('td');
        if (fTd != null) {
          fatherName = fTd.querySelector('a')?.text.trim() ?? fTd.text.trim();
          final href = fTd.querySelector('a')?.attributes['href'];
          if (href != null) {
            final match = RegExp(r'/horse/ped/(\w+)/').firstMatch(href);
            if (match != null) fatherId = match.group(1)!;
          }
          // 父父: 1行目 2列目 (rowspanがあるためHTML構造上は同じ行の次のtd)
          // ただしrowspanの実装依存なので、tdのリストから取得
          final tds = rows[0].querySelectorAll('td');
          if (tds.length > 1) {
            ffName = tds[1].querySelector('a')?.text.trim() ?? tds[1].text.trim();
          }
        }

        // 父母: 9行目 (index 8) 1列目 (父のrowspanが16の場合、その半分の位置)
        // 注: netkeibaの血統表は通常 rowspan=16, 8, 4... となる
        if (rows.length > 8) {
          final fmTd = rows[8].querySelector('td');
          if (fmTd != null) {
            fmName = fmTd.querySelector('a')?.text.trim() ?? fmTd.text.trim();
          }
        }

        // 母: 17行目 (index 16) 1列目
        if (rows.length > 16) {
          final mTd = rows[16].querySelector('td');
          if (mTd != null) {
            motherName = mTd.querySelector('a')?.text.trim() ?? mTd.text.trim();
            final href = mTd.querySelector('a')?.attributes['href'];
            if (href != null) {
              final match = RegExp(r'/horse/ped/(\w+)/').firstMatch(href);
              if (match != null) motherId = match.group(1)!;
            }
            // 母父: 17行目 2列目
            final tds = rows[16].querySelectorAll('td');
            if (tds.length > 1) {
              mfName = tds[1].querySelector('a')?.text.trim() ?? tds[1].text.trim();
            }
          }
        }

        // 母母: 25行目 (index 24) 1列目
        if (rows.length > 24) {
          final mmTd = rows[24].querySelector('td');
          if (mmTd != null) {
            mmName = mmTd.querySelector('a')?.text.trim() ?? mmTd.text.trim();
          }
        }
      }
    }

    // 4. DBへの保存
    final profile = HorseProfile(
      horseId: horseId,
      horseName: horseName,
      birthday: birthday,
      ownerId: ownerId,
      ownerName: ownerName,
      ownerImageLocalPath: ownerImageLocalPath,
      trainerId: trainerId,
      trainerName: trainerName,
      breederName: breederName,
      fatherId: fatherId,
      fatherName: fatherName,
      motherId: motherId,
      motherName: motherName,
      ffName: ffName,
      fmName: fmName,
      mfName: mfName,
      mmName: mmName,
      lastUpdated: DateTime.now().toIso8601String(),
    );

    await DatabaseHelper().insertOrUpdateHorseProfile(profile);
  }
}