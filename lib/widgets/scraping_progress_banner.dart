// lib/widgets/scraping_progress_banner.dart

// [追加] Phase 3: shutuba_table_page.dartの_buildScrapingProgressIndicator()を
// アプリ全体で共有するグローバルバナーとして独立させたもの。ScrapingManagerはシングルトンで
// アプリ全体を通じてキューを処理し続けるため、出馬表タブを離れても進捗が見え続けるようにする
// (v.2026.9.4+26090406)
// [修正] Phase 4-F: 画面上部(ステータスバー)にあるとRacePageのヘッダー/タブバーと
// 重なり取得中にタブを操作できなかったため、画面下部へ移動した (v.2026.9.5+26090505)

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/services/scraping_manager.dart';
import 'package:hetaumakeiba_v2/widgets/scraping_banner_route_observer.dart';

/// スクレイピングの進捗状況をアプリ全体の最前面に表示するバナー。
/// main.dartのMaterialApp.builder経由で全ルートの上に重ねて配置する。
class ScrapingProgressBanner extends StatelessWidget {
  const ScrapingProgressBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: ScrapingBannerRouteObserver.stackDepth,
      builder: (context, stackDepth, _) {
        return StreamBuilder<ScrapingStatus>(
          stream: ScrapingManager().statusStream,
          initialData: ScrapingStatus.idle(),
          builder: (context, snapshot) {
            final status = snapshot.data!;

            if (!status.isRunning) {
              return const SizedBox.shrink();
            }

            // [修正] Phase 4-F: 下端にMediaQueryのシステム余白＋（ボトムナビゲーションバー
            // 表示時のみ）kBottomNavigationBarHeightを加算する。このWidgetは
            // ResponsiveBreakpoints.builder()の兄弟としてStackに置かれ、その
            // InheritedWidgetがスコープに無いためResponsiveBreakpoints.of(context)は
            // 実行時例外になる。そのためmain.dartのBreakpoint(start:0, end:450,
            // name: MOBILE)と同じ境界をMediaQueryの幅で直接判定する (v.2026.9.5+26090505)
            final isMobileWidth = MediaQuery.of(context).size.width <= 450;
            final hasBottomNavigationBar = stackDepth == 1 && isMobileWidth;
            final bottomPadding = MediaQuery.of(context).padding.bottom +
                (hasBottomNavigationBar ? kBottomNavigationBarHeight : 0);

            return Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8 + bottomPadding),
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
      },
    );
  }
}
