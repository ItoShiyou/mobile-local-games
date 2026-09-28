import 'package:flutter/widgets.dart';

import '../game/engine.dart';
import 'scope.dart';

/// All user-facing text, in Japanese and English. Nothing is written on
/// the board during play; the cat's lines here are read out to screen
/// readers only.
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
  String blocked(Blocked b);
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
  String get appTitle => 'ふすま渡り';
  @override
  String get appTitleKana => 'ふすまわたり';
  @override
  String get tagline => 'ふすまを押して、客間までお届け';
  @override
  String get play => 'はじめる';
  @override
  String get continueFrom => 'つづきから';
  @override
  String get stages => '宿帳';
  @override
  String get howToPlay => 'あそびかた';
  @override
  String get settings => '設定';
  @override
  String get openSign => '空室あり';
  @override
  String chapterLabel(int n) => '第${const ['〇', '一', '二', '三', '四', '五', '六', '七', '八', '九'][n.clamp(0, 9)]}章';
  @override
  String clearedCount(int n, int total) => '$n / $total 間';
  @override
  String get locked => '準備中';
  @override
  String get lockedHint => 'まだ準備中です。前の棟の配達を先にすませよう。';
  @override
  String get orders => 'ご注文';
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
  String blocked(Blocked b) => switch (b) {
        Blocked.wall => '',
        Blocked.across => 'ふすまは敷居にそってしか動かないよ',
        Blocked.jammed => 'つっかえて動かない…',
        Blocked.locked => '鍵がかかってる。女将さんの鍵はどこだろう',
        Blocked.pivot => '柱のところは押しても回らない',
        Blocked.alreadyServed => 'もう届けたよ',
        Blocked.finished => '',
      };
  @override
  String get stuckTitle => 'あれれ…もう全員には届けられないみたい';
  @override
  String get stuckBody => '1手戻すか、はじめからやり直そう';
  @override
  String hintArrow(Dir d) => 'つぎは${_dirJa(d)}かな？';
  @override
  String get clearTitle => '毎度あり！';
  @override
  String clearBody(int moves, int par) => '$moves手で配達（目標 $par手）';
  @override
  String get newBest => 'ベスト更新';
  @override
  String get perfect => '目標どおり';
  @override
  String get next => '次の間へ';
  @override
  String get retry => 'もう一度';
  @override
  String get toStages => '宿帳';
  @override
  String get allClearTitle => '本日の配達、ぜんぶ完了！';
  @override
  String get allClearBody => 'おつかれさまでした。目標手数の判子を集めに、また来てね。';

  @override
  String get ruleShort => 'ねこは上下左右に歩く。ふすまに向かって歩くと押してすべらせるけれど、動くのは敷居にそった向きだけ（端の小さな三角が動く向き）。お客さんにぶつかると注文を届ける。全員に届けたら完了。';
  @override
  List<(String, String)> get howToPages => const [
        ('ふすまを押す', 'ふすまに向かって歩くと、押してすべらせるよ。動くのは敷居にそった向きだけ。端の小さな三角が、動く向きの目印。'),
        ('つっかえたら', 'ふすまの先に壁や別のふすまがあると、つっかえて動かない。どのふすまから、どちらへ動かすかが大事。'),
        ('お客さんに届ける', 'お客さんにぶつかると、頭の上の注文を届けるよ。全員に届けたら配達完了。目標の手数で届けられたら、判子が3つもらえる。'),
        ('困ったときは', '「戻す」は何回でも使えるよ。わからなくなったら「ヒント」で、次に進む方に足あとをつけてあげる。'),
      ];
  @override
  String gimmickName(String id) => switch (id) {
        'guests' => 'お客さんがふたり',
        'pair' => '対のふすま',
        'lock' => '女将さんの鍵',
        'revolve' => '回り障子',
        _ => '',
      };
  @override
  String gimmickDesc(String id) => switch (id) {
        'guests' => 'ここからは、お客さんがふたりの間もあるよ。どちらから届けてもいい。全員に届けたら完了。',
        'pair' => '同じ波の柄のふすまは、一緒にすべる。どちらか一枚でもつっかえると、両方とも動かない。',
        'lock' => '赤い錠のついたふすまは、女将さんの鍵を拾うまで動かない。鍵は畳の上に落ちているよ。',
        'revolve' => '柱を軸にくるりと回る障子。横から押すと、柱のまわりを90度まわる。まわった先と、そのあいだの角があいていないと回らない。',
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
    final waiting = [
      for (var i = 0; i < s.board.guests.length; i++)
        if (!s.isServed(i)) dishName(s.board.guests[i].wants),
    ];
    final key = s.board.key == null ? '' : (s.hasKey ? '鍵を持っている。' : '鍵はまだ。');
    return '盤面。まだ届けていない注文：${waiting.isEmpty ? 'なし' : waiting.join('、')}。$key';
  }

  @override
  String get keyboardHelp => '矢印キー／WASDで移動、Zで戻す、Yで進む、Rでやり直し、Hでヒント';
}

