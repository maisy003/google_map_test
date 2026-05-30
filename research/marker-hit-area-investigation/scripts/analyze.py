#!/usr/bin/env python3
"""
Phase 5: 仮説 H1-H5 をログから機械的に判定し、図表と統計を出力する。

使い方:
  python3 scripts/analyze.py [--logs logs/] [--out reports/]

入力:
  logs/*.jsonl  — `run_taps.sh` が出力した JSONL（1タップ1行）

出力:
  reports/raw/summary_by_cell.csv  — 形状×比×アプリ ごとの集計
  reports/raw/hypothesis_results.csv  — 仮説判定一覧
  reports/figures/*.png  — グラフ
  stdout に判定サマリ
"""

import argparse
import csv
import glob
import json
import math
import os
import sys
from collections import defaultdict
from statistics import mean, stdev

# matplotlib は figure 生成のみ。失敗しても集計は出す。
try:
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    HAS_MPL = True
except ImportError:
    HAS_MPL = False


def load_jsonl(paths):
    rows = []
    for p in paths:
        with open(p) as f:
            for line in f:
                line = line.strip()
                if line:
                    rows.append(json.loads(line))
    return rows


def cell_summary(rows):
    """形状 × ratio × app ごとに集計。"""
    cells = defaultdict(list)
    for r in rows:
        key = (r['app_id'], r['shape_id'], r['ratio_id'])
        cells[key].append(r)
    out = []
    for (app, shape, ratio), data in sorted(cells.items()):
        self_hits = [r for r in data if r['fired_marker_id'] == r['marker_id']]
        misses = [r for r in data if r['fired_marker_id'] is None]
        cross_hits = [r for r in data if r['fired_marker_id'] is not None and r['fired_marker_id'] != r['marker_id']]
        dists = [r['distance_px'] for r in self_hits]
        out.append({
            'app_id': app,
            'shape_id': shape,
            'ratio_id': ratio,
            'total_taps': len(data),
            'self_hits': len(self_hits),
            'misses': len(misses),
            'cross_hits': len(cross_hits),
            'max_self_hit_distance': max(dists, default=0),
            'mean_self_hit_distance': round(mean(dists), 2) if dists else 0,
        })
    return out


def evaluate_h1(rows, summary):
    """H1: Android のヒット領域 = ビットマップ矩形 (透明含む)。
    判定: 透明パディングが増える S0→S1→S2→S3 で max_self_hit_distance が
          単調増加するか。R3 (96px bitmap) で評価。"""
    # native app の S0/S1/S2/S3 × R3
    series = {s: 0 for s in ['S0', 'S1', 'S2', 'S3']}
    for cell in summary:
        if cell['app_id'] == 'native' and cell['ratio_id'] == 'R3' and cell['shape_id'] in series:
            series[cell['shape_id']] = cell['max_self_hit_distance']
    vals = [series[s] for s in ['S0', 'S1', 'S2', 'S3']]
    monotonic = all(vals[i+1] >= vals[i] for i in range(len(vals) - 1))
    span = vals[-1] - vals[0] if vals else 0
    return {
        'hypothesis': 'H1',
        'description': '透明パディング増 → ヒット距離単調増 (Android, R3)',
        'data_S0_S1_S2_S3': vals,
        'monotonic': monotonic,
        'span_px': span,
        'verdict': 'pass' if monotonic and span > 0 else (
            'inconclusive' if not series else 'fail'
        ),
    }


def evaluate_h2(rows, summary):
    """H2: iOS のヒット領域 ≒ 可視ピクセル領域。
    本サンプルは Android のみのため判定不能。"""
    return {
        'hypothesis': 'H2',
        'description': 'iOS は可視領域近く判定（本サンプルは Android only）',
        'verdict': 'not_applicable',
        'note': 'iOS は本サンプルの対象外。本番アプリでの目視/手動計測が必要。',
    }


