// lib/screens/bulk_memo_edit_page.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/models/horse_memo_model.dart';
import 'package:hetaumakeiba_v2/models/prediction_race_data.dart';
import 'package:hetaumakeiba_v2/main.dart';

class BulkMemoEditPage extends StatefulWidget {
  final List<PredictionHorseDetail> horses;
  final String raceId;

  const BulkMemoEditPage({
    super.key,
    required this.horses,
    required this.raceId,
  });

  @override
  State<BulkMemoEditPage> createState() => _BulkMemoEditPageState();
}

class _BulkMemoEditPageState extends State<BulkMemoEditPage> {
  late Map<String, TextEditingController> _controllers;
  bool _isLoading = false;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (var horse in widget.horses)
        horse.horseId: TextEditingController(text: horse.userMemo?.predictionMemo)
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
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ユーザー情報が取得できませんでした。')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final List<HorseMemo> memosToUpdate = [];
      for (final horse in widget.horses) {
        final controller = _controllers[horse.horseId];
        if (controller != null) {
          memosToUpdate.add(HorseMemo(
            id: horse.userMemo?.id,
            userId: userId,
            raceId: widget.raceId,
            horseId: horse.horseId,
            predictionMemo: controller.text,
            reviewMemo: horse.userMemo?.reviewMemo, // 既存の総評メモは維持
            timestamp: DateTime.now(),
          ));
        }
      }

      await _dbHelper.insertOrUpdateMultipleMemos(memosToUpdate);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('メモを保存しました。')),
        );
        Navigator.of(context).pop(true); // trueを返して更新を通知
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存中にエラーが発生しました: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('メモ一括編集'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : TextButton(
              onPressed: _saveMemos,
              child: const Text('保存', style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: widget.horses.length,
        itemBuilder: (context, index) {
          final horse = widget.horses[index];
          final controller = _controllers[horse.horseId];

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4.0),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${horse.horseNumber} ${horse.horseName}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: controller,
                    maxLines: null,
                    decoration: const InputDecoration(
                      hintText: '予想メモ...',
                      border: OutlineInputBorder(),
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