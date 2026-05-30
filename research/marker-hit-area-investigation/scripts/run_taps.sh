#!/usr/bin/env bash
# Phase 3-4: 全 18 マーカーに対して 8 方向 × 20 半径 = 160 タップを実施し
# `HITLOG` イベントを集計して JSONL に書き出す。
#
# 使い方:
#   ./scripts/run_taps.sh flutter   # App-F に対して計測
#   ./scripts/run_taps.sh native    # App-A に対して計測
#   ./scripts/run_taps.sh flutter smoke  # スモークテスト (1マーカー × 8タップ)
#
# 出力:
#   logs/<app>_YYYYMMDD_HHMMSS.jsonl  (1タップ1行 JSON)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="${1:-flutter}"
MODE="${2:-full}"

case "$APP" in
  flutter) PKG="com.example.markerhit.flutter_app" ;;
  native)  PKG="com.example.markerhit.nativeapp" ;;
  *) echo "usage: $0 [flutter|native] [full|smoke]" >&2; exit 1 ;;
esac

source "$ROOT/scripts/setup_env.sh" > /dev/null

OUT="$ROOT/logs/${APP}_$(date +%Y%m%d_%H%M%S).jsonl"
mkdir -p "$ROOT/logs"

# ============================================================
# 1) アプリ起動 & MARKER_INDEX を全件取得
# ============================================================
echo "[1/3] starting app: $PKG"
adb shell am force-stop "$PKG" || true
adb logcat -c
adb shell am start -n "$PKG/.MainActivity" > /dev/null

# index_done が出るまで logcat を見て蓄積。最大 240 秒（Maps SDK 初回ロード猶予）。
INDEX_FILE="$(mktemp)"
echo "[1/3] capturing logcat → $INDEX_FILE (timeout 240s; Maps SDK 初回ロード猶予)"
adb logcat -v raw HitLog:I flutter:I "*:S" > "$INDEX_FILE" 2>&1 &
LOG_PID=$!
SECONDS=0
while ! grep -q '"event":"index_done"' "$INDEX_FILE" 2>/dev/null; do
  if [ "$SECONDS" -gt 600 ]; then
    kill "$LOG_PID" 2>/dev/null || true
    echo "ERROR: index_done not received within 240s" >&2
    echo "--- last 20 lines captured ---" >&2
    tail -20 "$INDEX_FILE" >&2
    exit 1
  fi
  if [ $((SECONDS % 20)) -eq 0 ] && [ "$SECONDS" -gt 0 ]; then
    echo "  waiting... ${SECONDS}s elapsed" >&2
  fi
  sleep 2
done
kill "$LOG_PID" 2>/dev/null || true
wait "$LOG_PID" 2>/dev/null || true
INDEX_LINES=$(grep -c '"event":"index"' "$INDEX_FILE" || true)
echo "[1/3] received $INDEX_LINES marker indexes"

# Build a python helper that parses HITLOG lines from the captured file
PARSE_PY="$(mktemp).py"
cat > "$PARSE_PY" <<'EOF'
import json, re, sys
lines = open(sys.argv[1]).read().splitlines()
markers = []
for line in lines:
    m = re.search(r'HITLOG (\{.*\})', line)
    if not m: continue
    try:
        ev = json.loads(m.group(1))
    except Exception:
        continue
    if ev.get('event') == 'index':
        markers.append(ev)
