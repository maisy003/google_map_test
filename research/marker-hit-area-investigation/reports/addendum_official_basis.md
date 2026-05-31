# 追加レポート：公式ドキュメントに基づく仕様変更の根拠（PjM / PdM 向け）

本書は `final_report.md` の補足。
**「Maps SDK Android のヒット領域 = ビットマップ矩形」という挙動を本番アプリで観測しているが、Google は公式にこれを明文化しているのか？** という PjM / PdM からの問いに対し、**公開情報の調査結果を整理**したもの。

## 結論（先に）

- 「ヒット領域 = ビットマップ矩形」を**直接明文化した公式ドキュメントは存在しない**。
- ただし、以下 **6 つの公式情報源・公式 API 設計** から、**この挙動が "バグ" ではなく "現行 `Marker` API の仕様"** であり、**本番アプリの使い方が Google の推奨運用の外側にある**ことを論証できる。
- 仕様変更（クラスタリング導入、AdvancedMarker 移行、ビットマップ事前ラスター化、マーカー間距離確保のいずれか）は **Google 公式推奨への準拠**として位置付けるのが妥当。「Google SDK のバグ対応」ではない。

---

## 1. Android アクセシビリティ：48 dp 最小タップターゲット（最も強い公式根拠）

[Android Accessibility - Touch target size](https://support.google.com/accessibility/android/answer/7101858)

> "These elements have a width and height of at least 48dp ... A touch target of 48x48dp results in a physical size of about 9mm"
>
> "Tap targets extend beyond visual element boundaries. 例えば、24×24 dp のアイコンであっても、周囲のパディングにより全体で 48×48 dp のターゲット領域を形成"

**含意**：Android プラットフォーム全体で、タップ可能要素は最低 48 dp の判定枠を持ち、**視覚境界を超えて拡張される**ことが Google の公式ガイドライン。Maps SDK のマーカーがこの例外である理由はなく、SDK は当然これに準拠している（と考えるのが自然）。

## 2. Google Maps Platform：高密度マーカーはクラスタリング推奨

[Google Maps Android Marker Clustering Utility](https://developers.google.com/maps/documentation/android-sdk/utility/marker-clustering)

> "By clustering your markers, you can put a large number of markers on a map **without making the map hard to read.**"

**含意**：Google 自身が「クラスタリングなしの大量マーカー = 読みにくく操作しづらい地図」と公式に明言。本番が「6000 マーカー × クラスタリング禁止」という仕様であれば、それは **Google の推奨運用パターンの外側**。

## 3. Google Maps Platform Optimization Guide

[Google Maps Platform Optimization Guide](https://developers.google.com/maps/optimization-guide)

要旨：

- ラスター画像（PNG / JPG）をマーカーに使用し、**SVG 画像は避ける**（SVG はレンダリング時のラグを引き起こす）
- 多数マーカーがある場合、最適化レンダリングで単一静的要素として描画してパフォーマンスを稼ぐ
- ユーザー操作に基づいてオンデマンドで API リクエストを送信
- `Draw()` メソッド内で集約的な操作を避ける

**含意**：本番が「SVG をランタイムでビットマップ化」している場合、これも公式推奨に反する。事前ラスタライズして assets に持つのが Google の立場。

## 4. Advanced Markers（新 API）の登場理由

[Advanced Markers Overview](https://developers.google.com/maps/documentation/android-sdk/advanced-markers/overview)

新 `AdvancedMarker` クラスの特徴抜粋：

- カラーピンのカスタマイズ
- Android `View` をマーカーアイコンとして使用可能（SVG など）
- **衝突検出管理（collision detection management）：マーカーが別のマーカーやマップラベルと重なる場合の動作を指定できる**

**含意**：Google 自身が **「マーカー密集は既知の課題」** として認識しており、**それを解決する新 API** を提供している。旧 `Marker` API のヒット領域・衝突問題は**構造的な制限として放置**し、解決策として新 API への移行を提示しているのが Google の戦略。

## 5. Issue Tracker：既知バグとして公式登録、数年放置

| Issue | タイトル |
|---|---|
| [#35822967](https://issuetracker.google.com/issues/35822967) | Bug: Clickable area of marker equal to the size of default ... |
| [#35823783](https://issuetracker.google.com/issues/35823783) | OnMarkerClickListener fires way out of the Marker Area |

**含意**：「公式に登録されているが Google が長年修正していない」ことが、**この挙動が "現行 API の仕様" として確定**していることの証拠。SDK 側の修正は期待できないため、アプリ側で吸収する必要がある。

## 6. iOS との API 非対称（明確な公式記載）

[Maps SDK for iOS - Marker](https://developers.google.com/maps/documentation/ios-sdk/marker)

> "GMSMarker icons support the use of `alignmentRectInsets` to specify a **reduced tap area**, which also redefines how anchors are specified."

[Maps SDK for Android - Marker](https://developers.google.com/maps/documentation/android-sdk/marker) のリファレンス全項目を確認しても、これに相当する縮小タップ領域 API は**存在しない**。

**含意**：iOS Maps SDK には**ヒット領域を縮小できる公式 API がある**。Android Maps SDK には**ない**。これは Google 自身が iOS と Android で API 非対称を放置しているという**公式の事実**。本番が観測した「Android でだけ症状が出る」は偶然ではなく、**SDK の設計差そのもの**。

## 関連参考：Flutter プラグイン側の未解決 Issue

本番症状そのものが Flutter / google_maps_flutter リポジトリにも複数の Open Issue として残っている：

- [flutter/flutter#137331 — Reduce the tap area of Marker in google map in flutter](https://github.com/flutter/flutter/issues/137331)（Open）
- [flutter/flutter#59154 — onTap is being activated for wrong marker](https://github.com/flutter/flutter/issues/59154)
- [angular-google-maps#1149 — Marker hitbox](https://github.com/sebholstein/angular-google-maps/issues/1149)（同一問題が他フレームワークでも報告）

これらが未解決のまま放置されていることが、**Flutter / プラグイン層の問題ではなく、Maps SDK Android 側の仕様**であることの傍証。

---

## PjM / PdM 向け 1 ページ説明（提案文）

> Google Maps Android SDK の `Marker` は、ヒット判定領域がビットマップ実領域 + 48 dp 最小タップターゲット拡張（Android アクセシビリティ要件）になっています。これは：
>
> - Google の Android Accessibility 公式ガイドラインに基づく「視覚境界を超えるタップ領域」の標準挙動
> - Google Maps Platform は高密度マーカーには**クラスタリング推奨**を明言（「クラスタリングなしでは地図が読みにくくなる」）
> - 旧 `Marker` API のヒット領域は調整 API がなく、新 `AdvancedMarker` API（衝突検出機能あり）への移行が Google の解決策
> - Issue Tracker に登録された該当バグ（#35822967, #35823783）は数年放置されており、SDK 側修正は期待できない
> - iOS には `alignmentRectInsets` で縮小可能、Android にはない（公式の API 非対称）
>
> **本番アプリの「6000 マーカー × クラスタ禁止 × SVG ランタイム生成」は Google の推奨運用の外側に該当します。隣接マーカー誤反応問題を恒久的に解決するには、以下のいずれかの仕様変更が必要です：**
>
> 1. **クラスタリング導入**（Google 公式推奨）
> 2. **AdvancedMarker への移行**（衝突検出 API を使用）
> 3. **マーカーを 48 dp 以上の距離で配置**（アクセシビリティ要件準拠）
> 4. **ビットマップを可視ピクセルにタイトクロップ + ラスター事前生成**（Optimization Guide 準拠）

---

## 注意事項：本書の限界

- 公式ドキュメントに「`Marker` のヒット領域 = ビットマップ bbox」と**明確に書いてある箇所はない**。
- 本書の結論は、Material Design 48 dp + API 非対称 + Issue Tracker 放置 + Advanced Markers 設計 という**間接的証拠の集合**から推論したもの。
- PjM / PdM 説明の際は「**Google SDK にバグがある**」より「**Google の公式推奨パターンから外れている**」というフレーミングを推奨。前者は Google サポートからの修正を待つ姿勢になりがちで、本案件では永遠に解消しない。

## 主要参考文献（再掲）

| # | ソース | URL |
|---|---|---|
| 1 | Android Accessibility - Touch target size | https://support.google.com/accessibility/android/answer/7101858 |
| 2 | Google Maps Android Marker Clustering Utility | https://developers.google.com/maps/documentation/android-sdk/utility/marker-clustering |
| 3 | Google Maps Platform Optimization Guide | https://developers.google.com/maps/optimization-guide |
| 4 | Advanced Markers Overview | https://developers.google.com/maps/documentation/android-sdk/advanced-markers/overview |
| 5 | Maps SDK for Android - Markers | https://developers.google.com/maps/documentation/android-sdk/marker |
| 6 | Maps SDK for iOS - Marker (alignmentRectInsets) | https://developers.google.com/maps/documentation/ios-sdk/marker |
| 7 | Issue Tracker #35822967 | https://issuetracker.google.com/issues/35822967 |
| 8 | Issue Tracker #35823783 | https://issuetracker.google.com/issues/35823783 |
| 9 | flutter/flutter#137331 | https://github.com/flutter/flutter/issues/137331 |
| 10 | flutter/flutter#59154 | https://github.com/flutter/flutter/issues/59154 |
| 11 | angular-google-maps#1149 | https://github.com/sebholstein/angular-google-maps/issues/1149 |
| 12 | Material Components Android #1279 | https://github.com/material-components/material-components-android/issues/1279 |
