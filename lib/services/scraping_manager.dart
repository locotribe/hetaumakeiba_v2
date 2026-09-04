// lib/services/scraping_manager.dart

import 'package:flutter/foundation.dart';
import 'dart:async';

/// スクレイピングの進捗状況を表すクラス
class ScrapingStatus {
  final bool isRunning;
  final int queueLength;
  final String currentTaskName;
  // [追加] Phase 2: バッチ全体に対する進捗カウント (v.2026.9.4+26090405)
  final int doneCount;
  final int totalCount;

  ScrapingStatus({
    required this.isRunning,
    required this.queueLength,
    required this.currentTaskName,
    this.doneCount = 0,
    this.totalCount = 0,
  });

  factory ScrapingStatus.idle() {
    return ScrapingStatus(isRunning: false, queueLength: 0, currentTaskName: '');
  }
}

/// スクレイピングタスクのラッパークラス
class _ScrapingTask {
  final String label;
  final Future<void> Function() task;
  // [追加] Phase 2: 重複排除用キー (v.2026.9.4+26090405)
  final String? key;

  _ScrapingTask(this.label, this.task, {this.key});
}

class ScrapingManager {
  static final ScrapingManager _instance = ScrapingManager._internal();

  factory ScrapingManager() => _instance;

  ScrapingManager._internal();

  // タスクキュー
  final List<_ScrapingTask> _queue = [];

  // 処理中フラグ
  bool _isProcessing = false;

  // [追加] Phase 2: 現在実行中のタスクのkey（重複排除の判定に使用） (v.2026.9.4+26090405)
  String? _currentKey;

  // [追加] Phase 2: 現在のバッチの進捗カウント (v.2026.9.4+26090405)
  int _doneCount = 0;
  int _totalCount = 0;

  // 進捗状況を通知するStreamController
  final StreamController<ScrapingStatus> _statusController = StreamController<ScrapingStatus>.broadcast();

  Stream<ScrapingStatus> get statusStream => _statusController.stream;

  /// リクエスト間隔（ミリ秒）
  /// サーバー負荷軽減のため1秒以上の間隔を空ける
  static const int _intervalMs = 1500;

  /// タスクをキューに追加する
  // [修正] Phase 2: keyによる重複排除を追加。keyがnullの場合は従来どおり無条件で積む (v.2026.9.4+26090405)
  void addRequest(String label, Future<void> Function() task, {String? key}) {
    if (key != null) {
      final isDuplicateInQueue = _queue.any((t) => t.key == key);
      final isDuplicateRunning = _currentKey == key;
      if (isDuplicateInQueue || isDuplicateRunning) {
        debugPrint('ScrapingManager: skipped duplicate: $key');
        return;
      }
    }

    _queue.add(_ScrapingTask(label, task, key: key));
    _totalCount++;
    _notifyStatus();

    if (!_isProcessing) {
      _processQueue();
    }
  }

  /// 現在のキューをすべてクリアする（画面遷移時などに使用可能）
  // [修正] Phase 2: カウンタと_currentKeyもリセットする (v.2026.9.4+26090405)
  void clearQueue() {
    _queue.clear();
    _currentKey = null;
    _doneCount = 0;
    _totalCount = 0;
    _notifyStatus();
  }

  /// キューの処理ループ
  Future<void> _processQueue() async {
    if (_queue.isEmpty) {
      _isProcessing = false;
      // [追加] Phase 2: キューが空になった時点でカウンタ・_currentKeyをリセット (v.2026.9.4+26090405)
      _currentKey = null;
      _doneCount = 0;
      _totalCount = 0;
      _notifyStatus();
      return;
    }

    _isProcessing = true;

    // 先頭のタスクを取り出す
    final currentTask = _queue.removeAt(0);
    // [追加] Phase 2: 実行中タスクのkeyを保持（重複排除の判定に使用） (v.2026.9.4+26090405)
    _currentKey = currentTask.key;

    // ステータス更新（処理中）
    _statusController.add(ScrapingStatus(
      isRunning: true,
      queueLength: _queue.length + 1, // 現在処理中のものも含めるため+1
      currentTaskName: currentTask.label,
      doneCount: _doneCount,
      totalCount: _totalCount,
    ));

    try {
      // タスク実行
      debugPrint('ScrapingManager: Start processing -> ${currentTask.label}');
      await currentTask.task();
    } catch (e) {
      debugPrint('ScrapingManager: Error in task ${currentTask.label}: $e');
    } finally {
      // [追加] Phase 2: タスク完了（成功・失敗いずれも）でkeyを解放し完了数を加算 (v.2026.9.4+26090405)
      _currentKey = null;
      _doneCount++;

      // 指定間隔待機（サーバー負荷軽減）
      await Future.delayed(const Duration(milliseconds: _intervalMs));

      // 再帰的に次のタスクを処理
      _processQueue();
    }
  }

  void _notifyStatus() {
    if (_queue.isEmpty && !_isProcessing) {
      _statusController.add(ScrapingStatus.idle());
    } else if (!_isProcessing) {
      // 処理待ち状態
      _statusController.add(ScrapingStatus(
        isRunning: true,
        queueLength: _queue.length,
        currentTaskName: '待機中...',
        doneCount: _doneCount,
        totalCount: _totalCount,
      ));
    }
  }

  void dispose() {
    _statusController.close();
  }
}