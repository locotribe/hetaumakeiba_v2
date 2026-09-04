// lib/widgets/scraping_progress_banner.dart

// [追加] Phase 3: shutuba_table_page.dartの_buildScrapingProgressIndicator()を
// アプリ全体で共有するグローバルバナーとして独立させたもの。ScrapingManagerはシングルトンで
// アプリ全体を通じてキューを処理し続けるため、出馬表タブを離れても進捗が見え続けるようにする
// (v.2026.9.4+26090406)

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/services/scraping_manager.dart';

/// スクレイピングの進捗状況をアプリ全体の最前面に表示するバナー。
/// main.dartのMaterialApp.builder経由で全ルートの上に重ねて配置する。
class ScrapingProgressBanner extends StatelessWidget {
  const ScrapingProgressBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ScrapingStatus>(
      stream: ScrapingManager().statusStream,
      initialData: ScrapingStatus.idle(),
      builder: (context, snapshot) {
        final status = snapshot.data!;

        if (!status.isRunning) {
          return const SizedBox.shrink();
        }

        // [追加] Phase 3: ステータスバーと重ならないよう上端にpaddingを加算 (v.2026.9.4+26090406)
        final topPadding = MediaQuery.of(context).padding.top;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(16, 8 + topPadding, 16, 8),
          color: Colors.blueGrey.shade800,
          child: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  // [修正] Phase 2で追加されたdoneCount/totalCountがある場合はそちらを表示する (v.2026.9.4+26090406)
                  status.totalCount > 0
                      ? '${status.currentTaskName} (${status.doneCount}/${status.totalCount})'
                      : '${status.currentTaskName} (残り: ${status.queueLength}件)',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
