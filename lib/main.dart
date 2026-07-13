import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/intl.dart';

import 'ads/ad_service.dart';
import 'game/game_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const GoldTapMinerApp());
}

class GoldTapMinerApp extends StatelessWidget {
  const GoldTapMinerApp({super.key, this.testMode = false});

  final bool testMode;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gold Tap Miner',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xfff59e0b)),
        useMaterial3: true,
        fontFamily: 'sans',
      ),
      home: MiningScreen(testMode: testMode),
    );
  }
}

class MiningScreen extends StatefulWidget {
  const MiningScreen({super.key, required this.testMode});
  final bool testMode;

  @override
  State<MiningScreen> createState() => _MiningScreenState();
}

class _MiningScreenState extends State<MiningScreen> with TickerProviderStateMixin {
  late final GameController controller;
  late final AdService ads;
  late final AnimationController pickaxeAnimation;
  late final AnimationController rewardAnimation;
  BannerAd? banner;
  int lastReward = 0;
  int previousLevel = 1;
  Timer? rewardTimer;

  @override
  void initState() {
    super.initState();
    controller = GameController(persist: !widget.testMode);
    ads = AdService(enabled: !widget.testMode);
    pickaxeAnimation = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    rewardAnimation = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    controller.addListener(_onStateChanged);
    if (!widget.testMode) {
      controller.start();
      ads.initialize();
      banner = ads.createBanner()..load();
    }
  }

  void _onStateChanged() {
    if (!mounted) return;
    if (controller.state.level > previousLevel) {
      previousLevel = controller.state.level;
      ads.showInterstitialAtNaturalBreak();
      _showSnack('LEVEL UP! Sekarang level $previousLevel');
    }
    setState(() {});
  }

  void _tapMiner() {
    final earned = controller.tap();
    if (earned <= 0) {
      _showSnack('Energy habis. Tunggu recharge dulu.');
      return;
    }
    HapticFeedback.lightImpact();
    pickaxeAnimation.forward(from: 0);
    setState(() => lastReward = earned);
    rewardAnimation.forward(from: 0);
    rewardTimer?.cancel();
    rewardTimer = Timer(const Duration(milliseconds: 850), () {
      if (mounted) setState(() => lastReward = 0);
    });
  }

