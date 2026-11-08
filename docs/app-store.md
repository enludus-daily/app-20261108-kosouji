# App Store 提出の準備

> 名前・説明・キーワードなどの正本は `docs/app-store.json`（`.github/workflows/asc.yml` の metadata が App Store Connect に API で入れる）。ここは審査の危険と、本人がすることの記録。

| 項目 | 内容 |
|---|---|
| Bundle ID | com.enludus.daily.006 |
| アプリ名 | こそうじ暦 - 1日10分で大掃除いらず（AI が決めた。本人の許可 2026-11-04） |
| サポート URL | https://github.com/enludus-daily/app-20261108-kosouji/issues |
| プライバシーポリシー URL | https://github.com/enludus-daily/app-20261108-kosouji/blob/main/PRIVACY.md |
| 年齢区分の答え | すべて「なし」の見込み（暴力・性的表現・ギャンブル・Web 閲覧・ユーザー生成コンテンツ・生成 AI なし）。4+ の見込み |
| 輸出コンプライアンス | `ITSAppUsesNonExemptEncryption = NO`（標準の暗号だけ。ビルドの答えは asc が NO で入れる） |

## 審査の危険

- 4.3(b) の種類に当たらない理由：懐中電灯・壁紙・単純なタイマーなどではない。手で用意した 157 か所の掃除のやり方（手順・道具・こつ）と、季節と間隔で今日の 1 か所を決める計画、間取り図での見える化を持つ
- 既存のアプリとの意味のある違い：Tody・Sweepy・Home Tasker は自分で項目を入れる汎用の家事リスト。こそうじ暦は、年末の大掃除を 1 日 10 分に分けることに絞り、やり方つきの場所を手で用意し、間取り図で家全体の状態を見せる
- 長く使える価値（4.2）：1 年で家じゅうが一巡し、年末の大掃除が要らなくなる。最後にやった日が全部残る
- これまでの毎日のアプリとの違い（4.3 の焼き直し）：題材（掃除）、見た目（間取り図・札・mint）、仕組み（間隔と季節の計画）とも別
- 他社の名前・商標・見た目を使っていないか：使っていない（キーワードに他社名なし）
- 薬剤：塩素系と酸性を同じ場所に並べない（テストで確かめる）。混ぜない注意を設定と説明に書いた。高い所・業者向けの作業（エアコンの奥のファン）は「無理をせず業者に」と書いた
- Apple Intelligence：使わない

## 収益の道筋

- 買い切りの Pro ¥480（`com.enludus.daily.006.pro`、ファミリー共有）。理由と比べた表は README の「課金」
- App 内課金は、初めてはアプリのバージョンと一緒に審査に出す（本人）。審査用の画像は `docs/iap/paywall.png`
- Paid Apps Agreement が有効か、本人が確かめる

## App プライバシーの答え（下書き。申告は本人。公開 API がない）

- データの収集：**なし**（根拠：通信しない（StoreKit を除く）、解析・広告 SDK なし、記録は端末の UserDefaults だけ、お知らせは端末の中のローカル通知）
- トラッキング：なし
- Privacy manifest：`App/Resources/PrivacyInfo.xcprivacy`（UserDefaults: CA92.1）

## スクリーンショット

CI の artifact `screenshots`（iPhone Duo のシミュレータ）。`launch onboarding steps done plan room spot calendar empty settings paywall`。

## 本人がすること

- [ ] App プライバシーを申告する（API がない）：「データの収集なし」
- [ ] 年齢区分を答える
- [ ] TestFlight で動作を確かめる（内部テストのグループ `daily-internal` に自動で配信される）。サンドボックスで Pro の購入と復元
- [ ] スクリーンショットを確かめる
- [ ] App 内課金をバージョンと一緒に審査に出す
- [ ] 審査に提出する
