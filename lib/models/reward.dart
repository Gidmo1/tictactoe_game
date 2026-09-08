/// Reward achievement types: trophies, medals, or awards
enum RewardType {
  trophy,
  medal,
  award,
}

/// Reward rarity levels
enum RewardRarity {
  common,
  rare,
  epic,
  legendary,
}

/// A player achievement reward (trophy, medal, or award)
class Reward {
  final String id;
  final String name;
  final RewardType type;
  final RewardRarity rarity;
  final String assetPath;
  final String description;
  final bool isUnlocked;
  final DateTime? unlockedAt;

  Reward({
    required this.id,
    required this.name,
    required this.type,
    required this.rarity,
    required this.assetPath,
    required this.description,
    this.isUnlocked = false,
    this.unlockedAt,
  });

  /// Create a copy with optional field overrides
  Reward copyWith({
    String? id,
    String? name,
    RewardType? type,
    RewardRarity? rarity,
    String? assetPath,
    String? description,
    bool? isUnlocked,
    DateTime? unlockedAt,
  }) {
    return Reward(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      rarity: rarity ?? this.rarity,
      assetPath: assetPath ?? this.assetPath,
      description: description ?? this.description,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
    );
  }

  @override
  String toString() => 'Reward(id: $id, name: $name, isUnlocked: $isUnlocked)';
}

/// Predefined rewards for the app
class RewardLibrary {
  static final List<Reward> allRewards = [
    // Trophies
    Reward(
      id: 'champion',
      name: 'Champion',
      type: RewardType.trophy,
      rarity: RewardRarity.legendary,
      assetPath: 'assets/images/champion.png',
      description: 'Won a tournament',
      isUnlocked: false,
    ),
    Reward(
      id: 'finalist',
      name: 'Finalist',
      type: RewardType.trophy,
      rarity: RewardRarity.epic,
      assetPath: 'assets/images/finalist.png',
      description: 'Reached the tournament final',
      isUnlocked: false,
    ),
    Reward(
      id: 'host',
      name: 'Tournament Host',
      type: RewardType.trophy,
      rarity: RewardRarity.epic,
      assetPath: 'assets/images/host.png',
      description: 'Created and hosted a tournament',
      isUnlocked: false,
    ),

    // Medals
    Reward(
      id: 'first_tournament',
      name: 'First Tournament',
      type: RewardType.medal,
      rarity: RewardRarity.common,
      assetPath: 'assets/images/first_tournament.png',
      description: 'Completed your first tournament',
      isUnlocked: false,
    ),
    Reward(
      id: 'win_streak',
      name: 'Win Streak',
      type: RewardType.medal,
      rarity: RewardRarity.rare,
      assetPath: 'assets/images/win_streak.png',
      description: 'Won 3 matches in a row',
      isUnlocked: false,
    ),
    Reward(
      id: 'participant',
      name: 'Participant',
      type: RewardType.medal,
      rarity: RewardRarity.common,
      assetPath: 'assets/images/participant.png',
      description: 'Joined a tournament',
      isUnlocked: false,
    ),
    Reward(
      id: 'top_participant',
      name: 'Top Performer',
      type: RewardType.medal,
      rarity: RewardRarity.rare,
      assetPath: 'assets/images/top_participant.png',
      description: 'Achieved highest win rate in an event',
      isUnlocked: false,
    ),

    // Awards
    Reward(
      id: 'community_legend',
      name: 'Community Legend',
      type: RewardType.award,
      rarity: RewardRarity.legendary,
      assetPath: 'assets/images/community_legend.png',
      description: 'Recognized as a community pillar',
      isUnlocked: false,
    ),
    Reward(
      id: 'bracket_breaker',
      name: 'Bracket Breaker',
      type: RewardType.award,
      rarity: RewardRarity.epic,
      assetPath: 'assets/images/bracket_breaker.png',
      description: 'Pulled off an upset in tournament bracket',
      isUnlocked: false,
    ),
    Reward(
      id: 'most_improved',
      name: 'Most Improved',
      type: RewardType.award,
      rarity: RewardRarity.rare,
      assetPath: 'assets/images/most_improved.png',
      description: 'Showed the most improvement in ranking',
      isUnlocked: false,
    ),
    Reward(
      id: 'mvp',
      name: 'MVP',
      type: RewardType.award,
      rarity: RewardRarity.epic,
      assetPath: 'assets/images/mvp.png',
      description: 'Most valuable player in a tournament',
      isUnlocked: false,
    ),
    Reward(
      id: 'event_hero',
      name: 'Event Hero',
      type: RewardType.award,
      rarity: RewardRarity.rare,
      assetPath: 'assets/images/event_hero.png',
      description: 'Standout performer in a special event',
      isUnlocked: false,
    ),
  ];

  /// Get all rewards by type
  static List<Reward> getByType(RewardType type) {
    return allRewards.where((r) => r.type == type).toList();
  }

  /// Get a reward by ID
  static Reward? getById(String id) {
    try {
      return allRewards.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }
}
