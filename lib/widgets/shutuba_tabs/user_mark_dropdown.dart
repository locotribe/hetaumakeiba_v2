// lib/widgets/shutuba_tabs/user_mark_dropdown.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/models/user_mark_model.dart';
import 'package:hetaumakeiba_v2/main.dart';

class UserMarkDropdown extends StatelessWidget {
  final PredictionHorseDetail horse;
  final String raceId;
  final Color textColor;
  final Function(UserMark?) onMarkChanged;

  const UserMarkDropdown({
    super.key,
    required this.horse,
    required this.raceId,
    required this.onMarkChanged,
    this.textColor = Colors.black87, // デフォルトの文字色は黒
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      constraints: const BoxConstraints(
        minWidth: 2.0 * 24.0,
        maxWidth: 2.0 * 24.0,
      ),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        ...['◎', '〇', '▲', '△', '✕', '★'].map((String value) {
          return PopupMenuItem<String>(
            value: value,
            height: 36,
            child: Center(child: Text(value)),
          );
        }),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: '消',
          height: 36,
          child: Center(child: Text('消')),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: '--',
          height: 36,
          child: Center(child: Text('--')),
        ),
      ],
      onSelected: (String newValue) {
        final userId = localUserId;
        if (userId == null) return;

        if (newValue == '--') {
          onMarkChanged(null); // 削除
        } else {
          final userMark = UserMark(
            userId: userId,
            raceId: raceId,
            horseId: horse.horseId,
            mark: newValue,
            timestamp: DateTime.now(),
          );
          onMarkChanged(userMark); // 保存・更新
        }
      },
      padding: EdgeInsets.zero,
      child: Center(
        child: Text(
          horse.userMark?.mark ?? '--',
          style: TextStyle(
            fontSize: 16.0,
            fontWeight: FontWeight.bold,
            color: textColor, // 親から指定された色を適用
          ),
        ),
      ),
    );
  }
}