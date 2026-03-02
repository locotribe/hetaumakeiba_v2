// lib/screens/bulk_review_edit_page.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/repositories/horse_repository.dart';
import 'package:hetaumakeiba_v2/models/horse_memo_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/main.dart';

class BulkReviewEditPage extends StatefulWidget {
  final String raceId;
  final List<HorseResult> horseResults;

  const BulkReviewEditPage({
    super.key,
    required this.raceId,
    required this.horseResults,
  });

  @override
  State<BulkReviewEditPage> createState() => _BulkReviewEditPageState();
}

class _BulkReviewEditPageState extends State<BulkReviewEditPage> {
  late Map<String, TextEditingController> _controllers;
  bool _isLoading = false;
  final HorseRepository _horseRepository = HorseRepository();

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (var horse in widget.horseResults)
        horse.horseId: TextEditingController(text: horse.userMemo?.reviewMemo)
    };
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _saveMemos() async {
    final userId = localUserId;
    if (userId == null) return;

    setState(() => _isLoading = true);

    try {
      final List<HorseMemo> memosToUpdate = [];
      for (final horse in widget.horseResults) {
        final controller = _controllers[horse.horseId];
        if (controller != null) {
          memosToUpdate.add(HorseMemo(
            id: horse.userMemo?.id,
            userId: userId,
            raceId: widget.raceId,
            horseId: horse.horseId,
            reviewMemo: controller.text, // ここを更新
            predictionMemo: horse.userMemo?.predictionMemo, // 既存の予想メモは維持
            timestamp: DateTime.now(),
          ));
        }
      }

      await _horseRepository.insertOrUpdateMultipleMemos(memosToUpdate);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('回顧メモを一括保存しました')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存エラー: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('回顧メモ一括編集'),
        actions: [
          if (_isLoading)
            const Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(color: Colors.white))
          else
            TextButton(
              onPressed: _saveMemos,
              child: const Text('保存', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: widget.horseResults.length,
        itemBuilder: (context, index) {
          final horse = widget.horseResults[index];
          final controller = _controllers[horse.horseId];
          final prediction = horse.userMemo?.predictionMemo;

          // 着順によって色を変える
          final rankInt = int.tryParse(horse.rank);
          Color? rankColor;
          if (rankInt == 1) rankColor = Colors.pink.shade50;
          else if (rankInt == 2) rankColor = Colors.blue.shade50;
          else if (rankInt == 3) rankColor = Colors.yellow.shade50;

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4.0),
            color: rankColor,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${horse.rank}着',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${horse.horseNumber} ${horse.horseName}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),

                  // 予想メモの表示（参照用）
                  if (prediction != null && prediction.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.blue.shade100),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('【予想時のメモ】', style: TextStyle(fontSize: 10, color: Colors.blue)),
                          Text(prediction, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 8),
                  TextFormField(
                    controller: controller,
                    maxLines: null,
                    minLines: 2,
                    decoration: const InputDecoration(
                      hintText: '回顧メモを入力...',
                      border: OutlineInputBorder(),
                      fillColor: Colors.white,
                      filled: true,
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}