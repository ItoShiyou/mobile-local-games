import 'package:flutter/widgets.dart';

import '../game/engine.dart';
import 'scope.dart';

/// All user-facing text, in Japanese and English. Feedback is spoken by the
/// delivery cat, so it is written in their voice rather than as system
/// messages.
abstract class Strings {
  const Strings();

  static Strings of(BuildContext context) => AppScope.of(context).settings.strings(context);

  String get appTitle;
  String get appTitleKana;
  String get tagline;

  // Title
  String get play;
  String get continueFrom;
  String get stages;
  String get howToPlay;
  String get settings;
  String get openSign;

  // Stage select
  String chapterLabel(int n);
  String clearedCount(int n, int total);
  String get locked;
  String get lockedHint;

  // Game
  String get orders;
  String get onHead;
  String capacity(int n);
  String get movesWord;
  String get parWord;
  String get bestWord;
  String get servedStamp;
  String get undo;
  String get redo;
  String get restart;
  String get hint;
  String get rules;
  String get back;

  // The cat's lines
  String blocked(Blocked b, {String? wanted});
  String get stuckTitle;
  String get stuckBody;
  String hintArrow(Dir d);
  String get greeting;

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
  String get nextPage;
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
  String get appTitleKana => 'つみあげでまえ';
  @override
  String get tagline => '頭の上に積んで、順番どおりにお届け';
  @override
  String get play => 'はじめる';
  @override
  String get continueFrom => 'つづきから';
  @override
  String get stages => 'お品書き';
  @override
  String get howToPlay => 'あそびかた';
  @override
  String get settings => '設定';
  @override
  String get openSign => '営業中';
  @override
  String chapterLabel(int n) => '第${const ['〇', '一', '二', '三', '四', '五', '六', '七', '八', '九'][n.clamp(0, 9)]}章';
  @override
  String clearedCount(int n, int total) => '$n / $total 品';
  @override
  String get locked => '準備中';
  @override
  String get lockedHint => 'まだ準備中です。前のお店の出前を先に届けよう。';
  @override
  String get orders => 'ご注文';
  @override
  String get onHead => '頭の上';
  @override
  String capacity(int n) => '$n皿まで';
  @override
  String get movesWord => '手数';
  @override
  String get parWord => '目標';
  @override
  String get bestWord => '最少';
  @override
  String get servedStamp => '済';
  @override
  String get undo => '戻す';
  @override
  String get redo => '進む';
  @override
  String get restart => 'やり直す';
  @override
  String get hint => 'ヒント';
  @override
  String get rules => 'ルール';
  @override
  String get back => 'もどる';

  @override
  String blocked(Blocked b, {String? wanted}) => switch (b) {
        Blocked.wall => '',
        Blocked.oneWay => 'こっちからは入れないね',
        Blocked.full => 'もう持てないよ〜',
        Blocked.wrongDish => '${dishName(wanted ?? 'a')}がいちばん上じゃないと…',
        Blocked.emptyHands => 'あっ、手ぶらだった',
        Blocked.alreadyServed => 'もう届けたよ',
        Blocked.counterUsed => '返却口はもう閉まってる',
        Blocked.finished => '',
      };
  @override
  String get stuckTitle => 'あれれ…もう全員には届けられないみたい';
  @override
  String get stuckBody => '1手戻すか、はじめからやり直そう';
  @override
  String hintArrow(Dir d) => 'つぎは${_dirJa(d)}かな？';
  @override
  String get greeting => 'いってきまーす！';
  @override
  String get clearTitle => '毎度あり！';
  @override
  String clearBody(int moves, int par) => '$moves手で配達（目標 $par手）';
  @override
  String get newBest => 'ベスト更新';
  @override
  String get perfect => '目標どおり';
  @override
  String get next => '次の出前へ';
  @override
  String get retry => 'もう一度';
  @override
  String get toStages => 'お品書き';
  @override
  String get allClearTitle => '本日の出前、ぜんぶ完了！';
  @override
  String get allClearBody => 'おつかれさまでした。目標手数の判子を集めに、また来てね。';

  @override
  String get ruleShort => '料理の上を通ると、頭の上に積み上がる（通れば必ず拾う）。お客さんにぶつかると、いちばん上の料理を渡す。注文の料理がいちばん上にないと渡せない。全員に届けたら完了。';
  @override
  List<(String, String)> get howToPages => const [
        ('料理を拾う', '料理の上を通ると、頭の上に積み上がるよ。通れば必ず拾うから、どの道を通るかが大事。一度に載せられるお皿には限りがあるんだ。'),
        ('順番に届ける', 'お客さんにぶつかると、いちばん上の料理を渡すよ。伝票の料理がいちばん上にないと渡せない。あとから拾った料理ほど上に来るからね。'),
        ('みんなに届けよう', 'お客さん全員に届けたら出前完了。余った料理があっても大丈夫。目標の手数で届けられたら、判子が3つもらえるよ。'),
        ('困ったときは', '「戻す」は何回でも使えるよ。わからなくなったら「ヒント」で、次に進む方に足あとをつけてあげる。'),
      ];
  @override
  String gimmickName(String id) => switch (id) {
        'counter' => '返却口',
        'tray' => 'くるりのお盆',
        'oneWay' => '一方通行',
        _ => '',
      };
  @override
  String gimmickDesc(String id) => switch (id) {
        'counter' => 'ぶつかると、いちばん上の料理を1皿だけ引き取ってくれる。使えるのは1回だけで、そのあとはシャッターが閉まるよ。',
        'tray' => '上に乗ると、頭の上の料理の順番が上下さかさまになるよ。',
        'oneWay' => '矢印の向きに進むときだけ入れる道。戻り道に気をつけて。',
        _ => '',
      };
  @override
  String get newGimmick => 'おしらせ';
  @override
  String get gotIt => 'わかった';
  @override
  String get nextPage => 'つぎへ';
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
  String get languageSystem => '端末';
  @override
  String get theme => '営業時間';
  @override
  String get themeSystem => '端末';
  @override
  String get themeLight => '昼';
  @override
  String get themeDark => '夜';
  @override
  String get reduceMotion => '動きを減らす';
  @override
  String get reduceMotionSub => '移動や揺れのアニメーションを止めます';
  @override
  String get resetProgress => '記録を消す';
  @override
  String get resetConfirm => 'すべての配達記録と判子を消します。元に戻せません。';
  @override
  String get resetDone => '記録を消しました';
  @override
  String get cancel => 'やめる';
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
  String get keyboardHelp => '矢印キー／WASDで移動、Zで戻す、Yで進む、Rでやり直し、Hでヒント';
}