class StringsEn extends Strings {
  const StringsEn();

  @override
  String get appTitle => 'Sliding Doors Inn';
  @override
  String get appTitleKana => 'fusuma watari';
  @override
  String get tagline => 'Slide the doors, bring the orders';
  @override
  String get play => 'Start';
  @override
  String get continueFrom => 'Continue';
  @override
  String get stages => 'Guest book';
  @override
  String get howToPlay => 'How to play';
  @override
  String get settings => 'Settings';
  @override
  String get openSign => 'VACANCY';
  @override
  String chapterLabel(int n) => 'Chapter $n';
  @override
  String clearedCount(int n, int total) => '$n / $total';
  @override
  String get locked => 'Closed';
  @override
  String get lockedHint => 'Not open yet. Finish the earlier wing first.';
  @override
  String get orders => 'Orders';
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
  String blocked(Blocked b) => switch (b) {
        Blocked.wall => '',
        Blocked.across => 'Doors only slide along their tracks',
        Blocked.jammed => 'It\'s jammed…',
        Blocked.locked => 'Locked. Where is the landlady\'s key?',
        Blocked.pivot => 'Pushing the post won\'t turn it',
        Blocked.alreadyServed => 'Already served them',
        Blocked.finished => '',
      };
  @override
  String get stuckTitle => 'Uh-oh… I can\'t serve everyone now';
  @override
  String get stuckBody => 'Undo a move, or start over';
  @override
  String hintArrow(Dir d) => 'Maybe ${_dirEn(d)}?';
  @override
  String get clearTitle => 'Thank you!';
  @override
  String clearBody(int moves, int par) => 'Delivered in $moves (par $par)';
  @override
  String get newBest => 'New best';
  @override
  String get perfect => 'On par';
  @override
  String get next => 'Next room';
  @override
  String get retry => 'Again';
  @override
  String get toStages => 'Guest book';
  @override
  String get allClearTitle => 'Every order delivered!';
  @override
  String get allClearBody => 'Thanks for your hard work. Come back to collect every par stamp.';

  @override
  String get ruleShort => 'Walk up, down, left and right. Walk into a door to slide it, but doors only move along their tracks (the small arrows at the ends). Bump into a guest to serve their order. Serve everyone to finish.';
  @override
  List<(String, String)> get howToPages => const [
        ('Slide the doors', 'Walk into a door to slide it along. Doors only move along their tracks: the little arrows at the ends show the way.'),
        ('When it jams', 'A door stops against a wall or another door. Which door you move, and which way, is the whole puzzle.'),
        ('Serve the guests', 'Bump into a guest to serve the order on your head. Serve everyone to finish. Do it within par for all three stamps.'),
        ('Stuck?', 'Undo as often as you like. Tap Hint and I\'ll leave paw prints on the way to go.'),
      ];
  @override
  String gimmickName(String id) => switch (id) {
        'guests' => 'Two guests',
        'pair' => 'Paired doors',
        'lock' => 'The landlady\'s key',
        'revolve' => 'Revolving shoji',
        _ => '',
      };
  @override
  String gimmickDesc(String id) => switch (id) {
        'guests' => 'From here some rooms have two guests. Serve them in any order; serve everyone to finish.',
        'pair' => 'Doors with the same wave crest slide together. If either one jams, neither moves.',
        'lock' => 'A door with a red lock won\'t move until you pick up the landlady\'s key from the tatami.',
        'revolve' => 'A shoji that turns on a post. Push it from the side and it swings a quarter turn round the post, if the spot it swings to and the corner on the way are clear.',
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
    final waiting = [
      for (var i = 0; i < s.board.guests.length; i++)
        if (!s.isServed(i)) dishName(s.board.guests[i].wants),
    ];
    final key = s.board.key == null ? '' : (s.hasKey ? ' You have the key.' : ' No key yet.');
    return 'Board. Orders still waiting: ${waiting.isEmpty ? 'none' : waiting.join(', ')}.$key';
  }

  @override
  String get keyboardHelp => 'Arrows/WASD move, Z undo, Y redo, R restart, H hint';
}
