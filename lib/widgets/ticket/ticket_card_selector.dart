// lib/widgets/ticket/ticket_card_selector.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/parse.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/cards/betting_ticket_card.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/cards/dual_betting_ticket_card.dart';

Widget buildTicketCard(Map<String, dynamic> ticketData, {RaceResult? raceResult}) {
  Map<String, dynamic> activeTicketData = Map<String, dynamic>.from(ticketData);

  String foundQr = '';
  for (var entry in ticketData.entries) {
    if (entry.value is String && (entry.value as String).length >= 190) {
      foundQr = entry.value as String;
      break;
    }
  }
  if (foundQr.isNotEmpty) {
    try {
      activeTicketData = parseHorseracingTicketQr(foundQr);
    } catch (_) {}
  }

  List<dynamic> rawList = [];
  if (activeTicketData.containsKey('購入内容') && activeTicketData['購入内容'] is List) {
    rawList = activeTicketData['購入内容'] as List;
  } else if (activeTicketData.containsKey('purchase_details') && activeTicketData['purchase_details'] is List) {
    rawList = activeTicketData['purchase_details'] as List;
  } else if (activeTicketData.containsKey('purchaseDetails') && activeTicketData['purchaseDetails'] is List) {
    rawList = activeTicketData['purchaseDetails'] as List;
  }

  List<Map<String, dynamic>> purchaseDetails = [];
  for (var item in rawList) {
    if (item is Map) {
      purchaseDetails.add(Map<String, dynamic>.from(item));
    }
  }

  final String method = (activeTicketData['方式'] ?? '').toString();
  final bool isOuenBaken = (method == '応援馬券' || method == '5');

  final Set<String> shikibetsuTypes = {};
  for (var p in purchaseDetails) {
    final code = p['式別']?.toString() ?? '';
    if (code.isNotEmpty) {
      shikibetsuTypes.add(code);
    }
  }

  final bool isDual = !isOuenBaken && shikibetsuTypes.length >= 2;

  if (isDual) {
    return DualBettingTicketCard(ticketData: activeTicketData, raceResult: raceResult);
  } else {
    return BettingTicketCard(ticketData: activeTicketData, raceResult: raceResult);
  }
}
