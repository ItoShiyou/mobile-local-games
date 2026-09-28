# だし回し (Stock Pipes)

小料理屋の厨房で、出前ねこが竹の樋を回して、鍋のだしをお椀へ届けるパズルゲームです。
樋をタップすると右回りに90度まわります。すべての樋をつなぎ、一滴もこぼさず、どのお椀にも注文どおりのだし
（鰹・昆布・合わせ・椎茸…）を届けたら完成。「つみあげ出前」「ふすま渡り」と同じねこが主人公の3作目です。

- 全40ステージ（5章）。しかけは合わせだし・鉄の樋・交差する樋・椎茸だし
- どの面も答えはひとつ（全ステージをテストで確認）。目標は答えまでの最少タップ数
- 無制限の「戻す／進む」、次に回す樋を光らせるヒント
- 目標回数と判子（最大3つ）、面ごとの最少回数の記録、続きから再開
- 章ごとに場所が変わる小料理屋の世界観（厨房・乾物蔵・釜場・裏庭・夜なべ）、手描きの線と和紙の質感
- 日本語・英語、昼・夜、アニメーションを減らす設定、キーボード操作、読み上げ対応
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

`test/levels_test.dart` は全ステージを解き直し、答えがちょうどひとつであること、目標回数が最初の配置から答えまでの
タップ数と一致すること、その面のしかけ（合わせだし・鉄の樋・交差・椎茸）が実際に使われていることを確かめます。

## ステージを作り直す

```sh
dart run tool/gen_levels.dart --w=5 --h=6 --trees=kn,k --walls=1 --target=14 --min=9 --n=40
```

鍋ごとに樋の「木」を育てて盤面を埋め、枝の先を鍋とお椀にします。樋をばらばらに回してから解き直し、
答えがひとつだけの盤面のうち、目標に近いタップ数のものを選びます。面ごとの指定は `tool/stage_plan.txt` にあります。

## 構成

```
lib/
  game/     ルール（engine）、解き方の探索（solver）、ステージ（levels）、プレイ状態（controller）
  ui/       画面（title / stage_select / game / settings / how_to_play）
            盤面の描画（board_painter, art, scene）、小料理屋の背景（backdrop）
            操作部品（world_controls：木札・提灯・黒板）、共通部品（widgets, paper, ink_icons）
  app/      テーマ、文言（日英）、設定、進行データ
  audio/    効果音と BGM
tool/
  gen_levels.dart     ステージの自動生成と選別
  stage_plan.txt      全40面の生成条件
  make_audio.py       効果音と BGM の合成
  make_icons.js       アプリアイコンの生成
```

画面まわりの土台は「つみあげ出前」「ふすま渡り」（`apps/tsumiage_demae`, `apps/fusuma_watari`）から写して作っています。

## 自動ビルド

`.github/workflows/dashi_mawashi.yml` が push のたびに解析・テストを行い、Android（APK、デバッグ鍵で署名）と iOS（署名なし）をビルドします。
署名済みの Play 用 AAB は `.github/workflows/dashi_mawashi_release.yml`（`docs/RELEASE.md` 参照）。

## ライセンス

フォント Zen Maru Gothic と Yusei Magic は SIL Open Font License 1.1（`assets/fonts/OFL*.txt`）。アプリ内の「設定 → ライセンス」にも表示されます。
