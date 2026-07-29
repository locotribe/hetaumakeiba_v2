#!/usr/bin/env python3
# tools/speed_index_fit.py
# スピード指数(案C: オフライン重回帰)の基準タイム定数を生成するスクリプト。
#
# 目的:
#   race_results から「距離・競馬場・馬場状態・クラス・年」を説明変数に走破タイムを重回帰し、
#   クラス補正済み(クラス中立)の基準タイム定数・馬場補正・年トレンド・距離係数を算出する。
#   出力は Flutter アプリに埋め込む定数(Dartクラス)。データが増えたら再実行して定数を更新する運用。
#
# 使い方:
#   python3 tools/speed_index_fit.py --db path/to/hetaumakeiba_v2.db [--out lib/logic/analysis/speed_index_constants.dart]
#   --out 未指定なら標準出力にDartコードを表示する。
#
# 注意:
#   - 非JRA/不明の競馬場コードは除外する。
#   - 目的変数は各レース1〜3着馬のタイム(大敗馬のノイズを避ける)。
#   - 基準クラスは OP。クラス係数は回帰内の交絡除去にのみ用い、基準タイムはクラス中立(OP)で出す。

import argparse, sqlite3, json, re, sys
import numpy as np
import pandas as pd

VEN = {'01':'札幌','02':'函館','03':'福島','04':'新潟','05':'東京',
       '06':'中山','07':'中京','08':'京都','09':'阪神','10':'小倉'}

def t2s(t):
    m = re.match(r'^(?:(\d+):)?(\d+(?:\.\d+)?)$', (t or '').strip())
    return (int(m.group(1)) if m and m.group(1) else 0) * 60 + float(m.group(2)) if m else None

def classify(s):
    s = s or ''
    for k in ['新馬','未勝利','1勝','2勝','3勝']:
        if k in s: return k
    if re.search(r'\(G1\)|\(GI\)|\(GⅠ\)', s): return 'G1'
    if re.search(r'\(G2\)|\(GII\)|\(GⅡ\)', s): return 'G2'
    if re.search(r'\(G3\)|\(GIII\)|\(GⅢ\)', s): return 'G3'
    if '(L)' in s: return 'L'
    return 'OP'

# 距離帯別 距離係数(点/秒) = 10 / 残差SD。スクリプト実行時に距離帯別残差SDから再算出する。
DIST_BANDS = {'芝':[(0,1400),(1400,1800),(1800,2200),(2200,9999)],
              'ダ':[(0,1400),(1400,1800),(1800,9999)]}

def load(dbpath):
    c = sqlite3.connect(dbpath)
    rows = []
    for rid, j in c.execute('SELECT race_id, race_result_json FROM race_results'):
        d = json.loads(j); info = d.get('raceInfo','')
        sm = re.search(r'(芝|ダ).*?(\d+)m', info)
        if not sm: continue
        ven = VEN.get(rid[4:6])
        if ven is None: continue
        cm = re.search(r'(良|稍重|重|不良)', info)
        if not cm: continue
        cls = classify((d.get('raceGrade','') or '') + ' ' + (d.get('raceTitle','') or ''))
        for h in d.get('horseResults', []):
            if h.get('rank') in ('1','2','3'):
                s = t2s(h.get('time',''))
                if s: rows.append(dict(surf=sm.group(1), dist=int(sm.group(2)), ven=ven,
                                       cond=cm.group(1), cls=cls, year=int(rid[:4]), time=s))
    return pd.DataFrame(rows)

def fit(df):
    models = {}
    for surf in ['芝','ダ']:
        d = df[df.surf == surf].copy()
        if len(d) < 50: continue
        d['dc'] = (d.dist - 1800) / 100.0
        d['yc'] = d.year - 2023
        X = pd.DataFrame({'const':1.0, 'dc':d.dc, 'dc2':d.dc**2, 'yc':d.yc})
        for col, ref in [('ven','東京'), ('cond','良'), ('cls','OP')]:
            du = pd.get_dummies(d[col], prefix=col)
            if f'{col}_{ref}' in du: du = du.drop(columns=[f'{col}_{ref}'])
            X = pd.concat([X, du], axis=1)
        X = X.astype(float)
        beta, *_ = np.linalg.lstsq(X.values, d.time.values, rcond=None)
        coef = dict(zip(X.columns, beta))
        d['resid'] = d.time.values - X.values @ beta
        bands = {}
        for lo, hi in DIST_BANDS[surf]:
            seg = d[(d.dist >= lo) & (d.dist < hi)]
            sd = seg.resid.std() if len(seg) >= 20 else d.resid.std()
            bands[(lo, hi)] = round(10.0 / sd, 2)
        models[surf] = (coef, bands, len(d), d.resid.std())
    return models

def emit_dart(models):
    def fmt_map(items): return ', '.join(f"'{k}': {round(v,3)}" for k, v in items)
    out = []
    out.append('// lib/logic/analysis/speed_index_constants.dart')
    out.append('// [自動生成] tools/speed_index_fit.py により生成。手で編集しないこと。')
    out.append('// 案C: race_results のオフライン重回帰による基準タイム定数(クラス中立=OP基準)。')
    out.append('')
    out.append('class SpeedIndexConstants {')
    out.append('  SpeedIndexConstants._();')
    out.append('  static const double kBaseIndex = 80.0;')
    for surf, key in [('芝','turf'), ('ダ','dirt')]:
        if surf not in models: continue
        coef, bands, n, sd = models[surf]
        vmap = {k.split('_',1)[1]: v for k, v in coef.items() if k.startswith('ven_')}
        vmap['東京'] = 0.0
        cmap = {k.split('_',1)[1]: v for k, v in coef.items() if k.startswith('cond_')}
        cmap['良'] = 0.0
        out.append('')
        out.append(f'  // ---- {surf} (N={n}, 残差SD={sd:.2f}s) ----')
        out.append(f'  static const double {key}Const = {round(coef["const"],3)};')
        out.append(f'  static const double {key}Dc = {round(coef["dc"],4)};')
        out.append(f'  static const double {key}Dc2 = {round(coef["dc2"],5)};')
        out.append(f'  static const double {key}YearTrend = {round(coef["yc"],4)};')
        out.append(f'  static const Map<String, double> {key}VenueOffset = {{{fmt_map(sorted(vmap.items()))}}};')
        out.append(f'  static const Map<String, double> {key}CondOffset = {{{fmt_map(sorted(cmap.items()))}}};')
        band_items = ', '.join(f'[{lo}, {hi}, {c}]' for (lo, hi), c in bands.items())
        out.append(f'  // 距離帯別 距離係数(点/秒): [下限, 上限, 係数]')
        out.append(f'  static const List<List<num>> {key}DistCoef = [{band_items}];')
    out.append('}')
    return '\n'.join(out)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--db', required=True)
    ap.add_argument('--out', default=None)
    a = ap.parse_args()
    df = load(a.db)
    if df.empty:
        print('データが取得できませんでした。', file=sys.stderr); sys.exit(1)
    models = fit(df)
    dart = emit_dart(models)
    if a.out:
        with open(a.out, 'w', encoding='utf-8') as f: f.write(dart + '\n')
        print(f'書き出しました: {a.out}')
    else:
        print(dart)

if __name__ == '__main__':
    main()
