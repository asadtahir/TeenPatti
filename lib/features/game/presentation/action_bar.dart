import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teen_patti_engine/teen_patti_engine.dart';

import '../../../core/theme/design_tokens.dart';
import '../../../shared/widgets/chip_badge.dart';
import 'feedback_service.dart';
import 'game_controller.dart';

/// The local player's controls. Buttons are enabled strictly from engine legality.
class ActionBar extends ConsumerWidget {
  const ActionBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(gameControllerProvider);
    final g = ui.game;
    if (g == null) return const SizedBox(height: 96);
    final ctrl = ref.read(gameControllerProvider.notifier);
    final fb = ref.read(feedbackServiceProvider);
    final legal = ui.legal;
    final me = ui.localPlayerId;
    final meState = g.playerById(me);

    void send(GameAction a) {
      fb.click();
      ctrl.act(a);
    }

    Widget bar(List<Widget> children) => Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
          child: Row(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.sm),
                Expanded(child: children[i]),
              ],
            ],
          ),
        );

    if (g.isFinished) return const SizedBox(height: 96);

    if (legal.canRespondSideShow) {
      final requester = g.playerById(g.pendingSideShow!.requesterId).name;
      return Column(mainAxisSize: MainAxisSize.min, children: [
        Text('$requester asks for a side show', style: AppText.body),
        bar([
          _Btn('DECLINE', onTap: () => send(SideShowResponse(me, accept: false))),
          _Btn('ACCEPT', primary: true, onTap: () => send(SideShowResponse(me, accept: true))),
        ]),
      ]);
    }

    if (meState.folded) {
      return const SizedBox(
          height: 96, child: Center(child: Text('You packed. Watching the rest of the hand...', style: AppText.caption)));
    }

    final extras = <Widget>[
      if (legal.canSee) _Btn('SEE CARDS', icon: Icons.visibility, onTap: () => send(SeeCards(me))),
      if (legal.canSideShow) _Btn('SIDE SHOW', onTap: () => send(SideShowRequest(me))),
    ];

    final main = <Widget>[
      _Btn('PACK', onTap: legal.canFold ? () => send(Fold(me)) : null, danger: true),
      if (legal.canShow)
        _Btn('SHOW ${formatChips(legal.showAmount)}', primary: true, onTap: () => send(Show(me)))
      else
        _Btn(
          '${meState.seen ? 'CHAAL' : 'BLIND'} ${formatChips(legal.callAmount)}',
          primary: true,
          onTap: legal.isTurn && legal.canCall ? () => send(Call(me)) : null,
        ),
      _Btn('RAISE ${formatChips(legal.raiseAmount)}',
          onTap: legal.isTurn && legal.canRaise ? () => send(Raise(me)) : null),
    ];

    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (extras.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm, left: AppSpacing.md, right: AppSpacing.md),
          child: Row(children: [
            for (var i = 0; i < extras.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.sm),
              Expanded(child: extras[i]),
            ]
          ]),
        ),
      bar(main),
    ]);
  }
}

class _Btn extends StatelessWidget {
  const _Btn(this.label, {this.onTap, this.primary = false, this.danger = false, this.icon});
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final bool danger;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final bg = primary ? AppColors.gold : (danger ? AppColors.crimson.withValues(alpha: 0.85) : AppColors.surfaceHigh);
    final fg = primary ? AppColors.night : AppColors.textPrimary;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: onTap,
            child: Container(
              height: 48,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: primary ? null : Border.all(color: Colors.white24),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 4)],
                  Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w900, letterSpacing: 0.8, fontSize: 14)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
