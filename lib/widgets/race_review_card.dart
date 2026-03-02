// lib/widgets/race_review_card.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/repositories/race_repository.dart';
import 'package:hetaumakeiba_v2/models/race_memo_model.dart';

class RaceReviewCard extends StatefulWidget {
  final String raceId;
  final String userId;

  const RaceReviewCard({
    super.key,
    required this.raceId,
    required this.userId,
  });

  @override
  State<RaceReviewCard> createState() => _RaceReviewCardState();
}

class _RaceReviewCardState extends State<RaceReviewCard> {
  final RaceRepository _raceRepo = RaceRepository();
  final TextEditingController _controller = TextEditingController();
  bool _isEditing = false;
  RaceMemo? _currentMemo;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMemo();
  }

  Future<void> _loadMemo() async {
    // ユーザーIDが空の場合は処理をスキップ
    if (widget.userId.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    final memo = await _raceRepo.getRaceMemo(widget.userId, widget.raceId);
    if (mounted) {
      setState(() {
        _currentMemo = memo;
        _controller.text = memo?.memo ?? '';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveMemo() async {
    final text = _controller.text;
    final newMemo = RaceMemo(
      id: _currentMemo?.id,
      userId: widget.userId,
      raceId: widget.raceId,
      memo: text,
      timestamp: DateTime.now(),
    );
    await _raceRepo.insertOrUpdateRaceMemo(newMemo);
    if (mounted) {
      setState(() {
        _currentMemo = newMemo;
        _isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('レース総評を保存しました')),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SizedBox.shrink();

    // userIdがない（未ログインなど）場合は非表示にする制御
    if (widget.userId.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      color: Colors.amber.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.rate_review, size: 20, color: Colors.brown),
                    SizedBox(width: 8),
                    Text(
                      'レース総評',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                if (!_isEditing)
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () {
                      setState(() {
                        _isEditing = true;
                      });
                    },
                    tooltip: '編集',
                  ),
              ],
            ),
            const Divider(),
            if (_isEditing) ...[
              TextField(
                controller: _controller,
                maxLines: null,
                minLines: 3,
                decoration: const InputDecoration(
                  hintText: 'レース全体の傾向やメモを入力...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isEditing = false;
                        _controller.text = _currentMemo?.memo ?? '';
                      });
                    },
                    child: const Text('キャンセル'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saveMemo,
                    child: const Text('保存'),
                  ),
                ],
              ),
            ] else ...[
              if (_currentMemo != null && _currentMemo!.memo.isNotEmpty)
                Text(
                  _currentMemo!.memo,
                  style: const TextStyle(fontSize: 14, height: 1.5),
                )
              else
                const Text(
                  'レースの総評はまだありません。\n編集ボタンから入力してください。',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
            ],
          ],
        ),
      ),
    );
  }
}