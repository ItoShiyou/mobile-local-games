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
  String hintCell(Pos p);

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


class StringsJa extends Strings {
  const StringsJa();

  @override
  String get appTitle => 'だし回し';
  @override
  String get appTitleKana => 'だしまわし';
  @override
  String get tagline => '樋を回して、だしをお椀へ';
  @override
  String get play => 'はじめる';
  @override
  String get continueFrom => 'つづきから';
  @override
  String get stages => '献立帳';
  @override
  String get howToPlay => 'あそびかた';
  @override
  String get settings => '設定';
  @override
  String get openSign => '仕込み中';
  @override
  String chapterLabel(int n) => '第${const ['〇', '一', '二', '三', '四', '五', '六', '七', '八', '九'][n.clamp(0, 9)]}章';
  @override
  String clearedCount(int n, int total) => '$n / $total 椀';
  @override
  String get locked => '準備中';
  @override
  String get lockedHint => 'まだ仕込み中です。前の章のだしを先に届けよう。';
  @override
  String get orders => 'ご注文';
  @override
  String get movesWord => '回した数';
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
        Blocked.notPipe => '',
        Blocked.iron => '鉄の樋は回らないよ',
        Blocked.finished => '',
      };
  @override
  String get stuckTitle => 'あれれ…もう全員には届けられないみたい';
  @override
  String get stuckBody => '1手戻すか、はじめからやり直そう';
  @override
  String hintCell(Pos p) => '左から${p.x + 1}列め、上から${p.y + 1}段めの樋を回してみて';
  @override
  String get clearTitle => '毎度あり！';
  @override
  String clearBody(int moves, int par) => '$moves回で完成（目標 $par回）';
  @override
  String get newBest => 'ベスト更新';
  @override
  String get perfect => '目標どおり';
  @override
  String get next => '次のだしへ';
  @override
  String get retry => 'もう一度';
  @override
  String get toStages => '献立帳';
  @override
  String get allClearTitle => '本日のだし、ぜんぶ完成！';
  @override
  String get allClearBody => 'おつかれさまでした。目標手数の判子を集めに、また来てね。';

  @override
  String get ruleShort => '樋をタップすると、右回りに90度まわる。鍋のだしは、つながった樋を通ってお椀へ流れる。すべての樋をつなぎ、だしをこぼさず、どのお椀にも輪の色のだしを届けたら完成。';
  @override
  List<(String, String)> get howToPages => const [
        ('樋を回す', '樋をタップすると、右回りに90度まわるよ。鍋のだしは、つながった樋を通ってお椀へ流れていく。'),
        ('こぼさない', 'つながっていない口から、だしはこぼれてしまう。すべての樋を、ほかの樋や鍋・お椀とつないであげよう。'),
        ('お椀の輪の色', 'お椀の横の輪の色が、ほしいだしの色。すべての樋がつながって、どのお椀にも注文どおりのだしが届いたら完成。少ない回数でできたら判子が3つ。'),
        ('困ったときは', '「戻す」は何回でも使えるよ。わからなくなったら「ヒント」で、次に回す樋を光らせてあげる。'),
      ];
  @override
  String gimmickName(String id) => switch (id) {
        'mix' => '合わせだし',
        'iron' => '鉄の樋',
        'cross' => '交差する樋',
        'shiitake' => '椎茸だし',
        _ => '',
      };
  @override
  String gimmickDesc(String id) => switch (id) {
        'mix' => '昆布だし（緑）が加わるよ。鰹（橙）と昆布が同じ樋でつながると、合わせだし（金）になる。お椀の輪の色をよく見て、混ぜるか分けるかを決めよう。',
        'iron' => '鋲のついた鉄の樋は、回らない。動かない樋は、まわりの樋の向きを決める手がかりになるよ。',
        'cross' => '縦と横が重なった樋。上下を通るだしと左右を通るだしは、混ざらずにすれ違う。回しても形は変わらないよ。',
        'shiitake' => '椎茸だし（茶）が加わる。三つのだしが出会うと、深い色の三つ合わせになるよ。',
        _ => '',
      };
  @override
  String get newGimmick => 'おしらせ';
  @override
  String get gotIt => 'わかった';
  @override
  String get nextPage => 'つぎへ';
  @override
  String dishName(String c) => stockNameJa(c);

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
    final flow = s.flow;
    final done = [for (var i = 0; i < s.board.bowls.length; i++) if (flow.bowls[i] == s.board.bowls[i].want) i].length;
    return '盤面。お椀 ${s.board.bowls.length} 個のうち $done 個に注文どおりのだし。${flow.allJoined ? 'すべての樋がつながっている。' : 'まだつながっていない樋がある。'}';
  }

  @override
  String get keyboardHelp => '矢印キーで樋を選び、スペースで回す。Zで戻す、Yで進む、Rでやり直し、Hでヒント';
}

