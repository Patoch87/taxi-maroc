import 'dart:math';

import 'package:flutter/material.dart';

import '../main.dart';
import '../services/coupons.dart';
import '../services/games.dart';
import '../services/promos.dart';
import '../theme.dart';
import '../widgets/coupon_sheet.dart';
import '../widgets/promo_card.dart';
import 'my_offers_screen.dart';

/// « Jouer pendant le trajet » : 3 petits jeux, une partie par jeu et par course.
/// Gagner donne un cadeau offert par un partenaire fictif, enregistré dans « Mes offres ».
class GamesScreen extends StatefulWidget {
  const GamesScreen({super.key, required this.tripId});
  final String tripId;

  @override
  State<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends State<GamesScreen> {
  static const _games = [
    (TripGame.scratch, 'gameScratch', 'gameScratchDesc', Icons.auto_awesome, Color(0xFFC1272D)),
    (TripGame.wheel, 'gameWheel', 'gameWheelDesc', Icons.album_outlined, Color(0xFF006233)),
    (TripGame.quiz, 'gameQuiz', 'gameQuizDesc', Icons.quiz_outlined, Color(0xFF1565C0)),
  ];

  Future<void> _open(TripGame g, String titleKey) async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => GamePage(game: g, tripId: widget.tripId, titleKey: titleKey)));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(s.t('gamesTitle'))),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Text(s.t('playSubtitle'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(s.t('gamesIntro'), style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 16),
          for (final (g, title, desc, icon, color) in _games) ...[
            _tile(g, title, desc, icon, color),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 6),
          // Partenaires des cadeaux : exemples fictifs de la démo.
          Text('${s.t('giftOfferedBy')} : ${tripGifts.map((p) => p.brand).join(', ')} · ${s.t('fictiveExample')}',
              style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ]),
      );

  Widget _tile(TripGame g, String title, String desc, IconData icon, Color color) {
    final played = hasPlayed(widget.tripId, g);
    return Semantics(
      button: true,
      enabled: !played,
      label: '${s.t(title)}. ${played ? s.t('alreadyPlayed') : s.t(desc)}',
      excludeSemantics: true,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: played ? null : () => _open(g, title),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line, width: 1.5),
            ),
            child: Row(children: [
              Container(
                width: 52,
                height: 52,
                decoration:
                    BoxDecoration(color: played ? AppColors.line : color, borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.t(title), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  Text(played ? s.t('alreadyPlayed') : s.t(desc),
                      style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                ]),
              ),
              Icon(played ? Icons.check_circle : Icons.play_circle_fill,
                  color: played ? AppColors.muted : AppColors.moroccoGreen, size: 30),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Une partie : le jeu, puis le résultat (cadeau gagné ou perdu).
class GamePage extends StatefulWidget {
  const GamePage({super.key, required this.game, required this.tripId, required this.titleKey, this.rnd});
  final TripGame game;
  final String tripId;
  final String titleKey;

  /// Pour les tests.
  final Random? rnd;

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late final Random _rnd = widget.rnd ?? Random();
  late final Promo _gift = randomGift(_rnd);
  Coupon? _won;
  bool _lost = false;
  String _rightAnswer = '';

  void _win() {
    if (_won != null || _lost) return;
    markPlayed(widget.tripId, widget.game);
    setState(() => _won = awardGift(_gift, widget.tripId, widget.game));
  }

  void _lose(String right) {
    markPlayed(widget.tripId, widget.game);
    setState(() {
      _lost = true;
      _rightAnswer = right;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(s.t(widget.titleKey))),
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _won != null
                ? _GiftWon(key: const ValueKey('won'), coupon: _won!)
                : _lost
                    ? _lostView()
                    : switch (widget.game) {
                        TripGame.scratch => _ScratchGame(gift: _gift, onDone: _win),
                        TripGame.wheel => _WheelGame(gift: _gift, onDone: _win),
                        TripGame.quiz => _QuizGame(rnd: _rnd, onWin: _win, onLose: _lose),
                      },
          ),
        ),
      );

  Widget _lostView() => Padding(
        key: const ValueKey('lost'),
        padding: const EdgeInsets.all(24),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.sentiment_neutral, size: 64, color: AppColors.muted),
              const SizedBox(height: 12),
              Text('${s.t('gameLost')} : $_rightAnswer',
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 24),
              FilledButton(onPressed: () => Navigator.pop(context), child: Text(s.t('close'))),
            ]),
      );
}

/// Cadeau gagné : carte du partenaire (« Offert par … · exemple fictif »), déjà dans « Mes offres ».
class _GiftWon extends StatelessWidget {
  const _GiftWon({super.key, required this.coupon});
  final Coupon coupon;

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(24), children: [
        const Icon(Icons.card_giftcard, size: 72, color: AppColors.taxiRed),
        const SizedBox(height: 8),
        Text(s.t('gameWon'),
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
        const SizedBox(height: 16),
        PromoCard(promo: coupon.promo, big: true, onTap: () => showCouponSheet(context, coupon)),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.check_circle, color: AppColors.moroccoGreen),
          const SizedBox(width: 6),
          Flexible(
            child: Text(s.t('giftSaved'),
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.moroccoGreen)),
          ),
        ]),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () =>
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MyOffersScreen())),
          icon: const Icon(Icons.local_offer_outlined),
          label: Text(s.t('seeMyOffers')),
        ),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(s.t('close'))),
      ]);
}