def evaluate_h3(rows, summary):
    """H3: imagePixelRatio で論理サイズが変わり判定矩形も変わる。
    判定: 同じ形状で R1 (32px bitmap) と R3 (96px bitmap, ratio=3.0) と RN (96px, ratio=null)
          で max_hit_distance がどう変わるか。"""
    series = defaultdict(dict)  # shape → ratio → max_d
    for cell in summary:
        if cell['app_id'] == 'native':
            series[cell['shape_id']][cell['ratio_id']] = cell['max_self_hit_distance']
    # S1 (タイト円) を代表例として：R1=32px(visual 84px), R3=96px(visual 84px), RN=96px(visual 96px)
    s1 = series.get('S1', {})
    if not all(k in s1 for k in ('R1', 'R3', 'RN')):
        return {'hypothesis': 'H3', 'verdict': 'inconclusive', 'data': dict(s1)}
    rn_vs_r3 = s1['RN'] - s1['R3']
    return {
        'hypothesis': 'H3',
        'description': 'imagePixelRatio 変更で判定矩形が変わる (S1 で R1/R3/RN 比較)',
        'data_S1_R1_R3_RN': [s1['R1'], s1['R3'], s1['RN']],
        'rn_vs_r3_diff_px': rn_vs_r3,
        'verdict': 'pass' if rn_vs_r3 > 5 else 'inconclusive',
    }


def evaluate_h4(rows, summary):
    """H4: 円+ポインタ形状 (S4) では方向別ヒット率がポインタ尻尾方向 (y+, angle=90°) に偏る。
    判定: native, S4_R3 の self-hit 数を 8 方向で集計。
    """
    direction_hits = defaultdict(int)
    direction_total = defaultdict(int)
    for r in rows:
        if r['app_id'] != 'native' or r['shape_id'] != 'S4' or r['ratio_id'] != 'R3':
            continue
        direction_total[r['angle_deg']] += 1
        if r['fired_marker_id'] == r['marker_id']:
            direction_hits[r['angle_deg']] += 1
    if not direction_total:
        return {'hypothesis': 'H4', 'verdict': 'inconclusive'}
    rates = {d: (direction_hits[d] / direction_total[d]) for d in direction_total}
    # ポインタは下向き = angle 90° (Android y+ = 画面下方向)
    pointer_rate = rates.get(90, 0)
    avg_other = mean([v for d, v in rates.items() if d != 90])
    return {
        'hypothesis': 'H4',
        'description': 'S4 (円+下向きポインタ) の方向別ヒット率に偏り',
        'direction_hit_rates': {d: round(rates[d], 3) for d in sorted(rates)},
        'pointer_dir_rate': round(pointer_rate, 3),
        'avg_other_dir_rate': round(avg_other, 3),
        'verdict': 'pass' if (pointer_rate - avg_other) > 0.10 else 'inconclusive',
    }


def evaluate_h5(rows, summary):
    """H5: フォーク版と公式版で挙動差なし。本サンプルでは省略。"""
    return {
        'hypothesis': 'H5',
        'description': 'フォーク版と公式版で挙動差なし',
        'verdict': 'not_tested',
        'note': '本サンプルではフォーク版 App-Ff を実装せず。',
    }


def plot_max_hit_distance_by_shape(summary, out_path):
    if not HAS_MPL:
        return
    shapes = ['S0', 'S1', 'S2', 'S3', 'S4', 'S5']
    apps = sorted(set(c['app_id'] for c in summary))
    ratios = ['R1', 'R3', 'RN']
    fig, axes = plt.subplots(1, len(apps), figsize=(6 * len(apps), 4))
    if len(apps) == 1:
        axes = [axes]
    for ax, app in zip(axes, apps):
        width = 0.25
        x = list(range(len(shapes)))
        for i, ratio in enumerate(ratios):
            vals = []
            for s in shapes:
                cell = next((c for c in summary if c['app_id'] == app and c['shape_id'] == s and c['ratio_id'] == ratio), None)
                vals.append(cell['max_self_hit_distance'] if cell else 0)
            ax.bar([xi + (i - 1) * width for xi in x], vals, width, label=ratio)
        ax.set_xticks(x)
        ax.set_xticklabels(shapes)
        ax.set_xlabel('shape')
        ax.set_ylabel('max self-hit distance (px)')
        ax.set_title(f'App: {app}')
        ax.legend()
    fig.tight_layout()
    fig.savefig(out_path, dpi=120)
    plt.close(fig)