  Future<void> _activateBoost() async {
    final earned = await ads.showRewarded();
    if (!mounted) return;
    if (earned) {
      controller.activateDoubleBoost();
      _showSnack('2X GOLD aktif selama 5 menit!');
    } else {
      _showSnack('Iklan belum tersedia. Coba lagi sebentar.');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  void dispose() {
    rewardTimer?.cancel();
    banner?.dispose();
    ads.dispose();
    controller.removeListener(_onStateChanged);
    controller.dispose();
    pickaxeAnimation.dispose();
    rewardAnimation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final formatter = NumberFormat.compact();
    final boosted = state.isDoubleBoostActive();
    return Scaffold(
      backgroundColor: const Color(0xfffff3c4),
      body: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: MineBackgroundPainter())),
          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  gold: formatter.format(state.gold),
                  energy: state.energy,
                  maxEnergy: state.maxEnergy,
                  boosted: boosted,
                ),
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(top: 18, right: 24, child: _LevelBadge(level: state.level)),
                      Positioned(
                        top: 70,
                        left: 30,
                        right: 30,
                        bottom: 10,
                        child: GestureDetector(
                          key: const Key('miner-tap-target'),
                          behavior: HitTestBehavior.opaque,
                          onTap: _tapMiner,
                          child: AnimatedBuilder(
                            animation: pickaxeAnimation,
                            builder: (_, __) => Transform.scale(
                              scale: 1 - (math.sin(pickaxeAnimation.value * math.pi) * .045),
                              child: CustomPaint(
                                painter: MinerPainter(swing: pickaxeAnimation.value),
                                child: const SizedBox.expand(),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (lastReward > 0)
                        AnimatedBuilder(
                          animation: rewardAnimation,
                          builder: (_, __) => Positioned(
                            top: 118 - (rewardAnimation.value * 70),
                            child: Opacity(
                              opacity: 1 - rewardAnimation.value,
                              child: Text(
                                '+$lastReward',
                                style: const TextStyle(
                                  color: Color(0xffffb300),
                                  fontSize: 38,
                                  fontWeight: FontWeight.w900,
                                  shadows: [Shadow(color: Colors.brown, blurRadius: 4, offset: Offset(2, 2))],
                                ),
                              ),
                            ),
                          ),
                        ),
                      const Positioned(
                        bottom: 6,
                        child: Text('TAP MINER UNTUK MENDAPAT GOLD', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xff7c4a14))),
                      ),
                    ],
                  ),
                ),
                _BottomPanel(
                  controller: controller,
                  onUpgrade: _showUpgrade,
                  onShop: _showShop,
                  onBoost: _activateBoost,
                  banner: banner,
                  testMode: widget.testMode,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showUpgrade() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xfffff7d6),
      showDragHandle: true,
      builder: (context) => AnimatedBuilder(
        animation: controller,
        builder: (_, __) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('MINING UPGRADES', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              _UpgradeTile(
                icon: Icons.hardware,
                title: 'Pickaxe Lv.${controller.state.pickaxeLevel}',
                subtitle: '${controller.state.goldPerTap} gold per tap',
                cost: controller.state.pickaxeUpgradeCost,
                onTap: () {
                  if (!controller.upgradePickaxe()) _showSnack('Gold belum cukup.');
                },
              ),
              _UpgradeTile(
                icon: Icons.precision_manufacturing,
                title: 'Auto Miner Lv.${controller.state.autoMinerLevel}',
                subtitle: '${controller.state.autoMinerLevel} gold per second',
                cost: controller.state.autoMinerUpgradeCost,
                onTap: () {
                  if (!controller.upgradeAutoMiner()) _showSnack('Gold belum cukup.');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showShop() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xfffff7d6),
      showDragHandle: true,
      builder: (_) => const Padding(
        padding: EdgeInsets.fromLTRB(24, 8, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('MINER SHOP', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            SizedBox(height: 16),
            Icon(Icons.construction, size: 54, color: Colors.orange),
            SizedBox(height: 10),
            Text('Skin miner, helmet, dan remove ads akan hadir di update berikutnya.', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.gold, required this.energy, required this.maxEnergy, required this.boosted});
  final String gold;
  final int energy;
  final int maxEnergy;
  final bool boosted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xffffdc58), Color(0xfffff5bf)]),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xffb76b12), width: 3),
          boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 8, offset: Offset(0, 4))],
        ),
        child: Row(
          children: [
            const SizedBox(width: 10),
            const _GoldCoin(size: 48),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('GOLD', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xff75430b))),
                  Text(gold, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xff5d3207))),
                ],
              ),
            ),
            SizedBox(
              width: 108,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(boosted ? Icons.bolt : Icons.battery_charging_full, color: boosted ? Colors.deepOrange : Colors.green, size: 18),
                      const SizedBox(width: 4),
                      Text('$energy/$maxEnergy', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xff356b25))),
                    ]),
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(value: energy / maxEnergy, minHeight: 7, color: Colors.green, backgroundColor: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level});
  final int level;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: const Color(0xffffedaa), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.brown, width: 2)),
        child: Text('LEVEL $level', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xff5d370f))),
      );
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({required this.controller, required this.onUpgrade, required this.onShop, required this.onBoost, required this.banner, required this.testMode});
  final GameController controller;
  final VoidCallback onUpgrade;
  final VoidCallback onShop;
  final VoidCallback onBoost;
  final BannerAd? banner;
  final bool testMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
      decoration: const BoxDecoration(
        color: Color(0xfffff9dc),
        borderRadius: BorderRadius.vertical(top: Radius.circular(38)),
        boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, -4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.brown.shade200)),
            child: banner != null && !testMode
                ? AdWidget(ad: banner!)
                : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.campaign_outlined), SizedBox(width: 8), Text('BANNER AD (TEST)', style: TextStyle(fontWeight: FontWeight.w700))]),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _GameButton(label: 'UPGRADE', color: const Color(0xff73778f), onTap: onUpgrade)),
              const SizedBox(width: 10),
              Expanded(child: _GameButton(label: 'SHOP', color: const Color(0xff2186d7), onTap: onShop)),
              const SizedBox(width: 10),
              Expanded(child: _GameButton(label: '2X GOLD', color: const Color(0xfff59e0b), icon: Icons.play_arrow_rounded, onTap: onBoost)),
            ],
          ),
        ],
      ),
    );
  }
}

class _GameButton extends StatelessWidget {
  const _GameButton({required this.label, required this.color, required this.onTap, this.icon});
  final String label;
  final Color color;
  final VoidCallback onTap;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            height: 58,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white, width: 3), boxShadow: const [BoxShadow(color: Color(0x55000000), offset: Offset(0, 5))]),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (icon != null) Icon(icon, color: Colors.white, size: 21),
              Flexible(child: Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, shadows: [Shadow(color: Colors.black45, offset: Offset(1, 2))]))),
            ]),
          ),
        ),
      );
}

class _UpgradeTile extends StatelessWidget {
  const _UpgradeTile({required this.icon, required this.title, required this.subtitle, required this.cost, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final int cost;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: CircleAvatar(backgroundColor: Colors.amber.shade200, child: Icon(icon, color: Colors.brown)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(subtitle),
          trailing: FilledButton(onPressed: onTap, child: Text('🪙 $cost')),
        ),
      );
}

class _GoldCoin extends StatelessWidget {
  const _GoldCoin({required this.size});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: const RadialGradient(colors: [Color(0xfffff176), Color(0xffffa000)]), border: Border.all(color: const Color(0xff8d4c00), width: 3), boxShadow: const [BoxShadow(color: Colors.brown, blurRadius: 3)]),
        alignment: Alignment.center,
        child: Text('G', style: TextStyle(fontSize: size * .48, color: Colors.white, fontWeight: FontWeight.w900, shadows: const [Shadow(color: Colors.brown, offset: Offset(2, 2))])),
      );
}

