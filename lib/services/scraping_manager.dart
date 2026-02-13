// lib/services/scraping_manager.dart

import 'dart:async';

/// スクレイピングの進捗状況を表すクラス
class ScrapingStatus {
  final bool isRunning;
  final int queueLength;
  final String currentTaskName;

  ScrapingStatus({
    required this.isRunning,
    required this.queueLength,
    required this.currentTaskName,
  });

  factory ScrapingStatus.idle() {
    return ScrapingStatus(isRunning: false, queueLength: 0, currentTaskName: '');
  }
}

/// スクレイピングタスクのラッパークラス
class _ScrapingTask {
  final String label;
  final Future<void> Function() task;

  _ScrapingTask(this.label, this.task);
}

class ScrapingManager {
  static final ScrapingManager _instance = ScrapingManager._internal();

  factory ScrapingManager() => _instance;

  ScrapingManager._internal();

  // タスクキュー
  final List<_ScrapingTask> _queue = [];

  // 処理中フラグ
  bool _isProcessing = false;

  // 進捗状況を通知するStreamController
  final StreamController<ScrapingStatus> _statusController = StreamController<ScrapingStatus>.broadcast();

  Stream<ScrapingStatus> get statusStream => _statusController.stream;

  /// リクエスト間隔（ミリ秒）
  /// サーバー負荷軽減のため1秒以上の間隔を空ける
  static const int _intervalMs = 1500;

  /// タスクをキューに追加する
  void addRequest(String label, Future<void> Function() task) {
    _queue.add(_ScrapingTask(label, task));
    _notifyStatus();

    if (!_isProcessing) {
      _processQueue();
    }
  }

  /// 現在のキューをすべてクリアする（画面遷移時などに使用可能）
  void clearQueue() {
    _queue.clear();
    _notifyStatus();
  }

  /// キューの処理ループ
  Future<void> _processQueue() async {
    if (_queue.isEmpty) {
      _isProcessing = false;
      _notifyStatus();
      return;
    }

    _isProcessing = true;

    // 先頭のタスクを取り出す
    final currentTask = _queue.removeAt(0);

    // ステータス更新（処理中）
    _statusController.add(ScrapingStatus(
      isRunning: true,
      queueLength: _queue.length + 1, // 現在処理中のものも含めるため+1
      currentTaskName: currentTask.label,
    ));

    try {
      // タスク実行
      print('ScrapingManager: Start processing -> ${currentTask.label}');
      await currentTask.task();
    } catch (e) {
      print('ScrapingManager: Error in task ${currentTask.label}: $e');
    } finally {
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
      ));
    }
  }

  void dispose() {
    _statusController.close();
  }
}