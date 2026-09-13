// lib/widgets/ticket/details/formation_details.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/combination_calculator.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/parts/horse_number_box.dart';

/// フォーメーション投票のレイアウト
Widget buildFormationDetails(Map<String, dynamic> detail, String currentBetType) {
  final String shikibetsuId = detail['式別'] ?? '';
  final String shikibetsu = bettingDict[shikibetsuId] ?? '';

  final horseGroups = (detail['馬番'] as List).map((e) => (e as List).cast<int>()).toList();
  final List<Map<String, dynamic>> groupsData = [];
  if (shikibetsu == '3連単') {
    groupsData.addAll([
      {'horseNumbers': horseGroups.isNotEmpty ? horseGroups[0] : <int>[]},
      {'horseNumbers': horseGroups.length > 1 ? horseGroups[1] : <int>[]},
      {'horseNumbers': horseGroups.length > 2 ? horseGroups[2] : <int>[]},
    ]);
  } else if (shikibetsu == '3連複') {
    for (var group in horseGroups) {
      groupsData.add({'horseNumbers': group});
    }
  } else if (shikibetsu == '馬単') {
    groupsData.addAll([
      {'horseNumbers': horseGroups.isNotEmpty ? horseGroups[0] : <int>[]},
      {'horseNumbers': horseGroups.length > 1 ? horseGroups[1] : <int>[]},
    ]);
  }
  return buildHorizontalGroupLayout(
    groupsData,
    isFormation: true,
    shikibetsu: shikibetsu,
    betType: currentBetType,
  );
}