def plot_h1_padding_effect(summary, out_path):
    if not HAS_MPL:
        return
    fig, ax = plt.subplots(figsize=(6, 4))
    shapes = ['S0', 'S1', 'S2', 'S3']
    pad_pct = [0, 21, 47, 68]
    for app in sorted(set(c['app_id'] for c in summary)):
        vals = []
        for s in shapes:
            cell = next((c for c in summary if c['app_id'] == app and c['shape_id'] == s and c['ratio_id'] == 'R3'), None)
            vals.append(cell['max_self_hit_distance'] if cell else 0)
        ax.plot(pad_pct, vals, marker='o', label=app)
    ax.set_xlabel('transparent padding (% area)')
    ax.set_ylabel('max self-hit distance (px)')
    ax.set_title('H1: padding vs hit-area span (R3)')
    ax.legend()
    ax.grid(True, alpha=0.3)
    fig.tight_layout()
    fig.savefig(out_path, dpi=120)
    plt.close(fig)


def plot_h4_direction(rows, out_path):
    if not HAS_MPL:
        return
    fig = plt.figure(figsize=(6, 6))
    ax = fig.add_subplot(projection='polar')
    direction_hits = defaultdict(int)
    direction_total = defaultdict(int)
    for r in rows:
        if r['app_id'] != 'native' or r['shape_id'] != 'S4' or r['ratio_id'] != 'R3':
            continue
        direction_total[r['angle_deg']] += 1
        if r['fired_marker_id'] == r['marker_id']:
            direction_hits[r['angle_deg']] += 1
    if not direction_total:
        plt.close(fig)
        return
    angles = sorted(direction_total)
    theta = [math.radians(a) for a in angles] + [0]
    rates = [direction_hits[a] / direction_total[a] for a in angles] + [direction_hits[angles[0]] / direction_total[angles[0]] if angles else 0]
    ax.plot(theta, rates, 'o-', linewidth=2)
    ax.fill(theta, rates, alpha=0.25)
    ax.set_title('H4: S4 R3 hit rate by direction (native)')
    fig.tight_layout()
    fig.savefig(out_path, dpi=120)
    plt.close(fig)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--logs', default='logs')
    ap.add_argument('--out', default='reports')
    args = ap.parse_args()

    log_paths = sorted(glob.glob(os.path.join(args.logs, '*.jsonl')))
    if not log_paths:
        print(f'No JSONL files in {args.logs}/', file=sys.stderr)
        sys.exit(1)
    print(f'loaded {len(log_paths)} log files:')
    for p in log_paths:
        print(f'  {p}')

    rows = load_jsonl(log_paths)
    print(f'total tap rows: {len(rows)}')

    summary = cell_summary(rows)
    raw_dir = os.path.join(args.out, 'raw')
    fig_dir = os.path.join(args.out, 'figures')
    os.makedirs(raw_dir, exist_ok=True)
    os.makedirs(fig_dir, exist_ok=True)

    # summary csv
    csv_path = os.path.join(raw_dir, 'summary_by_cell.csv')
    with open(csv_path, 'w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=list(summary[0].keys()) if summary else ['app_id'])
        w.writeheader()
        for row in summary:
            w.writerow(row)
    print(f'wrote {csv_path}')

    # hypothesis evaluations
    results = [
        evaluate_h1(rows, summary),
        evaluate_h2(rows, summary),
        evaluate_h3(rows, summary),
        evaluate_h4(rows, summary),
        evaluate_h5(rows, summary),
    ]
    hyp_path = os.path.join(raw_dir, 'hypothesis_results.json')
    with open(hyp_path, 'w') as f:
        json.dump(results, f, ensure_ascii=False, indent=2)
    print(f'wrote {hyp_path}')

    # figures
    plot_max_hit_distance_by_shape(summary, os.path.join(fig_dir, 'phase5_max_hit_by_shape.png'))
    plot_h1_padding_effect(summary, os.path.join(fig_dir, 'phase5_h1_padding_effect.png'))
    plot_h4_direction(rows, os.path.join(fig_dir, 'phase5_h4_direction.png'))
    print(f'wrote figures → {fig_dir}/')

    # stdout summary
    print('\n=== Hypothesis verdicts ===')
    for r in results:
        print(f"  {r['hypothesis']}: {r.get('verdict')}  — {r.get('description', '')}")


if __name__ == '__main__':
    main()
