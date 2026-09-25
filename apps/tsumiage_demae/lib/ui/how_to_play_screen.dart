import 'package:flutter/material.dart';

import '../app/strings.dart';
import '../app/theme.dart';
import 'auto_play.dart';
import 'widgets.dart';

/// Four short pages, each with a looping demo of the rule it explains.
class HowToPlayScreen extends StatefulWidget {
  const HowToPlayScreen({super.key});

  static Route<void> route() => MaterialPageRoute(
        settings: const RouteSettings(name: '/howto'),
        builder: (_) => const HowToPlayScreen(),
      );

  @override
  State<HowToPlayScreen> createState() => _HowToPlayScreenState();
}

const _demos = <List<String>>[
  ['#######', '#P.a.A#', '#######'],
  ['########', '#Pba..A#', '#.##B###', '########'],
  ['#######', '#Pa.bB#', '##A####', '#######'],
  ['#######', '#P.b.A#', '###a###', '#######'],
];

class _HowToPlayScreenState extends State<HowToPlayScreen> {
  final _page = PageController();
  int _index = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    final pal = context.palette;
    final pages = s.howToPages;
    final last = _index == pages.length - 1;
    return Scaffold(
      appBar: AppBar(title: Text(s.howToPlay)),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _page,
                    itemCount: pages.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (context, i) {
                      final (title, body) = pages[i];
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                        child: Column(
                          children: [
                            Container(
                              height: 190,
                              decoration: BoxDecoration(color: pal.tint(.22), borderRadius: BorderRadius.circular(22)),
                              padding: const EdgeInsets.all(10),
                              child: i == 3
                                  ? const _ToolsIllustration()
                                  : AutoPlayBoard(map: _demos[i], maxCell: 56, stepMs: 600),
                            ),
                            const SizedBox(height: 22),
                            Text('${i + 1}. $title', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 10),
                            Text(body, style: TextStyle(fontSize: 15, height: 1.7, color: pal.ink)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < pages.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.all(4),
                        width: i == _index ? 20 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _index ? pal.accent : pal.line,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: SoftButton(
                      primary: true,
                      label: last ? s.gotIt : '→',
                      onPressed: () {
                        if (last) {
                          Navigator.of(context).pop();
                        } else {
                          _page.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ToolsIllustration extends StatelessWidget {
  const _ToolsIllustration();

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return Center(
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        alignment: WrapAlignment.center,
        children: [
          SoftButton(icon: Icons.undo_rounded, label: s.undo, onPressed: () {}),
          SoftButton(icon: Icons.redo_rounded, label: s.redo, onPressed: () {}),
          SoftButton(icon: Icons.replay_rounded, label: s.restart, onPressed: () {}),
          SoftButton(icon: Icons.lightbulb_outline_rounded, label: s.hint, highlight: true, onPressed: () {}),
        ],
      ),
    );
  }
}
