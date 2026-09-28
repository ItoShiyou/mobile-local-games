# ふすま渡り (Sliding Doors Inn)

古い旅館で、出前ねこがふすまを押して客間まで料理を届けるパズルゲームです。
ふすまは敷居にそってしか動かず、押した向きにすべるだけ――どのふすまを、どちらへ、どの順で動かせば
お客さんのもとへたどり着けるかを考えます。「つみあげ出前」と同じねこが主人公の2作目です。

- 全40ステージ（5章）。しかけは対のふすま・女将さんの鍵・回り障子、お客さんがふたりの間
- 無制限の「1手戻す／1手進む」、最短解にもとづくヒント、詰んだら「戻す」の札がそっと揺れる
- 目標手数と判子（最大3つ）、面ごとの最少手数の記録、続きから再開
- 章ごとに棟が変わる旅館の世界観（一階の客間・離れ・帳場・茶室・宴会の夜）、手描きの線と和紙の質感
- 日本語・英語、昼・夜、アニメーションを減らす設定、読み上げ対応
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

`test/levels_test.dart` は全ステージを総当たりで解き、目標手数が最短であること、ふすまを押さないと解けないこと、
その面のしかけ（対のふすま・鍵・回り障子）が最短の解き方で必ず使われることを確かめます。

## ステージを作り直す

```sh
dart run tool/gen_levels.dart --w=7 --h=6 --walls=4 --doors=6 --guests=1 --pair --target=18 --n=160 --seeds=60
```

ランダムな部屋ごとに、たどり着けるすべての配置を調べ、「台所の戸口から始めて、最低でも押す回数がいちばん多い配置」を選びます。
面ごとの指定は `tool/stage_plan.txt` にあります。

## 構成

```
lib/
  game/     ルール（engine）、幅優先探索（solver）、ステージ（levels）、プレイ状態（controller）
  ui/       画面（title / stage_select / game / settings / how_to_play）
            盤面の描画（board_painter, art, scene）、旅館の背景（backdrop）
            操作部品（world_controls：木札・お盆の十字キー・提灯・黒板）、共通部品（widgets, paper, ink_icons）
  app/      テーマ、文言（日英）、設定、進行データ
  audio/    効果音と BGM
tool/
  gen_levels.dart     ステージの自動生成と選別
  stage_plan.txt      全40面の生成条件
  make_audio.py       効果音と BGM の合成
  make_icons.js       アプリアイコンの生成
```

画面まわりの土台は「つみあげ出前」（`apps/tsumiage_demae`）から写して作っています。

## 自動ビルド

`.github/workflows/fusuma_watari.yml` が push のたびに解析・テストを行い、Android（APK、デバッグ鍵で署名）と iOS（署名なし）をビルドします。
署名済みの Play 用 AAB は `.github/workflows/fusuma_watari_release.yml`（`docs/RELEASE.md` 参照）。

## ライセンス

フォント Zen Maru Gothic と Yusei Magic は SIL Open Font License 1.1（`assets/fonts/OFL*.txt`）。アプリ内の「設定 → ライセンス」にも表示されます。
