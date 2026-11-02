# App Store 公開ガイド（つみあげ出前）

Mac がなくても公開できるように、署名とアップロードは GitHub Actions（`tsumiage_demae iOS release`）が行います。
持ち主がするのは、Apple のアカウント作業と、App Store Connect への入力だけです。上から順に進めてください。

画面の名前やメニューの場所は Apple 側で変わることがあります（2026年11月時点の名前で書いています）。

## アプリ側で用意済みのもの

| 項目 | 内容 |
| --- | --- |
| Bundle ID | `io.github.itoshiyou.tsumiageDemae`（公開後は変更不可） |
| バージョン | `pubspec.yaml` の `version`（いまは 1.1.0）。ビルド番号は Actions の実行番号で自動的に増える |
| 対応端末 | iPhone（縦）・iPad（縦、フルスクリーン）。iOS 15 以上 |
| ホーム画面の名前 | 日本語端末「つみあげ出前」、英語端末「Stack & Deliver」 |
| アイコン | 1024×1024 を含む全サイズ（App Store の規定どおりアルファチャンネルなし） |
| プライバシーマニフェスト | `ios/Runner/PrivacyInfo.xcprivacy`（トラッキングなし・収集データなし・UserDefaults は理由 CA92.1） |
| 輸出コンプライアンス | `ITSAppUsesNonExemptEncryption = false`（暗号化なし。提出時の質問は出ない） |
| スクリーンショット | `store/screenshots/ios/{ja,en}/`（iPhone 6.9インチ 1290×2796）、`store/screenshots/ipad/{ja,en}/`（iPad 13インチ 2048×2732）。各6枚 |
| 掲載文 | `store/listing.md`（日英。文字数チェック済み） |
| 申告の回答 | `store/declarations.md` |

## 1. Apple Developer Program に登録する（初回のみ）

1. https://developer.apple.com/programs/ から個人として登録する（年会費あり）。
2. 承認後、https://developer.apple.com/account の「メンバーシップの詳細」で **チーム ID**（英数字10桁）を控える。

## 2. Bundle ID を登録する（初回のみ）

1. https://developer.apple.com/account/resources/identifiers/list で「＋」を押す。
2. 「App IDs」→「App」を選ぶ。
3. 次のとおり入力する。
   - Description：`Tsumiage Demae`
   - Bundle ID：Explicit で `io.github.itoshiyou.tsumiageDemae`
   - Capabilities：何もチェックしない
4. 「Register」を押す。

## 3. App Store Connect にアプリを作る（初回のみ）

1. https://appstoreconnect.apple.com →「アプリ」→「＋」→「新規App」を開く。
2. 次のとおり入力する。
   - プラットフォーム：iOS
   - 名前：`つみあげ出前`
   - プライマリ言語：日本語
   - バンドルID：上で登録した `io.github.itoshiyou.tsumiageDemae`
   - SKU：`tsumiage-demae`（自分用の管理番号。何でもよい）
   - ユーザアクセス：フルアクセス

## 4. アップロード用の API キーを作る（初回のみ。ほかのアプリと共通）

1. App Store Connect →「ユーザとアクセス」→「統合」→「App Store Connect API」→「チームキー」→「＋」を開く。
2. 名前は `GitHub Actions`、アクセスは **Admin** にする。
   - Admin なのは、Xcode がクラウドで配布用の証明書とプロビジョニングプロファイルを自動で作るためです。
3. 作成後に次の3つを控える。
   - `AuthKey_XXXXXXXXXX.p8`：ダウンロードは **1回だけ** しかできません。
   - キーID
   - 一覧の上にある発行者ID（Issuer ID）

## 5. GitHub にシークレットを登録する（初回のみ）

リポジトリの Settings → Secrets and variables → Actions →「New repository secret」で、次の4つを登録します。
ふすま渡り・だし回しを出すときも同じものを使えます。

| 名前 | 中身 |
| --- | --- |
| `APPLE_TEAM_ID` | 手順1のチーム ID |
| `APPSTORE_API_KEY_ID` | 手順4のキーID |
| `APPSTORE_API_ISSUER_ID` | 手順4の発行者ID |
| `APPSTORE_API_PRIVATE_KEY` | `.p8` ファイルをテキストで開いた中身（`-----BEGIN PRIVATE KEY-----` から `-----END PRIVATE KEY-----` まで全部） |

## 6. ビルドを上げる

1. GitHub の Actions タブ →「tsumiage_demae iOS release」→「Run workflow」を押す。
   - `tsumiage-v1.1.0` のようなタグを push しても動きます。
