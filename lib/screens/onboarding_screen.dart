import 'package:flutter/material.dart';
import '../core/ui.dart';

/// First-run walkthrough — tells a brand-new user what AI Companions,
/// Dynamic Duo and the Dashboard are, and WHY DeepRest asks for Usage
/// access and notifications. Shown once, skippable.
class OnboardingScreen extends StatelessWidget {
  final Future<void> Function() onDone;
  const OnboardingScreen({super.key, required this.onDone});

  static const _slides = <_Slide>[
    _Slide(
      emoji: '🌙',
      title: 'Welcome to DeepRest',
      body:
          'Rest deeply and scroll less. DeepRest tracks your screen time, rewards healthy habits with XP and ranks, and keeps the people who matter close.',
      accent: D.accent,
    ),
    _Slide(
      emoji: '🛡️',
      title: 'AI Companions',
      body:
          'Shepherd, Guide and Counselor — three companions with different styles, ready day or night. What you tell them is stored encrypted on our servers and never shown to other people. The companion itself reads your messages to reply.',
      accent: Color(0xFF60A5FA),
    ),
    _Slide(
      emoji: '🤝',
      title: 'Dynamic Duo',
      body:
          'Pair up with an accountability partner using an invite code. You see each other\u2019s progress, cheer each other on — and your direct chats are end-to-end encrypted: only you two can read them.',
      accent: D.teal,
    ),
    _Slide(
      emoji: '⏳',
      title: 'Why Usage access?',
      body:
          'Your dashboard, streak and rank are powered by real screen time measured on this phone — that\u2019s the one thing Usage access is for. DeepRest only records how long apps are used, never what happens inside them. Turn it on from the Dashboard.',
      accent: D.amber,
    ),
    _Slide(
      emoji: '🔔',
      title: 'Stay reachable',
      body:
          'Allow notifications so SOS alerts and calls from your partner always reach you. You can change this anytime in system settings.',
      accent: D.tick,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: D.bg.withValues(alpha: 0.97),
      body: SafeArea(
        child: _Pager(slides: _slides, onDone: onDone),
      ),
    );
  }
}

class _Slide {
  final String emoji, title, body;
  final Color accent;
  const _Slide(
      {required this.emoji, required this.title, required this.body, required this.accent});
}

class _Pager extends StatefulWidget {
  final List<_Slide> slides;
  final Future<void> Function() onDone;
  const _Pager({required this.slides, required this.onDone});
  @override
  State<_Pager> createState() => _PagerState();
}

class _PagerState extends State<_Pager> {
  final _ctrl = PageController();
  int _i = 0;

  Future<void> _next() async {
    if (_i < widget.slides.length - 1) {
      await _ctrl.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    } else {
      await widget.onDone();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _i == widget.slides.length - 1;
    return Column(children: [
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: widget.onDone,
          child: const Text('Skip', style: TextStyle(color: D.sub)),
        ),
      ),
      Expanded(
        child: PageView.builder(
          controller: _ctrl,
          itemCount: widget.slides.length,
          onPageChanged: (i) => setState(() => _i = i),
          itemBuilder: (_, i) {
            final s = widget.slides[i];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 34),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [s.accent.withValues(alpha: .35), s.accent.withValues(alpha: .08)]),
                    ),
                    child: Center(
                        child: Text(s.emoji, style: const TextStyle(fontSize: 58))),
                  ),
                  const SizedBox(height: 34),
                  Text(s.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 26, fontWeight: FontWeight.bold, color: D.text)),
                  const SizedBox(height: 14),
                  Text(s.body,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 15, height: 1.5, color: D.sub)),
                ],
              ),
            );
          },
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 18),
        child: Row(children: [
          ...List.generate(widget.slides.length, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 6),
                width: i == _i ? 22 : 7,
                height: 7,
                decoration: BoxDecoration(
                    color: i == _i ? D.accent : D.panelHi,
                    borderRadius: BorderRadius.circular(4)),
              )),
          const Spacer(),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: D.accent,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 26, vertical: 14)),
            onPressed: _next,
            child: Text(last ? 'Get started' : 'Next',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
    ]);
  }
}
