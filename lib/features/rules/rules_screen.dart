import 'package:flutter/material.dart';
import 'package:teen_patti_engine/teen_patti_engine.dart';

import '../../core/theme/design_tokens.dart';
import '../../shared/animations/entrance.dart';
import '../../shared/widgets/card_views.dart';
import '../../shared/widgets/screen_scaffold.dart';

/// How to play Teen Patti: goal, round flow, actions and hand rankings. Opened from the home
/// screen, settings and the table; the scaffold supplies the back button.
class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  static const _ranks = [
    _RankRow(
      'Trail (Set)',
      'Three cards of the same rank. The best hand. AAA beats everything.',
      [
        PlayingCard(Rank.ace, Suit.spades),
        PlayingCard(Rank.ace, Suit.hearts),
        PlayingCard(Rank.ace, Suit.diamonds),
      ],
    ),
    _RankRow(
      'Pure Sequence',
      'Three consecutive cards of the same suit.',
      [
        PlayingCard(Rank.nine, Suit.hearts),
        PlayingCard(Rank.ten, Suit.hearts),
        PlayingCard(Rank.jack, Suit.hearts),
      ],
    ),
    _RankRow('Sequence', 'Three consecutive cards of mixed suits.', [
      PlayingCard(Rank.five, Suit.spades),
      PlayingCard(Rank.six, Suit.hearts),
      PlayingCard(Rank.seven, Suit.clubs),
    ]),
    _RankRow('Color', 'Three cards of the same suit, not in sequence.', [
      PlayingCard(Rank.king, Suit.clubs),
      PlayingCard(Rank.eight, Suit.clubs),
      PlayingCard(Rank.three, Suit.clubs),
    ]),
    _RankRow('Pair', 'Two cards of the same rank.', [
      PlayingCard(Rank.queen, Suit.spades),
      PlayingCard(Rank.queen, Suit.diamonds),
      PlayingCard(Rank.four, Suit.hearts),
    ]),
    _RankRow('High Card', 'None of the above. The highest card decides.', [
      PlayingCard(Rank.ace, Suit.diamonds),
      PlayingCard(Rank.nine, Suit.spades),
      PlayingCard(Rank.two, Suit.clubs),
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[
      const _Section(
        icon: Icons.flag_outlined,
        title: 'Goal',
        lines: [
          'Teen Patti is played with 3 cards each. Win the pot by holding the best hand when '
              'the others pack (fold), or by winning the final show.',
          'This app uses virtual chips only. No real money is ever involved.',
        ],
      ),
      const _Section(
        icon: Icons.replay_circle_filled_outlined,
        title: 'How a round goes',
        lines: [
          '1. Everyone pays the boot (entry amount) into the pot.',
          '2. Each player is dealt 3 cards face down.',
          '3. Play moves around the table. On your turn you can play blind or look at your cards (seen).',
          '4. The round ends when only one player is left, or when a show is made.',
        ],
      ),
      _Section(
        icon: Icons.touch_app_outlined,
        title: 'Your moves',
        lines: [
          'BLIND: you have not looked at your cards. You bet the current stake.',
          'SEEN: you have looked at your cards. You bet double the current stake.',
          'CHAAL / CALL: match the stake and stay in the hand.',
          'RAISE: double the stake. The stake can never go above '
              '${GameSettings().maxStakeMultiple}x the boot.',
          'PACK: fold your hand and sit out the rest of the round.',
          'SIDE SHOW: if you and the player before you have both seen your cards, you can ask to '
              'compare. If they accept, the lower hand is packed automatically. A tie packs the asker.',
          'SHOW: when only two players are left you can pay to compare cards. The better hand wins.',
        ],
      ),
      _Section(
        icon: Icons.timer_outlined,
        title: 'Good to know',
        lines: [
          'You have ${GameSettings().turnSeconds} seconds per turn. If the timer runs out you pack.',
          'If the pot reaches ${GameSettings().potLimitMultiple}x the boot, a show is forced.',
          'Sequences rank A-K-Q highest, then A-2-3, then K-Q-J down to 4-3-2.',
          'If two hands tie exactly in a show, the player who asked for the show loses.',
        ],
      ),
      const Padding(
        padding: EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
        child: _Heading(Icons.emoji_events_outlined, 'Hand rankings (best to worst)'),
      ),
      ..._ranks,
      const SizedBox(height: AppSpacing.md),
    ];

    return ScreenScaffold(
      title: 'How to Play',
      child: ListView(
        children: staggered(sections, step: const Duration(milliseconds: 60), offset: const Offset(0, 22)),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.gold, size: 22),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: AppText.title.copyWith(color: AppColors.gold, fontSize: 18),
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, required this.lines});
  final IconData icon;
  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: _panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Heading(icon, title),
          const SizedBox(height: AppSpacing.sm),
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(l, style: AppText.body.copyWith(fontSize: 14, height: 1.35)),
            ),
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow(this.name, this.text, this.cards);
  final String name;
  final String text;
  final List<PlayingCard> cards;

  @override
  Widget build(BuildContext context) {
    const w = 38.0;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      decoration: _panel,
      child: Row(
        children: [
          SizedBox(
            width: w * 2.5 + 8,
            height: cardHeightFor(w) + 4,
            child: Stack(
              children: [
                for (var i = 0; i < cards.length; i++)
                  Positioned(
                    left: i * w * 0.75,
                    top: 2,
                    child: CardFace(card: cards[i], width: w),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(text, style: AppText.caption.copyWith(height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final _panel = BoxDecoration(
  color: AppColors.surface.withValues(alpha: 0.82),
  borderRadius: BorderRadius.circular(AppRadius.md),
  border: Border.all(color: AppColors.gold.withValues(alpha: 0.18)),
);
