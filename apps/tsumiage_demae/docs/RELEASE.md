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

- [ ] `flutter analyze` と `flutter test` が通る
- [ ] Android 実機・iOS 実機で、音（マナーモード時は無音）、振動、バックグラウンド復帰時のBGMを確認
- [ ] 小さい画面（iPhone SE）と大きい画面（タブレット）でレイアウトを確認
- [ ] 端末の文字サイズを最大にして、はみ出しがないか確認
- [ ] ダークモード、英語表示を確認
- [ ] 1面から最終面まで通しでプレイ
