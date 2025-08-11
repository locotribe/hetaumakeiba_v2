// lib/services/analytics_service.dart

import 'dart:convert';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/logic/hit_checker.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/logic/parse.dart';
import 'package:hetaumakeiba_v2/models/qr_data_model.dart';

class AnalyticsService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  /// 特定のレースIDの結果が確定した際に、関連する全ての集計値を更新する
  Future<void> updateAggregatesOnResultConfirmed(String raceId) async {
    final raceResult = await _dbHelper.getRaceResult(raceId);
    if (raceResult == null || raceResult.isIncomplete) {
      return; // レース結果が存在しない、または未確定の場合は何もしない
    }

    // このraceIdに紐づく全てのQrDataを取得
    final allQrData = await _dbHelper.getAllQrData();
    final List<QrData> relevantTickets = [];
    for (final qrData in allQrData) {
      final parsedData = json.decode(qrData.parsedDataJson) as Map<String, dynamic>;
      final qrRaceId = _getRaceIdFromParsedTicket(parsedData);
      if (qrRaceId == raceId) {
        relevantTickets.add(qrData);
      }
    }

    if (relevantTickets.isEmpty) {
      return; // 対象の馬券がなければ何もしない
    }

    final Map<String, Map<String, int>> updates = {};

    for (final ticket in relevantTickets) {
      final parsedTicket = json.decode(ticket.parsedDataJson) as Map<String, dynamic>;
      final hitResult = HitChecker.check(parsedTicket: parsedTicket, raceResult: raceResult);

      final int investment = parsedTicket['合計金額'] as int? ?? 0;
      final int payout = hitResult.totalPayout + hitResult.totalRefund;
      final int isHit = hitResult.isHit ? 1 : 0;
      final int betCount = 1;

      // この馬券が影響を与える全ての集計キーを生成
      final keys = _generateAggregateKeys(parsedTicket, raceResult);

      for (final key in keys) {
        _applyDeltas(
          updates: updates,
          key: key,
          investmentDelta: investment,
          payoutDelta: payout,
          hitDelta: isHit,
          betDelta: betCount,
        );
      }
    }

    if (updates.isNotEmpty) {
      await _dbHelper.updateAggregates(updates);
    }
  }

  /// 解析済み馬券データからレースIDを生成するヘルパー
  String _getRaceIdFromParsedTicket(Map<String, dynamic> parsedTicket) {
    try {
      final year = parsedTicket['年'].toString().padLeft(2, '0');
      final racecourseCode = racecourseDict.entries.firstWhere((e) => e.value == parsedTicket['開催場']).key;
      final round = parsedTicket['回'].toString().padLeft(2, '0');
      final day = parsedTicket['日'].toString().padLeft(2, '0');
      final race = parsedTicket['レース'].toString().padLeft(2, '0');
      return '20$year$racecourseCode$round$day$race';
    } catch (e) {
      return ''; // 失敗した場合は空文字を返す
    }
  }

  /// 馬券とレース結果から、更新すべき集計キーのリストを生成する
  List<String> _generateAggregateKeys(Map<String, dynamic> parsedTicket, RaceResult raceResult) {
    final List<String> keys = [];

    // 1. 年と月のキー
    int year = 0;
    int month = 0;
    try {
      final dateParts = raceResult.raceDate.split(RegExp(r'[年月日]'));
      year = int.parse(dateParts[0]);
      month = int.parse(dateParts[1]);
      keys.add('total_$year');
      keys.add('total_$year-${month.toString().padLeft(2, '0')}');
    } catch (e) {
      // 日付が不正な場合はスキップ
    }

    if (year == 0) return keys; // 年が取得できなければ以降の処理は行わない

    // 2. 競馬場のキー
    final venue = parsedTicket['開催場'] as String? ?? '不明';
    if (venue != '不明') keys.add('venue_${venue}_$year');

    // 3. グレードのキー
    final gradePattern = RegExp(r'\(((?:J[・.]?)?G(?:I{1,3}|[1-3])|Jpn[1-3])\)', caseSensitive: false);
    final gradeMatch = gradePattern.firstMatch(raceResult.raceTitle);
    String grade;
    if (gradeMatch != null) {
      grade = _normalizeGrade(gradeMatch.group(1)!);
    } else {
      grade = raceResult.raceGrade.isNotEmpty ? raceResult.raceGrade : 'その他';
    }
    keys.add('grade_${grade}_$year');

    // 4. 距離とトラックのキー
    final raceInfoParts = raceResult.raceInfo.split('/');
    if (raceInfoParts.isNotEmpty) {
      final trackAndDistance = raceInfoParts[0].trim();
      final track = trackAndDistance.startsWith('ダ') ? 'ダート' : (trackAndDistance.startsWith('障') ? '障害' : '芝');
      final distance = trackAndDistance.replaceAll(RegExp(r'[^0-9]'), '');
      keys.add('track_${track}_$year');
      if (distance.isNotEmpty) keys.add('distance_${distance}m_$year');
    }

    // 5. 購入方式のキー
    final purchaseMethod = parsedTicket['方式'] as String? ?? '不明';
    if (purchaseMethod != '不明') keys.add('purchase_method_${purchaseMethod}_$year');

    // 6. 式別のキー (購入内容ごとに個別)
    final purchaseDetails = parsedTicket['購入内容'] as List? ?? [];
    final Set<String> ticketTypeIds = {};
    for (var detail in purchaseDetails) {
      if (detail is Map<String, dynamic>) {
        final ticketTypeId = detail['式別'] as String? ?? '不明';
        if (ticketTypeId != '不明') ticketTypeIds.add(ticketTypeId);
      }
    }
    for (final id in ticketTypeIds) {
      final typeName = bettingDict[id] ?? '不明';
      if (typeName != '不明') keys.add('ticket_type_${typeName}_$year');
    }

    return keys;
  }

  /// 検出したグレード表記を正規化する
  String _normalizeGrade(String rawGrade) {
    final upperGrade = rawGrade.toUpperCase().replaceAll('Ⅰ', 'I').replaceAll('Ⅱ', 'II').replaceAll('Ⅲ', 'III');
    const gradeMap = {
      'J.G1': 'J.G1', 'J・G1': 'J.G1',
      'J.GI': 'J.G1', 'J・GI': 'J.G1',
      'J.G2': 'J.G2', 'J・G2': 'J.G2',
      'J.GII': 'J.G2', 'J・GII': 'J.G2',
      'J.G3': 'J.G3', 'J・G3': 'J.G3',
      'J.GIII': 'J.G3', 'J・GIII': 'J.G3',
      'G1': 'G1', 'GI': 'G1',
      'G2': 'G2', 'GII': 'G2',
      'G3': 'G3', 'GIII': 'G3',
      'JPN1': 'Jpn1',
      'JPN2': 'Jpn2',
      'JPN3': 'Jpn3',
    };
    return gradeMap[upperGrade] ?? 'その他';
  }

  /// 更新用マップに差分を適用するヘルパー
  void _applyDeltas({
    required Map<String, Map<String, int>> updates,
    required String key,
    required int investmentDelta,
    required int payoutDelta,
    required int hitDelta,
    required int betDelta,
  }) {
    if (!updates.containsKey(key)) {
      updates[key] = {
        'investment_delta': 0,
        'payout_delta': 0,
        'hit_delta': 0,
        'bet_delta': 0,
      };
    }
    updates[key]!['investment_delta'] = (updates[key]!['investment_delta'] ?? 0) + investmentDelta;
    updates[key]!['payout_delta'] = (updates[key]!['payout_delta'] ?? 0) + payoutDelta;
    updates[key]!['hit_delta'] = (updates[key]!['hit_delta'] ?? 0) + hitDelta;
    updates[key]!['bet_delta'] = (updates[key]!['bet_delta'] ?? 0) + betDelta;
  }
}