class MineBackgroundPainter extends CustomPainter {
  const MineBackgroundPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final sky = Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xfffff5c8), Color(0xffffd66b)]).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sky);
    final hill = Paint()..color = const Color(0xffd5cf82);
    canvas.drawOval(Rect.fromLTWH(-80, size.height * .17, size.width * .7, 190), hill);
    canvas.drawOval(Rect.fromLTWH(size.width * .38, size.height * .12, size.width * .85, 230), hill..color = const Color(0xffb9c47a));
    final sand = Paint()..color = const Color(0xffffcf55);
    canvas.drawPath(Path()..moveTo(0, size.height * .42)..quadraticBezierTo(size.width * .45, size.height * .30, size.width, size.height * .43)..lineTo(size.width, size.height)..lineTo(0, size.height)..close(), sand);
    final rng = math.Random(7);
    for (var i = 0; i < 24; i++) {
      final x = rng.nextDouble() * size.width;
      final y = size.height * .25 + rng.nextDouble() * size.height * .62;
      final r = 5 + rng.nextDouble() * 11;
      canvas.drawCircle(Offset(x, y), r, Paint()..color = i.isEven ? const Color(0xffffa000) : const Color(0xff9b7b56));
      if (i % 4 == 0) canvas.drawCircle(Offset(x - 2, y - 3), r * .28, Paint()..color = Colors.yellowAccent);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class MinerPainter extends CustomPainter {
  const MinerPainter({required this.swing});
  final double swing;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * .54);
    canvas.drawOval(Rect.fromCenter(center: Offset(center.dx, center.dy + 150), width: 230, height: 45), Paint()..color = const Color(0x33000000));
    canvas.drawCircle(center, 160, Paint()..color = const Color(0xfffff8dc));
    final skin = Paint()..color = const Color(0xffffc49a);
    canvas.drawCircle(Offset(center.dx, center.dy - 75), 69, skin);
    canvas.drawArc(Rect.fromCenter(center: Offset(center.dx, center.dy - 106), width: 150, height: 86), math.pi, math.pi, false, Paint()..color = const Color(0xffffa000)..strokeWidth = 28..style = PaintingStyle.stroke);
    canvas.drawRect(Rect.fromCenter(center: Offset(center.dx, center.dy - 134), width: 125, height: 24), Paint()..color = const Color(0xffffb300));
    canvas.drawCircle(Offset(center.dx, center.dy - 140), 17, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(center.dx - 24, center.dy - 75), 8, Paint()..color = const Color(0xff3c2415));
    canvas.drawCircle(Offset(center.dx + 24, center.dy - 75), 8, Paint()..color = const Color(0xff3c2415));
    canvas.drawArc(Rect.fromCenter(center: Offset(center.dx, center.dy - 48), width: 34, height: 22), 0, math.pi, false, Paint()..color = Colors.brown..strokeWidth = 4..style = PaintingStyle.stroke);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(center.dx, center.dy + 55), width: 130, height: 165), const Radius.circular(30)), Paint()..color = const Color(0xff4a5568));
    canvas.drawRect(Rect.fromCenter(center: Offset(center.dx, center.dy + 25), width: 112, height: 45), Paint()..color = const Color(0xffffc107));
    canvas.drawLine(Offset(center.dx - 36, center.dy + 120), Offset(center.dx - 48, center.dy + 190), Paint()..color = const Color(0xff42352b)..strokeWidth = 30..strokeCap = StrokeCap.round);
    canvas.drawLine(Offset(center.dx + 36, center.dy + 120), Offset(center.dx + 48, center.dy + 190), Paint()..color = const Color(0xff42352b)..strokeWidth = 30..strokeCap = StrokeCap.round);
    canvas.save();
    canvas.translate(center.dx + 82, center.dy + 10);
    canvas.rotate(-.75 + swing * 1.35);
    canvas.drawLine(Offset.zero, const Offset(0, -145), Paint()..color = const Color(0xff75491f)..strokeWidth = 13..strokeCap = StrokeCap.round);
    canvas.drawLine(const Offset(-55, -145), const Offset(55, -145), Paint()..color = const Color(0xff5d6872)..strokeWidth = 17..strokeCap = StrokeCap.round);
    canvas.restore();
    for (final dx in [-105.0, -75.0, 82.0, 110.0]) {
      canvas.drawCircle(Offset(center.dx + dx, center.dy + 145 - dx.abs() * .15), 18, Paint()..color = const Color(0xffffa000));
      canvas.drawCircle(Offset(center.dx + dx - 5, center.dy + 139 - dx.abs() * .15), 5, Paint()..color = Colors.yellowAccent);
    }
  }
  @override
  bool shouldRepaint(covariant MinerPainter oldDelegate) => oldDelegate.swing != swing;
}
