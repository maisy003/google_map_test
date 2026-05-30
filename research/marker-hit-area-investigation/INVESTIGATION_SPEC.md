# Google Maps カスタムマーカー 当たり判定調査 サンプルアプリ 実装指示書

本リポジトリは、Android 版で観測されているマーカーの当たり判定異常を仮説検証するためのサンプルアプリ群です。完全な仕様は会話プロンプトとして渡されたものを参照（このリポジトリの目的の要約のみここに記載）。

## 目的（要約）

- Android のカスタムマーカーのヒット領域が、ビットマップの矩形（透明ピクセル含む）に一致しているかをデータで確定する
- iOS との非対称（同じ画像で iOS は可視領域近く判定）を再現
- 本番修正方針を計測値で根拠付けて提示

## 仮説

| ID | 仮説 |
|----|------|
| H1 | Android のヒット領域 = ビットマップの矩形バウンディング |
| H2 | iOS のヒット領域 ≒ 可視ピクセル領域 |
| H3 | imagePixelRatio で論理サイズが変わり判定矩形も変わる |
| H4 | 円+ポインタ形状ではポインタ尻尾脇に偏る |
| H5 | フォーク版と公式版で挙動差なし |

本サンプルアプリでは **Android のみ** を対象とする。iOS は対象外。

## 構成

```
flutter_app/         App-F: 公式 google_maps_flutter
android_native_app/  App-A: Maps SDK for Android 直接
scripts/             adb タップ実行・ログ収集・分析
logs/                JSON Lines ログ
reports/             統計・図表・最終レポート
```

## 計測対象

形状 6 種 × ピクセル比 3 種 = 18 マーカー、各 160 タップ。
詳細はプロンプト仕様参照。

## 実行方法

1. local.properties に `MAPS_API_KEY=...` を記載
2. `scripts/setup_env.sh` を `source`
3. AVD 起動: `emulator -avd MarkerHitTest_API36 -no-snapshot &`
4. App-F 計測: `scripts/run_flutter_measurement.sh`
5. App-A 計測: `scripts/run_android_measurement.sh`
6. 分析: `python3 scripts/analyze.py`
7. レポート: `reports/final_report.md`
