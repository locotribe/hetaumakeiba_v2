// lib/models/ticket_list_item.dart

import 'package:hetaumakeiba_v2/models/qr_data_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/logic/hit_checker.dart';

class TicketListItem {
  final String raceId; // 新しいアーキテクチャで必要なraceId
  final QrData qrData;
  final Map<String, dynamic> parsedTicket;
  final RaceResult? raceResult;
  final HitResult? hitResult;
  final String displayTitle;
  final String displaySubtitle;

  TicketListItem({
    required this.raceId,
    required this.qrData,
    required this.parsedTicket,
    this.raceResult,
    this.hitResult,
    required this.displayTitle,
    required this.displaySubtitle,
  });
}