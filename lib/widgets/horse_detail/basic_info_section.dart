// lib/widgets/horse_detail/basic_info_section.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/horse_profile_model.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';

// [追加] 馬詳細タブStep3: 馬詳細タブの「基本情報」（設計書 3-3） (v.2026.9.23+26092308)
// [修正] 基本情報整理と本賞金照合 Step1: netkeibaの馬ページと同じ項目（生年月日・調教師・馬主・生産者）だけにした。
// 性齢・騎手・斤量・馬体重・人気・オッズ・脚質は見出しや他の表示と重なるので出さない。馬主は勝負服の画像つき (v.2026.10.15+26101504)
class BasicInfoSection extends StatelessWidget {
  final PredictionHorseDetail horse;

  /// 保存済みのプロフィール（未取得なら null）
  final HorseProfile? profile;

  const BasicInfoSection({Key? key, required this.horse, this.profile})
      : super(key: key);

  static String _pick(String? primary, String? fallback) {
    if (primary != null && primary.trim().isNotEmpty) return primary;
    if (fallback != null && fallback.trim().isNotEmpty) return fallback;
    return '--';
  }

  /// 調教師（netkeibaと同じ「氏名 (所属)」。氏名はプロフィール優先、所属は出馬表）
  String _trainerText() {
    final name = _pick(profile?.trainerName, horse.trainerName);
    final affiliation = horse.trainerAffiliation.trim();
    if (name == '--' || affiliation.isEmpty) return name;
    return '$name ($affiliation)';
  }

  /// 勝負服の画像（プロフィール優先）。無ければ null
  String? _ownerImagePath() {
    for (final path in [profile?.ownerImageLocalPath, horse.ownerImageLocalPath]) {
      if (path != null && path.trim().isNotEmpty) return path;
    }
    return null;
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

  Widget _text(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 13, color: Colors.black87),
    );
  }

  @override
  Widget build(BuildContext context) {
    final birthday = _pick(profile?.birthday, null);
    final owner = _pick(profile?.ownerName, horse.ownerName);
    final breeder = _pick(profile?.breederName, horse.breederName);
    final ownerImagePath = _ownerImagePath();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _row('生年月日', _text(birthday)),
        _row('調教師', _text(_trainerText())),
        _row(
          '馬主',
          Row(
            children: [
              if (ownerImagePath != null) ...[
                Image.file(
                  File(ownerImagePath),
                  width: 20,
                  height: 20,
                  fit: BoxFit.contain,
                  errorBuilder: (c, e, s) =>
                      const SizedBox(width: 20, height: 20),
                ),
                const SizedBox(width: 6),
              ],
              Flexible(child: _text(owner)),
            ],
          ),
        ),
        _row('生産者', _text(breeder)),
      ],
    );
  }
}
