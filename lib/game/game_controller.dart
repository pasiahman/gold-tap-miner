import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game_state.dart';

class GameController extends ChangeNotifier {
  GameController({required this.persist}) : state = GameState.initial();

  static const _storageKey = 'gold_tap_miner_state_v1';
  final bool persist;
  GameState state;
  Timer? _timer;
  DateTime _lastTick = DateTime.now();

  Future<void> start() async {
    if (persist) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        state = GameState.fromJson(jsonDecode(raw) as Map<String, Object?>);
      }
    }
    _lastTick = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    notifyListeners();
  }

  void tick() {
    final now = DateTime.now();
    final elapsed = now.difference(_lastTick);
    _lastTick = now;
    state = state.regenerate(elapsed);
    notifyListeners();
    save();
  }

  int tap() {
    final before = state.gold;
    state = state.tap();
    final earned = state.gold - before;
    if (earned > 0) {
      notifyListeners();
      save();
    }
    return earned;
  }

  bool upgradePickaxe() {
    final before = state.pickaxeLevel;
    state = state.upgradePickaxe();
    final changed = state.pickaxeLevel != before;
    if (changed) {
      notifyListeners();
      save();
    }
    return changed;
  }

  bool upgradeAutoMiner() {
    final before = state.autoMinerLevel;
    state = state.upgradeAutoMiner();
    final changed = state.autoMinerLevel != before;
    if (changed) {
      notifyListeners();
      save();
    }
    return changed;
  }

  void activateDoubleBoost() {
    state = state.activateDoubleBoost(DateTime.now());
    notifyListeners();
    save();
  }

  Future<void> save() async {
    if (!persist) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(state.toJson()));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
