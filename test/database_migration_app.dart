// lib/database_migration_app.dart

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:hetaumakeiba_v2/db/db_provider.dart';
import 'package:hetaumakeiba_v2/db/db_constants.dart';
import 'package:hetaumakeiba_v2/db/repositories/race_repository.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/models/shutuba_table_cache_model.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    title: 'データベース一括移行ツール',
    home: DatabaseMigrationScreen(),
    debugShowCheckedModeBanner: false,
  ));
}

class DatabaseMigrationScreen extends StatefulWidget {
  const DatabaseMigrationScreen({Key? key}) : super(key: key);

  @override
  State<DatabaseMigrationScreen> createState() => _DatabaseMigrationScreenState();
}

class _DatabaseMigrationScreenState extends State<DatabaseMigrationScreen> {
  bool _isUpdating = false;
  double _progress = 0.0;
  final List<String> _logs = [];

  // ログを画面に追加する関数
  void _addLog(String message) {
    setState(() {
      // 最新のログが一番上に来るように追加
      _logs.insert(0, '${DateTime.now().toIso8601String().substring(11, 19)} $message');
    });
    print(message); // ターミナルにも出力
  }

  Future<void> _runMigration() async {
    setState(() {
      _isUpdating = true;
      _progress = 0.0;
      _logs.clear();
      _addLog('🚀 データベースのマイグレーション（16項目への一括変換）を開始します...');
    });

    try {
      final db = await DbProvider().database;
      final raceRepo = RaceRepository();

      // =========================================================
      // 1. 出馬表キャッシュ (shutuba_table_cache) の移行
      // =========================================================
      _addLog('📂 旧・出馬表データ (shutuba_table_cache) を読み込み中...');
      final shutubaMaps = await db.query('shutuba_table_cache');
      _addLog('✅ 出馬表データ: ${shutubaMaps.length} 件見つかりました。変換を開始します。');

      int shutubaCount = 0;
      for (final map in shutubaMaps) {
        try {
          final raceId = map['race_id'] as String;
          final jsonString = map['race_data_json'] as String;
          final lastUpdatedStr = map['last_updated_at'] as String;

          // ▼ ここで Phase 1 の自動補完（フォールバック）が走り、16項目が生成される！
          final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
          final raceData = PredictionRaceData.fromJson(jsonData);

          final cache = ShutubaTableCache(
            raceId: raceId,
            predictionRaceData: raceData,
            lastUpdatedAt: DateTime.parse(lastUpdatedStr),
          );

          // ▼ Phase 2 で作った門番を通って、新テーブル（integrated_races）にUPSERTされる
          await raceRepo.insertOrUpdateShutubaTableCache(cache);
          shutubaCount++;

          if (shutubaCount % 10 == 0 || shutubaCount == shutubaMaps.length) {
            setState(() {
              _progress = (shutubaCount / shutubaMaps.length) * 0.5; // 全体の50%を占める
            });
          }
        } catch (e) {
          _addLog('⚠️ 出馬表エラー (ID: ${map['race_id']}): $e');
        }
      }
      _addLog('🎉 出馬表データの移行完了: $shutubaCount / ${shutubaMaps.length} 件');

      // =========================================================
      // 2. レース結果 (race_results) の移行
      // =========================================================
      _addLog('📂 旧・レース結果データ (race_results) を読み込み中...');
      final resultMaps = await db.query(DbConstants.tableRaceResults);
      _addLog('✅ レース結果データ: ${resultMaps.length} 件見つかりました。変換を開始します。');

      int resultCount = 0;
      for (final map in resultMaps) {
        try {
          final jsonString = map['race_result_json'] as String;

          // JSONから復元
          final resultData = raceResultFromJson(jsonString);

          // ▼ 新テーブルへUPSERT
          await raceRepo.insertOrUpdateRaceResult(resultData);
          resultCount++;

          if (resultCount % 10 == 0 || resultCount == resultMaps.length) {
            setState(() {
              _progress = 0.5 + ((resultCount / resultMaps.length) * 0.5); // 残りの50%
            });
          }
        } catch (e) {
          _addLog('⚠️ レース結果エラー: $e');
        }
      }
      _addLog('🎉 レース結果データの移行完了: $resultCount / ${resultMaps.length} 件');

      _addLog('✨ すべてのマイグレーションが完了しました！');
      _addLog('👉 ターミナルで Ctrl + C を押して終了し、元のアプリを起動してください。');

    } catch (e) {
      _addLog('❌ 致命的なエラーが発生しました: $e');
    } finally {
      setState(() {
        _isUpdating = false;
        _progress = 1.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DB一括移行ツール (Phase 16項目化)'),
        backgroundColor: Colors.blueGrey,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '過去の全レースデータを新しい「16項目統合テーブル」へ一括変換します。\n'
                  'これにより、今後の分析ロジックが劇的に高速化されます。',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isUpdating ? null : _runMigration,
              icon: _isUpdating
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.play_arrow),
              label: Text(_isUpdating ? "移行処理中... アプリを閉じないでください" : "一括移行スタート"),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isUpdating ? Colors.grey : Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            if (_isUpdating || _progress > 0) ...[
              LinearProgressIndicator(value: _progress, minHeight: 8),
              const SizedBox(height: 8),
              Text('${(_progress * 100).toStringAsFixed(1)} % 完了', textAlign: TextAlign.right),
            ],
            const SizedBox(height: 16),
            const Text('実行ログ:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Text(
                        _logs[index],
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}