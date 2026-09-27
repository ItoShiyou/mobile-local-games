# リリース手順

## 事前準備

- Flutter 3.47 以降（stable）
- Android: Android Studio / Android SDK、JDK 17
- iOS: Xcode、Apple Developer アカウント

```sh
cd apps/tsumiage_demae
flutter pub get
flutter analyze
flutter test
```

## バージョン

`pubspec.yaml` の `version: 1.0.0+1`（`表示バージョン+ビルド番号`）を上げます。
設定画面の表示は `lib/ui/settings_screen.dart` の `appVersion` です。

## Android

1. アップロード鍵を作る（初回のみ。鍵とパスワードはリポジトリに入れない）

   ```sh
   keytool -genkey -v -keystore ~/tsumiage-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

2. `android/key.properties` を作る（`.gitignore` 済み）

   ```properties
   storePassword=...
   keyPassword=...
   keyAlias=upload
   storeFile=/Users/you/tsumiage-upload.jks
   ```

   このファイルがないと、リリースビルドはデバッグ鍵で署名されます（手元での動作確認用）。

3. ビルド

   ```sh
   flutter build appbundle --release
   # build/app/outputs/bundle/release/app-release.aab を Play Console へ
   ```

   GitHub Actions でも作れます（手元に Android SDK がなくてよい）。リポジトリの
   Settings → Secrets and variables → Actions に次の4つを登録し、Actions タブで
   「tsumiage_demae release」を実行するか、`tsumiage-v1.0.0` のようなタグを push します。

   | シークレット | 中身 |
   | --- | --- |
   | `TSUMIAGE_UPLOAD_KEYSTORE_BASE64` | `base64 -w0 ~/tsumiage-upload.jks` の出力（mac は `base64 -i ~/tsumiage-upload.jks`） |
   | `TSUMIAGE_UPLOAD_STORE_PASSWORD` | キーストアのパスワード |
   | `TSUMIAGE_UPLOAD_KEY_PASSWORD` | 鍵のパスワード |
   | `TSUMIAGE_UPLOAD_KEY_ALIAS` | `upload` |

   署名済みの `tsumiage_demae-aab` がアーティファクトとして残ります。ビルド番号は実行番号で自動的に増えます。
   シークレットがないときは、デバッグ署名のまま進まないように失敗します。
   Play Console では「Play アプリ署名」を有効にしたまま、この AAB を内部テストに上げてから製品版へ進めます。

- アプリ ID: `io.github.itoshiyou.tsumiage_demae`（公開後は変更不可。変える場合は公開前に
  `android/app/build.gradle.kts` の `applicationId` と `namespace`、`MainActivity.kt` のパッケージを変更）
- アプリ名: 日本語「つみあげ出前」、英語「Stack & Deliver」（`res/values*/strings.xml`）
- 縦画面固定、アダプティブアイコン（テーマアイコン対応）

## iOS

1. Xcode で `ios/Runner.xcworkspace` を開き、Signing & Capabilities で Team を設定
2. Bundle Identifier を決める（既定は `io.github.itoshiyou.tsumiageDemae`）
3. ビルド

   ```sh
   flutter build ipa --release
   # build/ios/ipa/*.ipa を Transporter か Xcode Organizer でアップロード
   ```

- `ITSAppUsesNonExemptEncryption = false` 設定済み（輸出コンプライアンスの質問を省略）
- iPhone は縦のみ、iPad は縦（上下）でフルスクリーン

## アイコン・音を作り直す

```sh
node tool/make_icons.js      # Playwright が必要。iOS/Android/Web/ストア用を一括生成
python3 tool/make_audio.py   # 効果音と BGM（外部素材なし）
```

## ストア掲載用の素材

すべて `store/` にあります。

| 素材 | ファイル | 作り直し方 |
| --- | --- | --- |
| スクリーンショット（iPhone 1290×2796、Android 1080×1920、日英各6枚） | `store/screenshots/{ios,android}/{ja,en}/` | Web版をビルドして配信し `node tool/make_store_screens.js` |
| Play のフィーチャーグラフィック（1024×500） | `store/feature-graphic-{ja,en}.png` | 同上 |
| アイコン（Play 用 512×512） | `store/icon-512.png` | `node tool/make_icons.js` |
| 掲載文（アプリ名・サブタイトル・説明文・キーワードなど） | `store/listing.md` | 文字数は `python3 tool/check_listing.py` で確認 |
| プライバシーポリシー | `store/privacy-policy.html` | 開発者名と連絡先を埋めて公開する |
| プライバシー申告・年齢レーティングの回答 | `store/declarations.md` | — |

## プライバシー

通信・広告・解析・アカウントを一切使わず、進行データは端末内（SharedPreferences）にだけ保存します。
App Store の App Privacy は「データを収集しない」、Google Play のデータセーフティは「収集・共有なし」で申告できます。

## 公開前チェックリスト

### 開発側（済）

- [x] `flutter analyze` と `flutter test` が通る（CI でも Android / iOS のビルドまで確認）
- [x] 全46面が解けること・目標手数が最短であることをテストで確認
- [x] 小さい画面（320×568）〜タブレット（820×1180）で全章のレイアウトを確認
- [x] 端末の文字サイズ最大（アプリ内では1.3倍まで反映）で全画面がはみ出さない
- [x] 日本語／英語、昼／夜、動きを減らす、読み上げ
- [x] ストア用スクリーンショット・フィーチャーグラフィック・掲載文・申告内容

### 持ち主が行うこと

- [ ] 開発者名と連絡先メールを決め、`store/privacy-policy.html` と `store/listing.md` の（開発者名）を埋める
- [ ] プライバシーポリシーを公開URLに置く（GitHub Pages、個人サイトなど。App Store と Play の両方で必須）
- [ ] サポートURL（App Store 必須。問い合わせ先が書かれたページで可）
- [ ] Google Play デベロッパー登録、アップロード鍵の作成と上記シークレットの登録
- [ ] Apple Developer Program 登録、Xcode で Team を設定して `flutter build ipa`
- [ ] 実機での最終確認（以下）

#### 実機での最終確認

- [ ] Android 実機・iOS 実機で、音（マナーモード時は無音）、振動、バックグラウンド復帰時のBGMを確認
- [ ] 小さい画面（iPhone SE）とタブレットで見た目を確認
- [ ] ダークモード、英語表示を確認
- [ ] 1面から最終面まで通しでプレイ