/// « Grattez et gagnez » : la couche grise s'efface sous le doigt ; le cadeau apparaît à mi-chemin.
class _ScratchGame extends StatefulWidget {
  const _ScratchGame({required this.gift, required this.onDone});
  final Promo gift;
  final VoidCallback onDone;

  @override
  State<_ScratchGame> createState() => _ScratchGameState();
}

class _ScratchGameState extends State<_ScratchGame> {
  final _points = <Offset>[];
  bool _revealed = false;

  void _scratch(Offset p) {
    if (_revealed) return;
    setState(() => _points.add(p));
    if (_points.length > 60) _reveal();
  }

  void _reveal() {
    if (_revealed) return;
    setState(() => _revealed = true);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) widget.onDone();
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          Text(s.t('gameScratchDesc'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          AspectRatio(
            aspectRatio: 1.6,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: GestureDetector(
                onPanStart: (d) => _scratch(d.localPosition),
                onPanUpdate: (d) => _scratch(d.localPosition),
                child: Stack(fit: StackFit.expand, children: [
                  Container(
                    color: widget.gift.color,
                    padding: const EdgeInsets.all(16),
                    alignment: Alignment.center,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(widget.gift.icon, color: Colors.white, size: 40),
                      Text(s.t(widget.gift.titleKey),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                      Text(widget.gift.brand, style: const TextStyle(color: Colors.white70)),
                    ]),
                  ),
                  AnimatedOpacity(
                    opacity: _revealed ? 0 : 1,
                    duration: const Duration(milliseconds: 500),
                    child: CustomPaint(painter: _ScratchPainter(_points)),
                  ),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _revealed ? null : _reveal,
            icon: const Icon(Icons.auto_fix_high),
            label: Text(s.t('scratchAll')),
          ),
        ]),
      );
}

class _ScratchPainter extends CustomPainter {
  _ScratchPainter(this.points);
  final List<Offset> points;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFB8B8B8));
    final tp = TextPainter(
      text: const TextSpan(
          text: '? ? ?', style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
    final clear = Paint()..blendMode = BlendMode.clear;
    for (final p in points) {
      canvas.drawCircle(p, 22, clear);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ScratchPainter old) => true;
}

/// « Roue des cadeaux » : 6 cases (les 3 partenaires, deux fois), la roue s'arrête sur le cadeau tiré.
class _WheelGame extends StatefulWidget {
  const _WheelGame({required this.gift, required this.onDone});
  final Promo gift;
  final VoidCallback onDone;

  @override
  State<_WheelGame> createState() => _WheelGameState();
}

class _WheelGameState extends State<_WheelGame> {
  static const _segments = 6;
  double _turns = 0;
  bool _spinning = false;

  void _spin() {
    if (_spinning) return;
    final i = tripGifts.indexOf(widget.gift);
    // Case i (ou i + 3) en haut, sous la flèche, après 4 tours complets.
    final target = (_segments - i) / _segments;
    setState(() {
      _spinning = true;
      _turns = 4 + target;
    });
    Future.delayed(const Duration(milliseconds: 3200), () {
      if (mounted) widget.onDone();
    });
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          Text(s.t('gameWheelDesc'),
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          const Icon(Icons.arrow_drop_down, size: 48, color: AppColors.ink),
          SizedBox(
            width: 280,
            height: 280,
            child: AnimatedRotation(
              turns: _turns,
              duration: const Duration(milliseconds: 3000),
              curve: Curves.easeOutCubic,
              child: CustomPaint(painter: _WheelPainter()),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _spinning ? null : _spin,
            icon: const Icon(Icons.refresh),
            label: Text(s.t('spinWheel')),
          ),
        ]),
      );
}

class _WheelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    const n = 6;
    const sweep = 2 * pi / n;
    for (var k = 0; k < n; k++) {
      final gift = tripGifts[k % tripGifts.length];
      // La case k est centrée en haut (−90°) quand la roue a tourné de −k cases.
      final start = -pi / 2 - sweep / 2 + k * sweep;
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), start, sweep, true, Paint()..color = gift.color);
      canvas.drawArc(
          Rect.fromCircle(center: c, radius: r),
          start,
          sweep,
          true,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = Colors.white);
      final mid = start + sweep / 2;
      final tp = TextPainter(
        text: TextSpan(
            text: gift.initials,
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
        textDirection: TextDirection.ltr,
      )..layout();
      final pos = c + Offset(cos(mid), sin(mid)) * r * .65;
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(mid + pi / 2);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
    canvas.drawCircle(c, r * .14, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_WheelPainter old) => false;
}

/// « Quiz du Maroc » : une question, 3 réponses ; la bonne réponse fait gagner un cadeau.
class _QuizGame extends StatefulWidget {
  const _QuizGame({required this.rnd, required this.onWin, required this.onLose});
  final Random rnd;
  final VoidCallback onWin;
  final void Function(String right) onLose;

  @override
  State<_QuizGame> createState() => _QuizGameState();
}

class _QuizGameState extends State<_QuizGame> {
  late final _q = quizQuestions[widget.rnd.nextInt(quizQuestions.length)];

  @override
  Widget build(BuildContext context) {
    final (key, answers, right) = _q;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(s.t('gameQuizDesc'), style: const TextStyle(color: AppColors.muted)),
        const SizedBox(height: 8),
        Text(s.t(key), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 20),
        for (var i = 0; i < answers.length; i++) ...[
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            onPressed: () => i == right ? widget.onWin() : widget.onLose(answers[right]),
            child: Text(answers[i], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 10),
        ],
      ]),
    );
  }
}
