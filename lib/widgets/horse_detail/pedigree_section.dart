// lib/widgets/horse_detail/pedigree_section.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/horse_profile_model.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';

// [追加] 馬詳細タブStep3: 馬詳細タブの「血統」（2代の血統表。設計書 3-4） (v.2026.9.23+26092308)
class PedigreeSection extends StatelessWidget {
  final PredictionHorseDetail horse;

  /// 保存済みのプロフィール（未取得なら null。そのときは出馬表の父・母・母父で埋める）
  final HorseProfile? profile;

  const PedigreeSection({Key? key, required this.horse, this.profile})
      : super(key: key);

  static String _pick(String? primary, String? fallback) {
    if (primary != null && primary.trim().isNotEmpty) return primary;
    if (fallback != null && fallback.trim().isNotEmpty) return fallback;
    return '--';
  }

  Widget _cell(String label, String name, Color color, {bool isParent = false}) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: Colors.grey.shade300, width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          Text(
            name,
            style: TextStyle(
              fontSize: isParent ? 14 : 13,
              fontWeight: isParent ? FontWeight.bold : FontWeight.normal,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _block({
    required String parentLabel,
    required String parent,
    required String grand1Label,
    required String grand1,
    required String grand2Label,
    required String grand2,
    required Color color,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _cell(parentLabel, parent, color, isParent: true)),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _cell(grand1Label, grand1, color),
                _cell(grand2Label, grand2, color),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = this.profile;
    final father = _pick(profile?.fatherName, horse.fatherName);
    final mother = _pick(profile?.motherName, horse.motherName);
    final ff = _pick(profile?.ffName, null);
    final fm = _pick(profile?.fmName, null);
    final mf = _pick(profile?.mfName, horse.mfName);
    final mm = _pick(profile?.mmName, null);
    return Container(
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _block(
            parentLabel: '父',
            parent: father,
            grand1Label: '父父',
            grand1: ff,
            grand2Label: '父母',
            grand2: fm,
            color: Colors.lightBlue.shade50,
          ),
          _block(
            parentLabel: '母',
            parent: mother,
            grand1Label: '母父',
            grand1: mf,
            grand2Label: '母母',
            grand2: mm,
            color: Colors.pink.shade50,
          ),
        ],
      ),
    );
  }
}
