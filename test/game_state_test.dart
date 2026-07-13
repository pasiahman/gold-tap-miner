import 'package:flutter_test/flutter_test.dart';
import 'package:gold_tap_miner/game/game_state.dart';

void main() {
  group('GameState', () {
    test('tap spends energy and awards gold', () {
      final state = GameState.initial();
      final result = state.tap();

      expect(result.gold, 1);
      expect(result.energy, 99);
      expect(result.totalTaps, 1);
    });

    test('tap does nothing with zero energy', () {
      final state = GameState.initial().copyWith(energy: 0);
      final result = state.tap();

      expect(result.gold, 0);
      expect(result.totalTaps, 0);
    });

    test('upgrading pickaxe increases gold per tap and charges gold', () {
      final state = GameState.initial().copyWith(gold: 100);
      final result = state.upgradePickaxe();

      expect(result.pickaxeLevel, 2);
      expect(result.goldPerTap, 2);
      expect(result.gold, 75);
    });

    test('double boost doubles tap reward', () {
      final now = DateTime.utc(2026, 7, 13, 10);
      final state = GameState.initial().activateDoubleBoost(now);
      final result = state.tap(now: now.add(const Duration(minutes: 1)));

      expect(result.gold, 2);
      expect(result.isDoubleBoostActive(now.add(const Duration(minutes: 1))), isTrue);
    });

    test('energy regeneration respects maximum', () {
      final state = GameState.initial().copyWith(energy: 95);
      final result = state.regenerate(const Duration(seconds: 10));

      expect(result.energy, 100);
    });

    test('auto mining adds passive gold', () {
      final state = GameState.initial().copyWith(autoMinerLevel: 2);
      final result = state.regenerate(const Duration(seconds: 5));

      expect(result.gold, 10);
    });

    test('level is derived from lifetime gold', () {
      final state = GameState.initial().copyWith(lifetimeGold: 2500);
      expect(state.level, 3);
    });
  });
}
