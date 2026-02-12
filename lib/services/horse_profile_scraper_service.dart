// lib/services/horse_profile_scraper_service.dart

import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html;
import 'package:html/dom.dart' as dom;
import 'package:charset_converter/charset_converter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/models/horse_profile_model.dart';
import 'package:hetaumakeiba_v2/utils/url_generator.dart';

class HorseProfileScraperService {
  static const Map<String, String> _headers = {
    'User-Agent':
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/108.0.0.0 Safari/537.36',
    'x-requested-with': 'XMLHttpRequest',
  };

  /// 指定された馬IDのプロフィール（基本情報、馬主画像、血統）を取得し、DBに保存します。
  static Future<HorseProfile?> scrapeAndSaveProfile(String horseId) async {
    print('DEBUG: scrapeAndSaveProfile START for ID: $horseId');
    try {
      // ★修正: プロフィール取得専用のURLを使用 (/result/なし)
      final url = generateNetkeibaHorseProfileUrl(horseId: horseId);
      print('DEBUG: Requesting URL: $url');

      final response = await http.get(Uri.parse(url), headers: _headers);

      if (response.statusCode != 200) {
        print('DEBUG: [ERROR] Failed to fetch profile. Status: ${response.statusCode}');
        return null;
      }

      final decodedBody = await CharsetConverter.decode('EUC-JP', response.bodyBytes);
      final document = html.parse(decodedBody);

      // 1. 基本情報の解析
      final profileData = await _parseBasicInfo(horseId, document);
      print('DEBUG: Basic info parsed: $profileData');

      // 2. 血統情報の解析
      final pedigreeData = _parsePedigree(document);

      // 3. データの結合と保存
      final profile = HorseProfile(
        horseId: horseId,
        horseName: profileData['horseName'] ?? '',
        birthday: profileData['birthday'] ?? '',
        ownerId: profileData['ownerId'] ?? '',
        ownerName: profileData['ownerName'] ?? '',
        ownerImageLocalPath: profileData['ownerImageLocalPath'] ?? '',
        trainerId: profileData['trainerId'] ?? '',
        trainerName: profileData['trainerName'] ?? '',
        breederName: profileData['breederName'] ?? '',
        fatherId: pedigreeData['fatherId'] ?? '',
        fatherName: pedigreeData['fatherName'] ?? '',
        motherId: pedigreeData['motherId'] ?? '',
        motherName: pedigreeData['motherName'] ?? '',
        ffName: pedigreeData['ffName'] ?? '',
        fmName: pedigreeData['fmName'] ?? '',
        mfName: pedigreeData['mfName'] ?? '',
        mmName: pedigreeData['mmName'] ?? '',
        lastUpdated: DateTime.now().toIso8601String(),
      );

      print('DEBUG: Saving profile to DB... (Owner Image Path: ${profile.ownerImageLocalPath})');
      await DatabaseHelper().insertOrUpdateHorseProfile(profile);
      print('DEBUG: scrapeAndSaveProfile END (Success) for $horseId');
      return profile;

    } catch (e, stackTrace) {
      print('DEBUG: [ERROR] scrapeAndSaveProfile exception ($horseId): $e');
      print('DEBUG: StackTrace: $stackTrace');
      return null;
    }
  }

