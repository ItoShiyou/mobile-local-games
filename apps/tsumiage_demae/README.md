# つみあげ出前 (Stack & Deliver)

料理の上を通ると頭の上に積み上がり、お客さんには一番上の料理しか渡せない――
どの順番で拾えば全員に届けられるかを考える、倉庫番系のパズルゲームです。
「チルパズル工房 第2弾」の試作をもとに、Flutter で iOS / Android 向けに作りました。

- 全46ステージ（5章）。しかけは返却口・くるりトレイ・一方通行
- 無制限の「1手戻す／1手進む」、最短解にもとづくヒント、盤面で分かるまちがい
- 目標手数と判子（最大3つ）、面ごとの最少手数の記録、続きから再開
- 商店街のねこの出前屋という世界観：章ごとに舞台（食堂・定食屋・喫茶店・路地裏・夏祭り）、手描きの線と和紙の質感、夜営業のダークモード
- 日本語・英語、ライト・ダーク、アニメーションを減らす設定、読み上げ対応
- 効果音・BGM・アイコンはすべてこのリポジトリ内で生成（外部素材なし）
- 通信・広告なし

仕様は [docs/SPEC.md](docs/SPEC.md)、公開手順は [docs/RELEASE.md](docs/RELEASE.md) を参照してください。

## 動かす

```sh
flutter pub get
flutter run            # 接続中の端末やシミュレータで起動
flutter run -d chrome  # ブラウザでも遊べます（開発用）
```

## テスト

```sh
flutter analyze
flutter test
```

`test/levels_test.dart` は全ステージを総当たりで解き、目標手数が最短であること、しかけが解き方に効いていることを確かめます。

## 構成

```
lib/
  game/     ルール（engine）、幅優先探索（solver）、ステージ（levels）、プレイ状態（controller）
  ui/       画面（title / stage_select / game / settings / how_to_play）
            盤面の描画（board_painter, art, scene）、店内の背景（backdrop）
            店の中の操作部品（world_controls：木札・お盆の十字キー・提灯・黒板）
            共通部品（widgets, paper, ink_icons）
  app/      テーマ、文言（日英）、設定、進行データ
  audio/    効果音と BGM
tool/
  gen_levels.dart     ステージ候補の自動生成と選別
  verify_levels.dart  全ステージの最短手数としかけの効き具合を表示
  make_audio.py       効果音と BGM の合成
  make_icons.js       アプリアイコンの生成
```

`lib/game/` は Flutter に依存しない純粋な Dart なので、`dart run tool/...` で直接使えます。

## 自動ビルド

`.github/workflows/tsumiage_demae.yml` が push のたびに解析・テストを行い、Android（APK、デバッグ鍵で署名）と iOS（署名なし）をビルドします。APK は Actions の成果物からダウンロードして実機に入れられます。

## ライセンス

フォント Zen Maru Gothic と Yusei Magic は SIL Open Font License 1.1（`assets/fonts/OFL*.txt`）。アプリ内の「設定 → ライセンス」にも表示されます。
