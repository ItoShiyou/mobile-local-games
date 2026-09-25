import 'package:flutter/widgets.dart';

import '../game/engine.dart';
import 'scope.dart';

/// All user-facing text, in Japanese and English.
abstract class Strings {
  const Strings();

  static Strings of(BuildContext context) => AppScope.of(context).settings.strings(context);

  String get appTitle;
  String get tagline;

  // Title
  String get play;
  String get continueFrom;
  String get stages;
  String get howToPlay;
  String get settings;

  // Stage select
  String chapterLabel(int n);
  String clearedCount(int n, int total);
  String get locked;
  String get lockedHint;
  String starsTotal(int n, int total);

  // Game HUD
  String get onHead;
  String get empty;
  String capacity(int n);
  String delivered(int done, int total);
  String movesLabel(int n);
  String parLabel(int n);
  String bestLabel(int? n);
  String get undo;
  String get redo;
  String get restart;
  String get hint;
  String get rules;
  String get back;

  // Feedback
  String blocked(Blocked b, {String? wanted, String? top});
  String get stuckTitle;
  String get stuckBody;
  String hintArrow(Dir d);

  // Result
  String get clearTitle;
  String clearBody(int moves, int par);
  String get newBest;
  String get perfect;
  String get next;
  String get retry;
  String get toStages;
  String get allClearTitle;
  String get allClearBody;

  // Rules and gimmicks
  String get ruleShort;
  List<(String, String)> get howToPages;
  String gimmickName(String id);
  String gimmickDesc(String id);
  String get newGimmick;
  String get gotIt;
  String dishName(String c);

  // Settings
  String get sound;
  String get music;
  String get haptics;
  String get language;
  String get languageSystem;
  String get theme;
  String get themeSystem;
  String get themeLight;
  String get themeDark;
  String get reduceMotion;
  String get reduceMotionSub;
  String get resetProgress;
  String get resetConfirm;
  String get resetDone;
  String get cancel;
  String get reset;
  String get licenses;
  String get version;

  // Accessibility
  String boardSummary(GameState s);
  String get keyboardHelp;
}

String _dirJa(Dir d) => switch (d) { Dir.up => '上', Dir.down => '下', Dir.left => '左', Dir.right => '右' };
String _dirEn(Dir d) => switch (d) { Dir.up => 'up', Dir.down => 'down', Dir.left => 'left', Dir.right => 'right' };

class StringsJa extends Strings {
  const StringsJa();

  @override
  String get appTitle => 'つみあげ出前';
  @override
  String get tagline => '頭の上に積んで、順番どおりにお届け';
  @override
  String get play => 'あそぶ';
  @override
  String get continueFrom => 'つづきから';
  @override
  String get stages => 'ステージ';
  @override
  String get howToPlay => 'あそびかた';
  @override
  String get settings => '設定';
  @override
  String chapterLabel(int n) => '第$n章';
  @override
  String clearedCount(int n, int total) => '$n / $total クリア';
  @override
  String get locked => 'まだ遊べません';
  @override
  String get lockedHint => '前のステージをクリアすると遊べるようになります。';
  @override
  String starsTotal(int n, int total) => '★ $n / $total';
  @override
  String get onHead => '頭の上';
  @override
  String get empty => 'なし';
  @override
  String capacity(int n) => '最大 $n 皿';
  @override
  String delivered(int done, int total) => '配達 $done / $total';
  @override
  String movesLabel(int n) => '$n 手';
  @override
  String parLabel(int n) => '目標 $n 手';
  @override
  String bestLabel(int? n) => n == null ? '最少 —' : '最少 $n 手';
  @override
  String get undo => '1手戻す';
  @override
  String get redo => '1手進む';
  @override
  String get restart => 'やり直す';
  @override
  String get hint => 'ヒント';
  @override
  String get rules => 'ルール';
  @override
  String get back => 'もどる';

  @override
  String blocked(Blocked b, {String? wanted, String? top}) => switch (b) {
        Blocked.wall => '',
        Blocked.oneWay => '一方通行です',
        Blocked.full => 'もう載せられません',
        Blocked.wrongDish => '${dishName(wanted ?? 'a')}が一番上にありません',
        Blocked.emptyHands => '料理を持っていません',
        Blocked.alreadyServed => 'もう届けました',
        Blocked.counterUsed => '返却口は使用済みです',
        Blocked.finished => '',
      };
  @override
  String get stuckTitle => 'もう全員には配れません';
  @override
  String get stuckBody => '1手戻すか、最初からやり直しましょう。';
  @override
  String hintArrow(Dir d) => 'ヒント：${_dirJa(d)}へ';
  @override
  String get clearTitle => '配達完了！';
  @override
  String clearBody(int moves, int par) => '$moves 手でクリア（目標 $par 手）';
  @override
  String get newBest => '自己ベスト更新';
  @override
  String get perfect => '目標手数でクリア';
  @override
  String get next => '次のステージへ';
  @override
  String get retry => 'もう一度';
  @override
  String get toStages => 'ステージ一覧';
  @override
  String get allClearTitle => '全ステージ配達完了！';
  @override
  String get allClearBody => 'お疲れさまでした。★3を目指して、もう一度挑戦してみませんか。';