  /// 基本情報（馬名、馬主、調教師、画像など）の解析
  static Future<Map<String, String>> _parseBasicInfo(String horseId, dom.Document document) async {
    final Map<String, String> result = {};

    // 馬名
    String horseName = document.querySelector('div.horse_title h1')?.text.trim() ?? '';
    result['horseName'] = horseName.replaceAll(RegExp(r'\s+'), '');

    String ownerId = '';
    String ownerName = '';
    String ownerImageUrl = '';

    // 【重要】全リンクから馬主IDを検索
    final allLinks = document.querySelectorAll('a');
    for (final link in allLinks) {
      final href = link.attributes['href'];
      if (href != null && href.contains('/owner/')) {
        final match = RegExp(r'/owner/(\d+)').firstMatch(href);
        if (match != null) {
          ownerId = match.group(1)!;
          ownerName = link.text.trim();
          print('DEBUG: Found ownerId: $ownerId, Name: $ownerName');
          break; // 最初に見つかったものを採用
        }
      }
    }

    // IDが取れたらURL生成
    if (ownerId.isNotEmpty) {
      ownerImageUrl = 'https://cdn.netkeiba.com/img//db/colours/$ownerId.gif';
      print('DEBUG: Constructed Owner Image URL: $ownerImageUrl');
    } else {
      // バックアップ検索
      final ownerImg = document.querySelector('img.OwnerColours');
      if (ownerImg != null) {
        ownerImageUrl = ownerImg.attributes['src'] ?? '';
        ownerName = ownerImg.attributes['alt'] ?? '';
        print('DEBUG: Found owner image via img tag: $ownerImageUrl');
      }
    }

    result['ownerId'] = ownerId;
    result['ownerName'] = ownerName;

    // その他の情報
    final thList = document.querySelectorAll('th');
    for (final th in thList) {
      final headerText = th.text.trim();
      final td = th.nextElementSibling;
      if (td == null) continue;

      if (headerText == '生年月日') {
        result['birthday'] = td.text.trim();
      } else if (headerText == '調教師') {
        result['trainerName'] = td.querySelector('a')?.text.trim() ?? td.text.trim();
        final href = td.querySelector('a')?.attributes['href'];
        if (href != null) {
          final match = RegExp(r'/trainer/(\d+)/').firstMatch(href);
          if (match != null) result['trainerId'] = match.group(1)!;
        }
      } else if (headerText == '生産者') {
        result['breederName'] = td.text.trim();
      }
    }

    // 画像のダウンロード
    if (ownerImageUrl.isNotEmpty && ownerId.isNotEmpty) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final saveDir = Directory('${dir.path}/owner_images');
        if (!await saveDir.exists()) {
          await saveDir.create(recursive: true);
        }
        final filePath = '${saveDir.path}/owner_$ownerId.gif';
        final file = File(filePath);

        // ファイルがあっても上書きダウンロードするか、存在確認するか
        // デバッグのため、一旦毎回ダウンロードを試みる（もしくは存在確認ログを出す）
        if (await file.exists()) {
          print('DEBUG: Image file already exists at: $filePath');
          result['ownerImageLocalPath'] = filePath;
        } else {
          print('DEBUG: Downloading image from $ownerImageUrl');
          final imageResponse = await http.get(Uri.parse(ownerImageUrl), headers: _headers);
          if (imageResponse.statusCode == 200 && imageResponse.bodyBytes.isNotEmpty) {
            await file.writeAsBytes(imageResponse.bodyBytes);
            print('DEBUG: Image saved to $filePath, size: ${imageResponse.bodyBytes.length}');
            result['ownerImageLocalPath'] = filePath;
          } else {
            print('DEBUG: [ERROR] Image download failed. Status: ${imageResponse.statusCode}');
          }
        }
      } catch (e) {
        print('DEBUG: [ERROR] Image save error: $e');
      }
    } else {
      print('DEBUG: Skipping image download (URL or OwnerID empty)');
    }

    return result;
  }

  /// 血統情報の解析
  static Map<String, String> _parsePedigree(dom.Document document) {
    final Map<String, String> result = {};
    final bloodTable = document.querySelector('table.blood_table');

    if (bloodTable != null) {
      final rows = bloodTable.querySelectorAll('tr');
      if (rows.isNotEmpty) {
        // 父
        final fTd = rows[0].querySelector('td');
        if (fTd != null) {
          result['fatherName'] = fTd.querySelector('a')?.text.trim() ?? fTd.text.trim();
          final href = fTd.querySelector('a')?.attributes['href'];
          if (href != null) {
            final match = RegExp(r'/horse/ped/(\w+)/').firstMatch(href);
            if (match != null) result['fatherId'] = match.group(1)!;
          }
          final tds = rows[0].querySelectorAll('td');
          if (tds.length > 1) {
            result['ffName'] = tds[1].querySelector('a')?.text.trim() ?? tds[1].text.trim();
          }
        }
        // 父母
        if (rows.length > 8) {
          final fmTd = rows[8].querySelector('td');
          if (fmTd != null) {
            result['fmName'] = fmTd.querySelector('a')?.text.trim() ?? fmTd.text.trim();
          }
        }
        // 母
        if (rows.length > 16) {
          final mTd = rows[16].querySelector('td');
          if (mTd != null) {
            result['motherName'] = mTd.querySelector('a')?.text.trim() ?? mTd.text.trim();
            final href = mTd.querySelector('a')?.attributes['href'];
            if (href != null) {
              final match = RegExp(r'/horse/ped/(\w+)/').firstMatch(href);
              if (match != null) result['motherId'] = match.group(1)!;
            }
            final tds = rows[16].querySelectorAll('td');
            if (tds.length > 1) {
              result['mfName'] = tds[1].querySelector('a')?.text.trim() ?? tds[1].text.trim();
            }
          }
        }
        // 母母
        if (rows.length > 24) {
          final mmTd = rows[24].querySelector('td');
          if (mmTd != null) {
            result['mmName'] = mmTd.querySelector('a')?.text.trim() ?? mmTd.text.trim();
          }
        }
      }
    }
    return result;
  }
}