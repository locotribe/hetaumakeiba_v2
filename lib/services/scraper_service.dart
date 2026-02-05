// lib/services/scraper_service.dart

import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html;
import 'package:html/dom.dart' as dom;
import 'package:hetaumakeiba_v2/models/featured_race_model.dart';
import 'package:hetaumakeiba_v2/utils/url_generator.dart';
import 'package:charset_converter/charset_converter.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/models/shutuba_horse_detail_model.dart';
import 'dart:convert';
import 'package:hetaumakeiba_v2/models/ai_prediction_race_data.dart';
import 'package:hetaumakeiba_v2/services/race_result_scraper_service.dart';
import 'package:hetaumakeiba_v2/services/horse_performance_scraper_service.dart';
// ★追加: リポジトリのインポート
import 'package:hetaumakeiba_v2/repositories/race_data_repository.dart';

class ScraperService {

  static const Map<String, String> _headers = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/108.0.0.0 Safari/537.36',
    'x-requested-with': 'XMLHttpRequest',
  };

  static Future<List<FeaturedRace>> scrapeFeaturedRaces(DatabaseHelper dbHelper) async {
    final List<FeaturedRace> featuredRaces = [];
    try {
      const url = 'https://tospo-keiba.jp/';
      final response = await http.get(Uri.parse(url), headers: _headers);

      if (response.statusCode != 200) {
        throw Exception('HTTPリクエストに失敗しました: Status code ${response.statusCode} for featured races.');
      }

      final document = html.parse(response.body);

      final raceIds = <String>{};

      final topMainElement = document.querySelector('top-main');
      if (topMainElement != null) {
        final sideDataAttribute = topMainElement.attributes[':side'];
        if (sideDataAttribute != null) {
          try {
            final sideData = json.decode(sideDataAttribute);
            final gradedRaceInfoList = sideData['raceData']['gradedRaceInfo'] as List<dynamic>?;

            if (gradedRaceInfoList != null) {
              for (final raceInfo in gradedRaceInfoList) {
                final raceIdObject = raceInfo['id'];
                if (raceIdObject != null) {
                  raceIds.add(raceIdObject.toString());
                }
              }
            }
          } catch (e) {
            print("DEBUG: scrapeFeaturedRaces - JSONのパースに失敗しました。: $e");
          }
        }
      }

      if (raceIds.isEmpty) {
        print("DEBUG: scrapeFeaturedRaces - JSONからのレースID抽出に失敗またはデータが空です。HTMLのリンクから抽出を試みます。");
        final raceLinks = document.querySelectorAll('a[href*="/race/"]');
        final raceIdPattern = RegExp(r'/race/(\d{12})');

        for (final link in raceLinks) {
          final href = link.attributes['href'];
          if (href != null) {
            final match = raceIdPattern.firstMatch(href);
            if (match != null) {
              final raceId = match.group(1);
              if (raceId != null) {
                raceIds.add(raceId);
              }
            }
          }
        }
      }

      final uniqueRaceIds = raceIds.toList();

      if (uniqueRaceIds.isEmpty) {
        print("DEBUG: scrapeFeaturedRaces - レースIDが見つかりませんでした。");
      } else {
        print("DEBUG: scrapeFeaturedRaces - 抽出したレースID: $uniqueRaceIds");
      }

      for (final raceId in uniqueRaceIds) {
        final existingRace = await dbHelper.getFeaturedRace(raceId);
        if (existingRace != null && existingRace.lastScraped.isAfter(DateTime.now().subtract(const Duration(hours: 1)))) {
          featuredRaces.add(existingRace);
          continue;
        }

        final shutubaRaceDetails = await scrapeShutubaPageDetails(raceId);
        if (shutubaRaceDetails != null) {
          // ※FeaturedRaceの保存も本来Repositoryに移動すべきですが、今回は主要データ整合性を優先し既存維持
          await dbHelper.insertOrUpdateFeaturedRace(shutubaRaceDetails);
          featuredRaces.add(shutubaRaceDetails);
        }
      }
      return featuredRaces;
    } catch (e) {
      print('[ERROR]注目レースのスクレイピング中にエラーが発生しました: $e');
      return [];
    }
  }

  static Future<FeaturedRace?> scrapeShutubaPageDetails(String raceId) async {
    try {
      final url = 'https://race.netkeiba.com/race/shutuba.html?race_id=$raceId';
      final response = await http.get(Uri.parse(url), headers: _headers);

      if (response.statusCode != 200) {
        print('[ERROR]HTTPリクエストに失敗しました: Status code ${response.statusCode} for shutuba page $raceId');
        return null;
      }

      final decodedBody = await CharsetConverter.decode('EUC-JP', response.bodyBytes);
      final document = html.parse(decodedBody);

      return _parseFeaturedRaceFromDocument(document, raceId, url);
    } catch (e) {
      print('[ERROR]出馬表ページ $raceId のスクレイピング中にエラーが発生しました: $e');
      return null;
    }
  }

  static String _safeGetText(dom.Element? element) {
    return element?.text.trim() ?? '';
  }

  static Future<List<FeaturedRace>> scrapeMonthlyGradedRaces() async {
    try {
      return await _scrapeGradedRacesFromSchedulePage();
    } catch (e) {
      print('[ERROR]ニュースフィードのデータ取得中にエラーが発生しました: $e');
      return [];
    }
  }

  static Future<List<String>> extractHorseIdsFromShutubaPage(String shutubaTableUrl) async {
    final List<String> horseIds = [];
    try {
      final response = await http.get(Uri.parse(shutubaTableUrl), headers: _headers);

      if (response.statusCode != 200) {
        print('HTTPリクエストに失敗しました: Status code ${response.statusCode} for shutuba page $shutubaTableUrl');
        return [];
      }

      final decodedBody = await CharsetConverter.decode('EUC-JP', response.bodyBytes);
      final document = html.parse(decodedBody);

      final horseLinks = document.querySelectorAll('table.Shutuba_Table td.HorseInfo a[href*="/horse/"]');

      for (final link in horseLinks) {
        final href = link.attributes['href'];
        if (href != null) {
          final horseId = href.split('/').lastWhere((part) => part.isNotEmpty, orElse: () => '');
          if (horseId.isNotEmpty) {
            horseIds.add(horseId);
          }
        }
      }
      return horseIds.toSet().toList();
    } catch (e) {
      print('[ERROR]出馬表ページからのホースID抽出中にエラーが発生しました: $e');
      return [];
    }
  }

  static Future<void> syncNewHorseData(List<FeaturedRace> races, DatabaseHelper dbHelper) async {
    print('[Horse Data Sync Start] 競走馬データの同期を開始します...');
    try {
      for (final race in races) {
        final List<String> horseIdsToSync = [];
        if (race.shutubaHorses != null && race.shutubaHorses!.isNotEmpty) {
          horseIdsToSync.addAll(race.shutubaHorses!.map((h) => h.horseId));
        } else {
          horseIdsToSync.addAll(await ScraperService.extractHorseIdsFromShutubaPage(race.shutubaTableUrl));
        }

        for (final horseId in horseIdsToSync.toSet()) {
          final existingRecord = await dbHelper.getLatestHorsePerformanceRecord(horseId);
          if (existingRecord != null && existingRecord.raceId.isNotEmpty) {
            continue;
          }
          print('競走馬データ取得/更新中... Horse ID: $horseId');
          final newRecords = await HorsePerformanceScraperService.scrapeHorsePerformance(horseId);

          // ★修正: リポジトリ経由で保存（一括保存）
          await RaceDataRepository().saveHorsePerformanceList(newRecords);

          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    } catch (e) {
      print('[Horse Data Sync Error] 競走馬のデータ同期中にエラーが発生しました: $e');
    }
    print('[Horse Data Sync End] 競走馬データの同期が完了しました。');
  }

  static Future<List<FeaturedRace>> _scrapeGradedRacesFromSchedulePage() async {
    const url = 'https://race.netkeiba.com/top/schedule.html';
    final List<FeaturedRace> gradedRaces = [];

    final response = await http.get(Uri.parse(url), headers: _headers);
    if (response.statusCode != 200) {
      print('重賞日程ページの取得に失敗しました: Status code ${response.statusCode}');
      return [];
    }

    final decodedBody = await CharsetConverter.decode('EUC-JP', response.bodyBytes);
    final document = html.parse(decodedBody);

    final rows = document.querySelectorAll('table.race_table_01 tr');

    for (final row in rows) {
      final cells = row.querySelectorAll('td');
      if (cells.length < 7) continue;

      try {
        final dateStr = _safeGetText(cells[0]);
        final raceNameElement = cells[1].querySelector('a');
        final raceName = raceNameElement != null ? _safeGetText(raceNameElement) : _safeGetText(cells[1]);
        final link = cells[1].querySelector('a')?.attributes['href'] ?? '';
        final raceId = 'monthly_${dateStr.replaceAll(RegExp(r'[/\(\)]'), '')}_${raceName.replaceAll(' ', '')}';

        gradedRaces.add(FeaturedRace(
          raceId: raceId,
          raceName: raceName,
          raceGrade: _safeGetText(cells[2]),
          venue: _safeGetText(cells[3]),
          distance: _safeGetText(cells[4]),
          conditions: _safeGetText(cells[5]),
          weight: _safeGetText(cells[6]),
          raceDate: dateStr,
          shutubaTableUrl: link,
          raceNumber: '',
          lastScraped: DateTime.now(),
          raceDetails1: '',

          raceDetails2: '',
          shutubaHorses: null,
        ));
      } catch (e) {
        print('[ERROR]重賞日程の行解析エラー: $e');
        continue;
      }
    }
    return gradedRaces;
  }

  static Future<String?> getOfficialRaceId(String relativeUrl) async {
    try {
      final baseUrl = Uri.parse('https://race.netkeiba.com');
      final url = baseUrl.resolve(relativeUrl);

      final response = await http.get(url, headers: _headers);

      if (response.statusCode != 200) {
        print('レース特集ページの取得に失敗: $url (Status: ${response.statusCode})');
        return null;
      }
      final decodedBody = await CharsetConverter.decode('EUC-JP', response.bodyBytes);
      final document = html.parse(decodedBody);

      final resultLink = document.querySelector('a[href*="/race/result.html?race_id="]');

      if (resultLink != null) {
        final href = resultLink.attributes['href'];
        if (href != null) {
          return RaceResultScraperService.getRaceIdFromUrl(href);
        }
      }
      return null;
    } catch (e) {
      print('[ERROR]公式レースIDの取得中にエラー: $e');
      return null;
    }
  }

  static Future<PredictionRaceData> scrapeFullPredictionData(String raceId) async {
    try {
      final shutubaUrl = 'https://race.netkeiba.com/race/shutuba.html?race_id=$raceId';
      final shutubaResponse = await http.get(Uri.parse(shutubaUrl), headers: _headers);
      if (shutubaResponse.statusCode != 200) {
        throw Exception('netkeiba出馬表ページの取得に失敗しました。');
      }

      final decodedBody = await CharsetConverter.decode('EUC-JP', shutubaResponse.bodyBytes);
      final document = html.parse(decodedBody);

      final featuredRace = _parseFeaturedRaceFromDocument(document, raceId, shutubaUrl);
      final netkeibaHorses = _parseShutubaHorsesFromDocument(document);

      final List<PredictionHorseDetail> finalHorses = [];
      for (final netkeibaHorse in netkeibaHorses) {
        finalHorses.add(PredictionHorseDetail.fromShutubaHorseDetail(netkeibaHorse));
      }

      return PredictionRaceData(
        raceId: featuredRace.raceId,
        raceName: featuredRace.raceName,
        raceDate: featuredRace.raceDate,
        venue: featuredRace.venue,
        raceNumber: featuredRace.raceNumber,
        shutubaTableUrl: featuredRace.shutubaTableUrl,
        raceGrade: featuredRace.raceGrade,
        raceDetails1: featuredRace.raceDetails1,
        horses: finalHorses,
      );
    } catch (e) {
      print('[ERROR] 予想データのスクレイピング中にエラーが発生しました: $e');
      rethrow;
    }
  }

  static FeaturedRace _parseFeaturedRaceFromDocument(dom.Document document, String raceId, String url) {
    final raceNameBox = document.querySelector('div.RaceList_NameBox');
    final titleText = _safeGetText(document.querySelector('head > title'));

    String raceDate = '';
    final dateMatch = RegExp(r'(\d{4}年\d{1,2}月\d{1,2}日)').firstMatch(titleText);
    if (dateMatch != null) {
      raceDate = dateMatch.group(1)!;
    }

    final raceName = _safeGetText(raceNameBox?.querySelector('.RaceName'));
    final raceDetails1 = _safeGetText(raceNameBox?.querySelector('.RaceData01'));
    final raceDetails2 = _safeGetText(raceNameBox?.querySelector('.RaceData02')).replaceAll(RegExp(r'\s+'), ' ');

    String raceGrade = '';
    final gradeElement = raceNameBox?.querySelector('.RaceName [class*="Icon_GradeType"]');
    if (gradeElement != null) {
      final className = gradeElement.className;
      if (className.contains('Icon_GradeType10')) {
        raceGrade = 'J.G1';
      } else if (className.contains('Icon_GradeType11')) raceGrade = 'J.G2';
      else if (className.contains('Icon_GradeType12')) raceGrade = 'J.G3';
      else if (className.contains('Icon_GradeType1')) raceGrade = 'G1';
      else if (className.contains('Icon_GradeType2')) raceGrade = 'G2';
      else if (className.contains('Icon_GradeType3')) raceGrade = 'G3';
      else if (className.contains('Icon_GradeType19')) raceGrade = 'L';
    }

    return FeaturedRace(
      raceId: raceId,
      raceName: raceName,
      raceGrade: raceGrade,
      raceDate: raceDate,
      venue: _safeGetText(document.querySelector('.RaceKaisaiWrap .Active a')),
      raceNumber: _safeGetText(document.querySelector('.RaceNumWrap .Active a')).replaceAll('R', ''),
      shutubaTableUrl: url,
      lastScraped: DateTime.now(),
      distance: '',
      conditions: '',
      weight: '',
      raceDetails1: raceDetails1,
      raceDetails2: raceDetails2,
      shutubaHorses: null,
    );
  }

  static List<ShutubaHorseDetail> _parseShutubaHorsesFromDocument(dom.Document document) {
    final List<ShutubaHorseDetail> horses = [];
    final rows = document.querySelectorAll('table.Shutuba_Table tr.HorseList');
    for (final row in rows) {
      final bool isScratched = row.classes.contains('Cancel');

      final cells = row.querySelectorAll('td');
      if (cells.isEmpty) continue;

      final horseInfoCell = row.querySelector('td.HorseInfo');
      final horseLink = horseInfoCell?.querySelector('a');
      final horseId = horseLink?.attributes['href']?.split('/').lastWhere((p) => p.isNotEmpty, orElse: () => '') ?? '';

      if (horseId.isEmpty) continue;
      final jockeyLink = row.querySelector('td.Jockey a');
      final jockeyHref = jockeyLink?.attributes['href'];
      final jockeyIdMatch = jockeyHref != null ? RegExp(r'/jockey/result/recent/(\d{5})').firstMatch(jockeyHref) : null;
      final jockeyId = jockeyIdMatch?.group(1) ?? '';
      final trainerText = _safeGetText(row.querySelector('td.Trainer a'));
      String trainerAffiliation = '';
      String trainerName = trainerText;

      if (trainerText.startsWith('美') || trainerText.startsWith('栗')) {
        final parts = trainerText.split(' ');
        if (parts.length > 1) {
          trainerAffiliation = parts[0];
          trainerName = parts.sublist(1).join(' ');
        }
      }
      horses.add(ShutubaHorseDetail(
        horseId: horseId,
        gateNumber: int.tryParse(_safeGetText(row.querySelector('td[class^="Waku"]'))) ?? 0,
        horseNumber: int.tryParse(_safeGetText(row.querySelector('td[class^="Umaban"]'))) ?? 0,
        horseName: _safeGetText(horseLink),
        sexAndAge: _safeGetText(row.querySelector('td.Barei')),
        carriedWeight: isScratched ? 0.0 : double.tryParse(_safeGetText(cells[5])) ?? 0.0,
        jockey: _safeGetText(jockeyLink),
        jockeyId: jockeyId,
        trainerName: trainerName,
        trainerAffiliation: trainerAffiliation,
        horseWeight: _safeGetText(row.querySelector('td.Weight')),
        isScratched: isScratched,
      ));
    }
    return horses;
  }

  /// レース名から過去10年分のレースIDリストをスクレイピングする
  static Future<List<String>> scrapePastRaceIdsFromSearch({
    required String raceName,
  }) async {
    final searchUrl = await generateNetkeibaRaceSearchUrl(raceName: raceName);
    final List<String> pastIds = [];
    final currentYear = DateTime.now().year;

    try {
      final response = await http.get(Uri.parse(searchUrl), headers: _headers);
      if (response.statusCode != 200) {
        print('レース名検索ページの取得に失敗: $searchUrl (Status: ${response.statusCode})');
        return [];
      }

      final decodedBody = await CharsetConverter.decode('EUC-JP', response.bodyBytes);
      final document = html.parse(decodedBody);

      final table = document.querySelector('table.race_table_01');
      if (table == null) return [];

      final rows = table.querySelectorAll('tr');

      for (final row in rows) {
        final cells = row.querySelectorAll('td');
        if (cells.length < 5) continue;

        final raceNameCell = cells[4].querySelector('a');
        if (raceNameCell == null) continue;

        final dateText = _safeGetText(cells[0]);
        final yearMatch = RegExp(r'(\d{4})/\d{2}/\d{2}').firstMatch(dateText);
        if (yearMatch != null) {
          final year = int.parse(yearMatch.group(1)!);
          if (year >= currentYear - 10 && year < currentYear) {
            final href = raceNameCell.attributes['href'];
            if (href != null) {
              final id = RaceResultScraperService.getRaceIdFromUrl(href);
              if (id != null) {
                pastIds.add(id);
              }
            }
          }
        }
      }
      return pastIds;
    } catch (e) {
      print('Error fetching past race IDs by name: $e');
      return [];
    }
  }
}