class GameState {
  const GameState({
    required this.gold,
    required this.lifetimeGold,
    required this.energy,
    required this.maxEnergy,
    required this.pickaxeLevel,
    required this.autoMinerLevel,
    required this.totalTaps,
    this.doubleBoostUntil,
  });

  factory GameState.initial() => const GameState(
        gold: 0,
        lifetimeGold: 0,
        energy: 100,
        maxEnergy: 100,
        pickaxeLevel: 1,
        autoMinerLevel: 0,
        totalTaps: 0,
      );

  final int gold;
  final int lifetimeGold;
  final int energy;
  final int maxEnergy;
  final int pickaxeLevel;
  final int autoMinerLevel;
  final int totalTaps;
  final DateTime? doubleBoostUntil;

  int get goldPerTap => pickaxeLevel;
  int get level => (lifetimeGold ~/ 1000) + 1;
  int get pickaxeUpgradeCost => 25 * pickaxeLevel * pickaxeLevel;
  int get autoMinerUpgradeCost => 100 * (autoMinerLevel + 1);

  bool isDoubleBoostActive([DateTime? now]) {
    final until = doubleBoostUntil;
    return until != null && until.isAfter(now ?? DateTime.now());
  }

  GameState tap({DateTime? now}) {
    if (energy <= 0) return this;
    final multiplier = isDoubleBoostActive(now) ? 2 : 1;
    final reward = goldPerTap * multiplier;
    return copyWith(
      gold: gold + reward,
      lifetimeGold: lifetimeGold + reward,
      energy: energy - 1,
      totalTaps: totalTaps + 1,
    );
  }

  GameState regenerate(Duration elapsed) {
    final seconds = elapsed.inSeconds;
    if (seconds <= 0) return this;
    final passiveReward = autoMinerLevel * seconds;
    return copyWith(
      gold: gold + passiveReward,
      lifetimeGold: lifetimeGold + passiveReward,
      energy: (energy + seconds).clamp(0, maxEnergy),
    );
  }

  GameState upgradePickaxe() {
    if (gold < pickaxeUpgradeCost) return this;
    return copyWith(
      gold: gold - pickaxeUpgradeCost,
      pickaxeLevel: pickaxeLevel + 1,
    );
  }

  GameState upgradeAutoMiner() {
    if (gold < autoMinerUpgradeCost) return this;
    return copyWith(
      gold: gold - autoMinerUpgradeCost,
      autoMinerLevel: autoMinerLevel + 1,
    );
  }

  GameState activateDoubleBoost(DateTime now) =>
      copyWith(doubleBoostUntil: now.add(const Duration(minutes: 5)));

  Map<String, Object?> toJson() => {
        'gold': gold,
        'lifetimeGold': lifetimeGold,
        'energy': energy,
        'maxEnergy': maxEnergy,
        'pickaxeLevel': pickaxeLevel,
        'autoMinerLevel': autoMinerLevel,
        'totalTaps': totalTaps,
        'doubleBoostUntil': doubleBoostUntil?.toIso8601String(),
      };

  factory GameState.fromJson(Map<String, Object?> json) => GameState(
        gold: json['gold'] as int? ?? 0,
        lifetimeGold: json['lifetimeGold'] as int? ?? 0,
        energy: json['energy'] as int? ?? 100,
        maxEnergy: json['maxEnergy'] as int? ?? 100,
        pickaxeLevel: json['pickaxeLevel'] as int? ?? 1,
        autoMinerLevel: json['autoMinerLevel'] as int? ?? 0,
        totalTaps: json['totalTaps'] as int? ?? 0,
        doubleBoostUntil: json['doubleBoostUntil'] == null
            ? null
            : DateTime.tryParse(json['doubleBoostUntil'] as String),
      );

  GameState copyWith({
    int? gold,
    int? lifetimeGold,
    int? energy,
    int? maxEnergy,
    int? pickaxeLevel,
    int? autoMinerLevel,
    int? totalTaps,
    DateTime? doubleBoostUntil,
  }) =>
      GameState(
        gold: gold ?? this.gold,
        lifetimeGold: lifetimeGold ?? this.lifetimeGold,
        energy: energy ?? this.energy,
        maxEnergy: maxEnergy ?? this.maxEnergy,
        pickaxeLevel: pickaxeLevel ?? this.pickaxeLevel,
        autoMinerLevel: autoMinerLevel ?? this.autoMinerLevel,
        totalTaps: totalTaps ?? this.totalTaps,
        doubleBoostUntil: doubleBoostUntil ?? this.doubleBoostUntil,
      );
}
