// lib/widgets/horse_detail/memo_section.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/widgets/memo/horse_memo_parts.dart';

// [追加] 馬詳細タブStep3: 馬詳細タブの「メモ」（今回の予想・過去メモ。設計書 3-6） (v.2026.9.23+26092308)
class MemoSection extends StatelessWidget {
  final PredictionHorseDetail horse;

  /// 過去メモ（馬詳細タブで1頭1回だけ読み込んだもの）
  final Future<List<PastMemoDetail>> pastMemosFuture;
  final VoidCallback onEdit;

  const MemoSection({
    Key? key,
    required this.horse,
    required this.pastMemosFuture,
    required this.onEdit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final memo = horse.userMemo?.predictionMemo ?? '';
    final hasMemo = memo.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text('今回の予想',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const Spacer(),
            OutlinedButton.icon(
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('編集'),
              onPressed: horse.isScratched ? null : onEdit,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            hasMemo ? memo : 'メモなし',
            style: TextStyle(
              fontSize: 13,
              color: hasMemo ? Colors.black87 : Colors.grey,
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text('過去メモ(直近5走)',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        FutureBuilder<List<PastMemoDetail>>(
          future: pastMemosFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Text('-', style: TextStyle(color: Colors.grey));
            }
            return PastMemoList(details: snapshot.data!);
          },
        ),
      ],
    );
  }
}
