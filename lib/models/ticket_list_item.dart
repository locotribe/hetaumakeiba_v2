// lib/models/ticket_list_item.dart

import 'package:hetaumakeiba_v2/models/qr_data_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/logic/hit_checker.dart';

class TicketListItem {
  final String raceId;
  final QrData qrData;
  final Map<String, dynamic> parsedTicket;
  final RaceResult? raceResult;
  final HitResult? hitResult;
  final String displayTitle;
  final String displaySubtitle;
  final String raceDate; // 追加: 日付情報（結果または出馬表から取得）
  final String raceName; // 追加: レース名（結果または出馬表から取得）

  TicketListItem({
    required this.raceId,
    required this.qrData,
    required this.parsedTicket,
    this.raceResult,
    this.hitResult,
    required this.displayTitle,
    required this.displaySubtitle,
    required this.raceDate,
    required this.raceName,
  });
}