  @override
  String get ruleShort => '料理の上を通ると、頭の上に積み上がる（通れば必ず拾う）。お客さんにぶつかると、一番上の料理を渡す。欲しい料理が一番上にないと渡せない。全員に配ったらクリア。';
  @override
  List<(String, String)> get howToPages => const [
        ('料理を拾う', '料理の上を通ると、頭の上に積み上がります。通れば必ず拾うので、通る道順が大切です。一度に載せられる皿の数には上限があります。'),
        ('順番に届ける', 'お客さんにぶつかると、一番上の料理を渡します。吹き出しの料理が一番上にないと渡せません。あとから拾った料理ほど上に来ます。'),
        ('全員に配ろう', 'すべてのお客さんに届けたらクリア。余分な料理が残っていても大丈夫です。目標手数以内なら★3つ。'),
        ('困ったときは', '「1手戻す」は何度でも使えます。どうしても分からないときは「ヒント」で次の一手が分かります。詰んだときはお知らせします。'),
      ];
  @override
  String gimmickName(String id) => switch (id) {
        'counter' => '返却口',
        'tray' => 'くるりトレイ',
        'oneWay' => '一方通行',
        _ => '',
      };
  @override
  String gimmickDesc(String id) => switch (id) {
        'counter' => '体当たりすると、一番上の料理を1皿だけ引き取ってくれる。使えるのは1回だけ。',
        'tray' => '乗ると、頭の上の料理の順番が上下さかさまになる。',
        'oneWay' => '矢印の向きに進むときだけ入れる床。',
        _ => '',
      };
  @override
  String get newGimmick => '新しいしかけ';
  @override
  String get gotIt => 'わかった';
  @override
  String dishName(String c) => switch (c) { 'a' => 'トマト', 'b' => '抹茶だんご', 'c' => '卵焼き', _ => 'ぶどう' };

  @override
  String get sound => '効果音';
  @override
  String get music => 'BGM';
  @override
  String get haptics => '振動';
  @override
  String get language => '言語';
  @override
  String get languageSystem => '端末の設定';
  @override
  String get theme => '表示モード';
  @override
  String get themeSystem => '端末の設定';
  @override
  String get themeLight => 'ライト';
  @override
  String get themeDark => 'ダーク';
  @override
  String get reduceMotion => 'アニメーションを減らす';
  @override
  String get reduceMotionSub => '移動や揺れの動きを止めます';
  @override
  String get resetProgress => '記録を消す';
  @override
  String get resetConfirm => 'すべてのクリア記録と最少手数を消します。元に戻せません。';
  @override
  String get resetDone => '記録を消しました';
  @override
  String get cancel => 'キャンセル';
  @override
  String get reset => '消す';
  @override
  String get licenses => 'ライセンス';
  @override
  String get version => 'バージョン';

  @override
  String boardSummary(GameState s) {
    final head = s.stack.isEmpty ? 'なし' : s.stack.reversed.map(dishName).join('、');
    final waiting = [
      for (var i = 0; i < s.board.guests.length; i++)
        if (!s.isServed(i)) dishName(s.board.guests[i].wants),
    ];
    return '盤面。頭の上（上から）：$head。まだ届けていない注文：${waiting.isEmpty ? 'なし' : waiting.join('、')}。';
  }

  @override
  String get keyboardHelp => '矢印キー／WASDで移動、Zで戻す、Yで進める、Rでやり直し、Hでヒント';
}

class StringsEn extends Strings {
  const StringsEn();

  @override
  String get appTitle => 'Stack & Deliver';
  @override
  String get tagline => 'Stack dishes on your head, serve them in order';
  @override
  String get play => 'Play';
  @override
  String get continueFrom => 'Continue';
  @override
  String get stages => 'Stages';
  @override
  String get howToPlay => 'How to play';
  @override
  String get settings => 'Settings';
  @override
  String chapterLabel(int n) => 'Chapter $n';
  @override
  String clearedCount(int n, int total) => '$n / $total cleared';
  @override
  String get locked => 'Locked';
  @override
  String get lockedHint => 'Clear earlier stages to unlock this one.';
  @override
  String starsTotal(int n, int total) => '★ $n / $total';
  @override
  String get onHead => 'On head';
  @override
  String get empty => 'none';
  @override
  String capacity(int n) => 'max $n';
  @override
  String delivered(int done, int total) => 'Served $done / $total';
  @override
  String movesLabel(int n) => n == 1 ? '1 move' : '$n moves';
  @override
  String parLabel(int n) => 'Par $n';
  @override
  String bestLabel(int? n) => n == null ? 'Best —' : 'Best $n';
  @override
  String get undo => 'Undo';
  @override
  String get redo => 'Redo';
  @override
  String get restart => 'Restart';
  @override
  String get hint => 'Hint';
  @override
  String get rules => 'Rules';
  @override
  String get back => 'Back';

