#!/usr/bin/env bash
# logs/ ディレクトリの JSONL をすべてリストし、件数/サマリを表示するだけのヘルパー。
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/logs"
for f in *.jsonl; do
  [ -f "$f" ] || continue
  lines=$(wc -l < "$f" | tr -d ' ')
  echo "$f: $lines rows"
done
