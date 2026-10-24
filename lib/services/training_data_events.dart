// lib/services/training_data_events.dart

// [追加] 出走の意味 調教の行 Step4: 調教・近況のデータが変わったことを知らせる。
// 取得ボタン・馬を開いたときの取得・直前の取り直しが終わったときに流し、出馬表の画面が「出走の意味」を計算し直すかを確かめる。
// RacePreparationService.stepCompletedStream と同じ作り（アプリの間ずっと使うので close しない） (v.2026.10.24+26102404)

import 'dart:async';

class TrainingDataEvents {
  TrainingDataEvents._();

  static final StreamController<String> _controller =
      StreamController<String>.broadcast();

  /// 調教・近況のデータが変わったレースのID
  static Stream<String> get updated => _controller.stream;

  /// 調教・近況のデータが変わったことを知らせる。
  static void notifyUpdated(String raceId) {
    _controller.add(raceId);
  }
}