print(json.dumps(markers))
EOF
MARKERS_JSON=$(python3 "$PARSE_PY" "$INDEX_FILE")
COUNT=$(echo "$MARKERS_JSON" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")
echo "[1/3] parsed $COUNT marker specs"
if [ "$COUNT" -lt 1 ]; then
  echo "ERROR: no markers parsed" >&2
  exit 1
fi

# ============================================================
# 2) タップ実行 & 各タップ後の HITLOG event=tap を監視
# ============================================================
echo "[2/3] starting tap measurement (mode=$MODE) → $OUT"

# logcat を継続キャプチャ
TAP_LOG="$(mktemp)"
adb logcat -c
adb logcat -v raw HitLog:I flutter:I "*:S" > "$TAP_LOG" &
TAP_LOG_PID=$!
trap "kill $TAP_LOG_PID 2>/dev/null || true; rm -f $TAP_LOG $INDEX_FILE $PARSE_PY" EXIT

# python ドライバ：各マーカーごとに 8 方向 × 20 半径 = 160 タップ
RUNNER_PY="$(mktemp).py"
cat > "$RUNNER_PY" <<'EOF'
import json, math, os, re, subprocess, sys, time

markers_json = sys.argv[1]
log_path = sys.argv[2]
out_path = sys.argv[3]
mode = sys.argv[4]
device_model = sys.argv[5]
device_os = sys.argv[6]
device_density = int(sys.argv[7])
app_id = sys.argv[8]

markers = json.loads(markers_json)
if mode == "smoke":
    markers = markers[:1]
    radii = [0, 8, 20, 40, 80]
    directions_deg = [0, 90, 180, 270]
else:
    radii = list(range(0, 81, 4))  # 0..80, 4px step → 21 values
    directions_deg = [0, 45, 90, 135, 180, 225, 270, 315]

def adb_tap(x, y):
    subprocess.run(["adb", "shell", "input", "tap", str(x), str(y)], check=False)

def read_new_tap_id(prev_size):
    """Read log file from prev_size onwards, return any tap event id seen, or None."""
    try:
        with open(log_path, 'r') as f:
            f.seek(prev_size)
            new = f.read()
    except FileNotFoundError:
        return None, prev_size
    new_size = prev_size + len(new)
    last_id = None
    for line in new.splitlines():
        m = re.search(r'HITLOG (\{.*\})', line)
        if not m: continue
        try:
            ev = json.loads(m.group(1))
        except Exception:
            continue
        if ev.get('event') == 'tap':
            last_id = ev.get('id')
    return last_id, new_size

with open(out_path, 'w') as out:
    log_pos = os.path.getsize(log_path) if os.path.exists(log_path) else 0
    total_taps = 0
    for mi, spec in enumerate(markers):
        ax = int(spec['anchor_screen_x'])
        ay = int(spec['anchor_screen_y'])
        for r in radii:
            for d in directions_deg:
                rad = math.radians(d)
                tx = int(round(ax + r * math.cos(rad)))
                ty = int(round(ay + r * math.sin(rad)))
                # Avoid status bar / nav bar dead zones
                if ty < 100 or ty > 2300:
                    continue
                adb_tap(tx, ty)
                # 250ms ウィンドウで反応観測
                time.sleep(0.25)
                fired, log_pos = read_new_tap_id(log_pos)
                row = {
                    'app_id': app_id,
                    'marker_id': spec['id'],
                    'shape_id': spec['shape'],
                    'ratio_id': spec['ratio'],
                    'anchor': spec['anchor'],
                    'bitmap_px_w': spec['bitmap_px_w'],
                    'bitmap_px_h': spec['bitmap_px_h'],
                    'logical_pt_w': spec['logical_pt_w'],
                    'logical_pt_h': spec['logical_pt_h'],
                    'tap_screen_x': tx,
                    'tap_screen_y': ty,
                    'marker_anchor_screen_x': ax,
                    'marker_anchor_screen_y': ay,
                    'distance_px': r,
                    'angle_deg': d,
                    'fired_marker_id': fired,
                    'device_model': device_model,
                    'device_os': device_os,
                    'density_dpi': device_density,
                }
                out.write(json.dumps(row) + '\n')
                out.flush()
                total_taps += 1
        print(f"  marker {mi+1}/{len(markers)} {spec['id']} done", flush=True)
    print(f"total taps: {total_taps}", flush=True)
EOF

# device info を取得
DEVICE_MODEL=$(adb shell getprop ro.product.model | tr -d '\r')
DEVICE_OS=$(adb shell getprop ro.build.version.release | tr -d '\r')
DEVICE_DENSITY=$(adb shell wm density | grep -oE '[0-9]+' | head -1)
echo "[2/3] device: $DEVICE_MODEL  OS:$DEVICE_OS  dpi:$DEVICE_DENSITY"

python3 "$RUNNER_PY" "$MARKERS_JSON" "$TAP_LOG" "$OUT" "$MODE" "$DEVICE_MODEL" "$DEVICE_OS" "$DEVICE_DENSITY" "$APP"
rm -f "$RUNNER_PY"

# ============================================================
# 3) サマリ
# ============================================================
LINES=$(wc -l < "$OUT" | tr -d ' ')
echo "[3/3] DONE: $LINES taps recorded → $OUT"
echo "  (use: python3 scripts/analyze.py to evaluate hypotheses)"
