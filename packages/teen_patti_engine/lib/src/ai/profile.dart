enum Difficulty { easy, medium, hard }

enum Personality { conservative, aggressive, balanced, bluffer }

class AIProfile {
  const AIProfile(this.difficulty, this.personality);
  final Difficulty difficulty;
  final Personality personality;
}
