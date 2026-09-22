// lib/widgets/horse_detail/basic_info_section.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/horse_profile_model.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/widgets/leg_style_indicator.dart';

// [追加] 馬詳細タブStep3: 馬詳細タブの「基本情報」（設計書 3-3） (v.2026.9.23+26092308)
class BasicInfoSection extends StatelessWidget {
  final PredictionHorseDetail horse;

  /// 保存済みのプロフィール（未取得なら null）
  final HorseProfile? profile;

  const BasicInfoSection({Key? key, required this.horse, this.profile})
      : super(key: key);

  /// 所属の色分け（馬柱タブの所属列と同じ色）
  static Color _affiliationColor(String affiliation) {
    if (affiliation.contains('美') || affiliation.contains('美浦')) {
      return Colors.lightBlue.shade50;
    } else if (affiliation.contains('栗') || affiliation.contains('栗東')) {
      return Colors.pink.shade50;
    } else if (affiliation.contains('地') || affiliation.contains('地方')) {
      return Colors.orange.shade50;
    } else if (affiliation.contains('外') || affiliation.contains('海外')) {
      return Colors.green.shade50;
    }
    return Colors.transparent;
  }

  static String _pick(String? primary, String? fallback) {
    if (primary != null && primary.trim().isNotEmpty) return primary;
    if (fallback != null && fallback.trim().isNotEmpty) return fallback;
    return '--';
  }

  /// 馬体重（馬柱タブの馬情報と同じ考え方: 増減カッコ付きは当日体重）
  String _horseWeightText() {
    final hw = horse.horseWeight ?? '';
    if (hw.contains('(')) {
      return '当日: $hw';
    }
    return '${hw.isEmpty ? '--' : hw}（前走: ${horse.previousHorseWeight ?? '--'}）';
  }

  Widget _row(String label, Widget value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ),
          Expanded(child: value),
        ],
      ),
    );
  }

  Widget _text(String text, {Color? color, FontWeight? weight}) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        color: color ?? Colors.black87,
        fontWeight: weight,
      ),
    );
  }

  /// 外・地・ブリンカーの印（初装着のブリンカーのみ赤背景。馬柱タブと同じ見た目）
  Widget _markChip(String label, {bool isRed = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: isRed ? Colors.red : Colors.black,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final owner = _pick(horse.ownerName, profile?.ownerName);
    final breeder = _pick(horse.breederName, profile?.breederName);
    final birthday = profile?.birthday ?? '';
    final oddsColor = (horse.odds != null && horse.odds! <= 9.9)
        ? Colors.red
        : Colors.black87;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _row(
          '性齢',
          Row(
            children: [
              _text(horse.sexAndAge, weight: FontWeight.bold),
              if (horse.isMaruGai) _markChip('外'),
              if (horse.isMaruChi) _markChip('地'),
              if (horse.isBlinker)
                _markChip('B', isRed: horse.isFirstBlinker),
            ],
          ),
        ),
        _row('騎手・斤量',
            _text('${horse.jockey}  ${horse.carriedWeight.toStringAsFixed(1)}')),
        _row(
          '調教師',
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                color: _affiliationColor(horse.trainerAffiliation),
                child: Text(
                  horse.trainerAffiliation.isEmpty
                      ? '--'
                      : horse.trainerAffiliation,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(child: _text(horse.trainerName)),
            ],
          ),
        ),
        _row('馬主', _text(owner)),
        _row('生産者', _text(breeder)),
        if (birthday.trim().isNotEmpty) _row('生年月日', _text(birthday)),
        _row('馬体重', _text(_horseWeightText())),
        _row(
          '人気・オッズ',
          Row(
            children: [
              _text('${horse.popularity ?? '--'}人気'),
              const SizedBox(width: 8),
              _text('${horse.odds?.toString() ?? '--'}倍',
                  color: oddsColor, weight: FontWeight.bold),
            ],
          ),
        ),
        _row(
          '脚質',
          Align(
            alignment: Alignment.centerLeft,
            child: LegStyleIndicator(legStyleProfile: horse.legStyleProfile),
          ),
        ),
      ],
    );
  }
}