2. テストと署名を通り、App Store Connect にアップロードされるまで、20分前後かかります。
3. アップロード後、Apple 側の処理に10〜30分ほどかかります。その後 App Store Connect の「TestFlight」にビルドが出ます。
4. TestFlight の「内部テスト」に自分を追加し、iPhone の TestFlight アプリから実機で遊んで確認します（下の「実機での最終確認」）。

失敗したときは、Actions のログの最初の赤いエラーを見てください。よくある原因は次の3つです。

| エラー | 原因と対処 |
| --- | --- |
| `App Store Connect secrets are missing` | 手順5のシークレットが足りない |
| `No profiles for ...` や `No Account for Team` | キーのアクセスが Admin でない、チーム ID が違う、Bundle ID が未登録（手順2） |
| `The bundle version must be higher` | 同じビルド番号は二度と使えない。もう一度実行すれば番号が増える |

## 7. App Store Connect に入力する

### アプリ情報（左メニュー「アプリ情報」）

| 項目 | 入力 |
| --- | --- |
| サブタイトル | `store/listing.md` の「サブタイトル」 |
| カテゴリ | プライマリ：ゲーム、サブカテゴリ：パズル／ファミリー |
| 年齢制限指定 | すべて「なし」→ 4+（`store/declarations.md`） |
| コンテンツ配信権 | 「サードパーティのコンテンツを含まない」 |
| 英語（米国）のローカライズ | 右上の言語から「英語（米国）」を追加。名前 `Stack & Deliver` と英語の掲載文を入れる |

### App のプライバシー（左メニュー）

- プライバシーポリシーの URL：`store/privacy-policy.html` を公開したURL（下の「公開URLの用意」）
- データの収集：「いいえ、このAppからデータを収集していません」

### 価格および配信状況

- 価格：無料（0円）
- 配信国：すべて（または日本のみ）

### バージョンのページ（「iOS App」の「1.1.0 提出準備中」）

| 項目 | 入力 |
| --- | --- |
| スクリーンショット（iPhone 6.9インチ） | `store/screenshots/ios/ja/01.png`〜`06.png`（英語のページには `ios/en/`） |
| スクリーンショット（iPad 13インチ） | `store/screenshots/ipad/ja/01.png`〜`06.png`（英語のページには `ipad/en/`） |
| プロモーションテキスト・概要・キーワード | `store/listing.md` からそのまま |
| サポートURL | 下の「公開URLの用意」 |
| 著作権 | `2026 （開発者名）` |
| ビルド | 手順6で上がったビルドを選ぶ |
| サインインが必要 | オフにする（アカウントなし） |
| 連絡先情報 | 名前・電話番号・メール（審査担当者だけが見る） |
| メモ | 下の文をそのまま貼る |
| リリース方法 | 「このバージョンを手動でリリースする」がおすすめ（承認後に好きなタイミングで公開できる） |

審査メモ（そのまま使えます）：

```
This is an offline puzzle game. No account, network access, ads or in-app purchases.
Tap "はじめる" (Start) on the title screen; the first stage has a short tutorial.
The language can be switched to English in Settings (gear icon, top right).
```

### 公開URLの用意（プライバシーポリシーとサポート）

1. `store/privacy-policy.html` と `store/support.html` の「（開発者名）」「（連絡先メールアドレス）」を埋める。
2. 2つのページをどこかに公開する。いちばん手軽なのは GitHub Pages です。
   - 公開用のリポジトリ（public）に2つのファイルを置く。
   - Settings → Pages → Branch を `main` / `root` にして保存する。
   - `https://<ユーザー名>.github.io/<リポジトリ名>/privacy-policy.html` で開けるようになります。

## 8. 審査に出す

1. バージョンのページで「審査用に追加」→「審査に提出」を押す。
2. 審査は通常1〜2日です。
   - 承認されると「デベロッパによるリリース待ち」になるので、「このバージョンをリリース」で公開します。
   - 却下されたときは、理由が「App Review」に届きます。内容を貼ってもらえれば対応します。

## 2回目以降のアップデート

1. `pubspec.yaml` の `version` と、`lib/ui/settings_screen.dart` の `appVersion` を上げる（例 1.1.0 → 1.2.0）。
2. 手順6を実行し、App Store Connect で新しいバージョンを作って、手順7と8を繰り返す。

## 実機での最終確認（TestFlight で）

- [ ] 音（消音スイッチがオンなら無音）、振動、ホームに戻って復帰したときの BGM
- [ ] 小さい iPhone（SE）と iPad で見た目
- [ ] ダークモード、英語表示（ホーム画面の名前が「Stack & Deliver」になる）
- [ ] 1面から最終面まで通しでプレイ