  @override
  String blocked(Blocked b, {String? wanted, String? top}) => switch (b) {
        Blocked.wall => '',
        Blocked.oneWay => 'One-way floor',
        Blocked.full => 'Can\'t carry any more',
        Blocked.wrongDish => '${dishName(wanted ?? 'a')} is not on top',
        Blocked.emptyHands => 'Nothing to hand over',
        Blocked.alreadyServed => 'Already served',
        Blocked.counterUsed => 'Counter already used',
        Blocked.finished => '',
      };
  @override
  String get stuckTitle => 'Not everyone can be served now';
  @override
  String get stuckBody => 'Undo a move or restart the stage.';
  @override
  String hintArrow(Dir d) => 'Hint: go ${_dirEn(d)}';
  @override
  String get clearTitle => 'All served!';
  @override
  String clearBody(int moves, int par) => 'Cleared in $moves (par $par)';
  @override
  String get newBest => 'New best';
  @override
  String get perfect => 'Cleared at par';
  @override
  String get next => 'Next stage';
  @override
  String get retry => 'Retry';
  @override
  String get toStages => 'Stages';
  @override
  String get allClearTitle => 'Every order delivered!';
  @override
  String get allClearBody => 'Thanks for playing. Try again for three stars on every stage?';

  @override
  String get ruleShort => 'Walk over a dish to stack it on your head (you always pick it up). Bump into a guest to hand over the top dish — only if it is what they ordered. Serve everyone to clear.';
  @override
  List<(String, String)> get howToPages => const [
        ('Pick up', 'Walking over a dish stacks it on your head. You always pick it up, so your route matters. You can only carry so many dishes.'),
        ('Serve in order', 'Bump into a guest to hand over the dish on top. It has to be the one in their speech bubble. The last dish you picked up is on top.'),
        ('Serve everyone', 'Clear the stage by serving every guest. Leftover dishes are fine. Clear within par for three stars.'),
        ('Stuck?', 'Undo as often as you like. The Hint button shows the next move, and you\'ll be told when a stage can no longer be finished.'),
      ];
  @override
  String gimmickName(String id) => switch (id) {
        'counter' => 'Return counter',
        'tray' => 'Flip tray',
        'oneWay' => 'One-way floor',
        _ => '',
      };
  @override
  String gimmickDesc(String id) => switch (id) {
        'counter' => 'Bump into it to hand back your top dish. Works only once.',
        'tray' => 'Step on it to turn your stack upside down.',
        'oneWay' => 'You can only enter it moving the way the arrows point.',
        _ => '',
      };
  @override
  String get newGimmick => 'New gimmick';
  @override
  String get gotIt => 'Got it';
  @override
  String dishName(String c) => switch (c) { 'a' => 'Tomato', 'b' => 'Matcha dango', 'c' => 'Omelette', _ => 'Grapes' };

  @override
  String get sound => 'Sound effects';
  @override
  String get music => 'Music';
  @override
  String get haptics => 'Vibration';
  @override
  String get language => 'Language';
  @override
  String get languageSystem => 'System';
  @override
  String get theme => 'Appearance';
  @override
  String get themeSystem => 'System';
  @override
  String get themeLight => 'Light';
  @override
  String get themeDark => 'Dark';
  @override
  String get reduceMotion => 'Reduce motion';
  @override
  String get reduceMotionSub => 'Turns off movement and shaking';
  @override
  String get resetProgress => 'Erase progress';
  @override
  String get resetConfirm => 'This erases every cleared stage and best score. It cannot be undone.';
  @override
  String get resetDone => 'Progress erased';
  @override
  String get cancel => 'Cancel';
  @override
  String get reset => 'Erase';
  @override
  String get licenses => 'Licenses';
  @override
  String get version => 'Version';

  @override
  String boardSummary(GameState s) {
    final head = s.stack.isEmpty ? 'nothing' : s.stack.reversed.map(dishName).join(', ');
    final waiting = [
      for (var i = 0; i < s.board.guests.length; i++)
        if (!s.isServed(i)) dishName(s.board.guests[i].wants),
    ];
    return 'Board. On your head, top first: $head. Orders still waiting: ${waiting.isEmpty ? 'none' : waiting.join(', ')}.';
  }

  @override
  String get keyboardHelp => 'Arrows/WASD move, Z undo, Y redo, R restart, H hint';
}