class StringsEn extends Strings {
  const StringsEn();

  @override
  String get appTitle => 'Stock Pipes';
  @override
  String get appTitleKana => 'dashi mawashi';
  @override
  String get tagline => 'Turn the pipes, fill the bowls';
  @override
  String get play => 'Start';
  @override
  String get continueFrom => 'Continue';
  @override
  String get stages => 'Recipe book';
  @override
  String get howToPlay => 'How to play';
  @override
  String get settings => 'Settings';
  @override
  String get openSign => 'SIMMERING';
  @override
  String chapterLabel(int n) => 'Chapter $n';
  @override
  String clearedCount(int n, int total) => '$n / $total';
  @override
  String get locked => 'Closed';
  @override
  String get lockedHint => 'Not ready yet. Finish the earlier chapter first.';
  @override
  String get orders => 'Orders';
  @override
  String get movesWord => 'Turns';
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
        Blocked.notPipe => '',
        Blocked.iron => 'Iron pipes don\'t turn',
        Blocked.finished => '',
      };
  @override
  String get stuckTitle => 'Uh-oh… I can\'t serve everyone now';
  @override
  String get stuckBody => 'Undo a move, or start over';
  @override
  String hintCell(Pos p) => 'Try turning the pipe in column ${p.x + 1}, row ${p.y + 1}';
  @override
  String get clearTitle => 'Thank you!';
  @override
  String clearBody(int moves, int par) => 'Done in $moves turns (par $par)';
  @override
  String get newBest => 'New best';
  @override
  String get perfect => 'On par';
  @override
  String get next => 'Next stock';
  @override
  String get retry => 'Again';
  @override
  String get toStages => 'Recipe book';
  @override
  String get allClearTitle => 'Every stock is ready!';
  @override
  String get allClearBody => 'Thanks for your hard work. Come back to collect every par stamp.';

  @override
  String get ruleShort => 'Tap a pipe to turn it a quarter turn clockwise. Stock runs from the pots through every pipe it is joined to. Join up every pipe without spilling a drop, and fill each bowl with the stock of its ring colour.';
  @override
  List<(String, String)> get howToPages => const [
        ('Turn the pipes', 'Tap a pipe to turn it a quarter turn clockwise. Stock flows from the pots through the pipes that join up.'),
        ('Don\'t spill', 'Stock spills out of any open end. Join every pipe to another pipe, a pot or a bowl.'),
        ('The ring colour', 'The ring on each bowl shows the stock it wants. Join every pipe and fill every bowl as ordered. Do it in few turns for three stamps.'),
        ('Stuck?', 'Undo as often as you like. Tap Hint and I\'ll light up a pipe to turn.'),
      ];
  @override
  String gimmickName(String id) => switch (id) {
        'mix' => 'Awase',
        'iron' => 'Iron pipes',
        'cross' => 'Crossing pipes',
        'shiitake' => 'Shiitake stock',
        _ => '',
      };
  @override
  String gimmickDesc(String id) => switch (id) {
        'mix' => 'Kombu stock (green) joins in. Katsuo (amber) and kombu that meet in one pipe become awase (gold). Watch the ring colours: mix them or keep them apart.',
        'iron' => 'Studded iron pipes don\'t turn. Use them as clues for the pipes around them.',
        'cross' => 'Two pipes crossing, one over the other: the up-down stock and the left-right stock pass without mixing. Turning it changes nothing.',
        'shiitake' => 'Shiitake stock (brown) joins in. All three together make a deep mixed stock.',
        _ => '',
      };
  @override
  String get newGimmick => 'Notice';
  @override
  String get gotIt => 'Got it';
  @override
  String get nextPage => 'Next';
  @override
  String dishName(String c) => stockNameEn(c);

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
    final flow = s.flow;
    final done = [for (var i = 0; i < s.board.bowls.length; i++) if (flow.bowls[i] == s.board.bowls[i].want) i].length;
    return 'Board. $done of ${s.board.bowls.length} bowls have the right stock. ${flow.allJoined ? 'Every pipe is joined.' : 'Some pipes are not joined yet.'}';
  }

  @override
  String get keyboardHelp => 'Arrows pick a pipe, Space turns it, Z undo, Y redo, R restart, H hint';
}

String stockNameJa(String c) => [for (final ch in c.split('')) const {'k': '鰹', 'n': '昆布', 's': '椎茸'}[ch]].join('と') + (c.length > 1 ? 'の合わせだし' : 'だし');
String stockNameEn(String c) => '${[for (final ch in c.split('')) const {'k': 'katsuo', 'n': 'kombu', 's': 'shiitake'}[ch]].join(' and ')} stock';