class StringsEn extends Strings {
  const StringsEn();

  @override
  String get appTitle => 'Stack & Deliver';
  @override
  String get appTitleKana => 'tsumiage demae';
  @override
  String get tagline => 'Stack it on your head, serve it in order';
  @override
  String get play => 'Start';
  @override
  String get continueFrom => 'Continue';
  @override
  String get stages => 'Menu';
  @override
  String get howToPlay => 'How to play';
  @override
  String get settings => 'Settings';
  @override
  String get openSign => 'OPEN';
  @override
  String chapterLabel(int n) => 'Chapter $n';
  @override
  String clearedCount(int n, int total) => '$n / $total';
  @override
  String get locked => 'Closed';
  @override
  String get lockedHint => 'Not open yet. Finish the earlier deliveries first.';
  @override
  String get orders => 'Orders';
  @override
  String get onHead => 'On head';
  @override
  String capacity(int n) => 'max $n';
  @override
  String get movesWord => 'Moves';
  @override
  String get parWord => 'Par';
  @override
  String get bestWord => 'Best';
  @override
  String get servedStamp => '✓';
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
  String blocked(Blocked b, {String? wanted}) => switch (b) {
        Blocked.wall => '',
        Blocked.oneWay => 'Can\'t get in from this side',
        Blocked.full => 'I can\'t carry any more!',
        Blocked.wrongDish => 'The ${dishName(wanted ?? 'a').toLowerCase()} has to be on top…',
        Blocked.emptyHands => 'Oops, my hands are empty',
        Blocked.alreadyServed => 'Already served them',
        Blocked.counterUsed => 'The counter\'s closed now',
        Blocked.finished => '',
      };
  @override
  String get stuckTitle => 'Uh-oh… I can\'t serve everyone now';
  @override
  String get stuckBody => 'Undo a move, or start over';
  @override
  String hintArrow(Dir d) => 'Maybe ${_dirEn(d)}?';
  @override
  String get greeting => 'Off I go!';
  @override
  String get clearTitle => 'Thank you!';
  @override
  String clearBody(int moves, int par) => 'Delivered in $moves (par $par)';
  @override
  String get newBest => 'New best';
  @override
  String get perfect => 'On par';
  @override
  String get next => 'Next order';
  @override
  String get retry => 'Again';
  @override
  String get toStages => 'Menu';
  @override
  String get allClearTitle => 'Every order delivered!';
  @override
  String get allClearBody => 'Thanks for your hard work. Come back to collect every par stamp.';

  @override
  String get ruleShort => 'Walk over a dish to stack it on your head (you always pick it up). Bump into a guest to hand over the top dish — only if it is what they ordered. Serve everyone to finish.';
  @override
  List<(String, String)> get howToPages => const [
        ('Pick up', 'Walk over a dish and it goes on top of your stack. You always pick it up, so choose your route well. You can only carry so many plates.'),
        ('Serve in order', 'Bump into a guest to hand over the dish on top. It has to be the one on their ticket. The last dish you picked up is on top.'),
        ('Serve everyone', 'Serve every guest to finish. Leftover dishes are fine. Deliver within par to earn all three stamps.'),
        ('Stuck?', 'Undo as often as you like. Tap Hint and I\'ll leave paw prints on the way to go.'),
      ];
  @override
  String gimmickName(String id) => switch (id) {
        'counter' => 'Return counter',
        'tray' => 'Flip tray',
        'oneWay' => 'One-way lane',
        _ => '',
      };
  @override
  String gimmickDesc(String id) => switch (id) {
        'counter' => 'Bump it to hand back your top dish. It works once, then the shutter comes down.',
        'tray' => 'Step on it and your whole stack turns upside down.',
        'oneWay' => 'You can only enter it going the way the arrows point. Mind the way back.',
        _ => '',
      };
  @override
  String get newGimmick => 'Notice';
  @override
  String get gotIt => 'Got it';
  @override
  String get nextPage => 'Next';
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
  String get theme => 'Opening hours';
  @override
  String get themeSystem => 'System';
  @override
  String get themeLight => 'Day';
  @override
  String get themeDark => 'Night';
  @override
  String get reduceMotion => 'Reduce motion';
  @override
  String get reduceMotionSub => 'Turns off movement and shaking';
  @override
  String get resetProgress => 'Erase progress';
  @override
  String get resetConfirm => 'This erases every delivery record and stamp. It cannot be undone.';
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
