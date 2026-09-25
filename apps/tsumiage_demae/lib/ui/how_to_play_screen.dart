import 'package:flutter/material.dart';

import '../app/strings.dart';
import '../app/theme.dart';
import 'art.dart';
import 'backdrop.dart';
import 'auto_play.dart';
import 'ink_icons.dart';
import 'paper.dart';
import 'widgets.dart';

/// A four-page picture book; each page has a little diorama that plays the
/// rule it explains.
class HowToPlayScreen extends StatefulWidget {
  const HowToPlayScreen({super.key});

  static Route<void> route() => NorenRoute(settings: const RouteSettings(name: '/howto'), builder: (_) => const HowToPlayScreen());

  @override
  State<HowToPlayScreen> createState() => _HowToPlayScreenState();
}

const _demos = <List<String>>[
  ['#######', '#P.a.A#', '#######'],
  ['########', '#Pba..A#', '#.##B###', '########'],
  ['#######', '#Pa.bB#', '##A####', '#######'],
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
      body: DeskBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RoundWoodButton(glyph: InkGlyph.back, tooltip: s.back, onPressed: () => Navigator.of(context).maybePop()),
                        Expanded(
                          child: Center(
                            child: Signboard(
                              hanging: true,
                              padding: const EdgeInsets.fromLTRB(26, 4, 26, 8),
                              child: Text(s.howToPlay, style: display(22, kInk)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _page,
                      itemCount: pages.length,
                      onPageChanged: (i) => setState(() => _index = i),
                      itemBuilder: (context, i) {
                        final (title, body) = pages[i];
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
                          child: PaperSlip(
                            seed: 60 + i,
                            tilt: i.isEven ? -.6 : .6,
                            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                            child: SingleChildScrollView(
                              child: Column(
                                children: [
                                  SizedBox(
                                    height: 170,
                                    child: i == 3
                                        ? const _ToolsIllustration()
                                        : WoodFrame(child: AutoPlayBoard(map: _demos[i], maxCell: 54, stepMs: 620)),
                                  ),
                                  const SizedBox(height: 18),
                                  Row(
                                    children: [
                                      Container(
                                        width: 30,
                                        height: 30,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(color: pal.shu, shape: BoxShape.circle),
                                        child: Text('${i + 1}', style: display(17, pal.onShu, height: 1)),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(child: Text(title, style: display(24, pal.ink))),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(body, style: TextStyle(fontSize: 15.5, height: 1.8, color: pal.ink, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < pages.length; i++)
                          Padding(
                            padding: const EdgeInsets.all(4),
                            child: HankoStars(stars: i <= _index ? 1 : 0, total: 1, size: 14),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                    child: SizedBox(
                      width: double.infinity,
                      child: WoodButton(
                        kind: WoodKind.shu,
                        label: last ? s.gotIt : s.nextPage,
                        glyph: last ? null : InkGlyph.play,
                        onPressed: () {
                          if (last) {
                            Navigator.of(context).pop();
                          } else {
                            _page.nextPage(duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
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
      ),
    );
  }
}

class _ToolsIllustration extends StatelessWidget {
  const _ToolsIllustration();

  @override
  Widget build(BuildContext context) {
    final s = Strings.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CourierPortrait(size: 80, stack: ['c', 'a']),
        const SizedBox(width: 14),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 120, child: WoodButton(small: true, glyph: InkGlyph.undo, label: s.undo, onPressed: () {})),
            const SizedBox(height: 10),
            SizedBox(width: 120, child: WoodButton(small: true, kind: WoodKind.noren, glyph: InkGlyph.hint, label: s.hint, glow: true, onPressed: () {})),
          ],
        ),
      ],
    );
  }
}
