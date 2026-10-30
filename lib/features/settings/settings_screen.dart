import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/animations/entrance.dart';
import '../../shared/widgets/screen_scaffold.dart';
import '../game/presentation/feedback_service.dart';
import '../online/online_controller.dart';
import 'settings_controller.dart';
import 'settings_model.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);

    Widget toggle(
      String title,
      bool value,
      AppSettings Function(bool) apply, {
      String? subtitle,
      IconData? icon,
    }) => SwitchListTile(
      secondary: icon == null ? null : Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      value: value,
      onChanged: (v) {
        ctrl.update((_) => apply(v));
        // Confirm the sound is on by playing a click as it is switched on.
        if (v && title == 'Sound effects') {
          ref.read(soundServiceProvider).play(SoundEffect.chip);
        }
      },
    );

    return ScreenScaffold(
      title: 'Settings',
      child: ListView(
        children: staggered(
          [
            toggle(
              'Sound effects',
              s.sound,
              (v) => s.copyWith(sound: v),
              subtitle: 'Cards, chips, clicks and win / lose jingles',
              icon: Icons.volume_up_outlined,
            ),
            toggle('Vibration', s.vibration, (v) => s.copyWith(vibration: v)),
            toggle(
              'Notifications',
              s.notifications,
              (v) => s.copyWith(notifications: v),
            ),
            toggle(
              'Reduce animations',
              s.reduceMotion,
              (v) => s.copyWith(reduceMotion: v),
            ),
            ListTile(
              title: const Text('Graphics quality'),
              trailing: DropdownButton<GraphicsQuality>(
                value: s.graphicsQuality,
                underline: const SizedBox.shrink(),
                items: [
                  for (final q in GraphicsQuality.values)
                    DropdownMenuItem(
                      value: q,
                      child: Text(
                        q.name[0].toUpperCase() + q.name.substring(1),
                      ),
                    ),
                ],
                onChanged: (q) {
                  if (q != null) {
                    ctrl.update((_) => s.copyWith(graphicsQuality: q));
                  }
                },
              ),
            ),
            ListTile(
              title: const Text('Server address'),
              subtitle: Text(ref.watch(serverUrlProvider)),
              trailing: const Icon(Icons.edit, size: 18),
              onTap: () async {
                final controller = TextEditingController(
                  text: ref.read(serverUrlProvider),
                );
                final url = await showDialog<String>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Server address'),
                    content: TextField(
                      controller: controller,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        hintText: 'http://192.168.1.10:8080',
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(controller.text),
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                );
                if (url != null &&
                    Uri.tryParse(url.trim())?.hasAuthority == true) {
                  await ref.read(serverUrlProvider.notifier).set(url);
                  await ref.read(onlineProvider.notifier).disconnect();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: const Text('How to play'),
              subtitle: const Text('Rules and hand rankings'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/rules'),
            ),
            const ListTile(title: Text('Language'), trailing: Text('English')),
            const ListTile(
              title: Text('Account'),
              trailing: Icon(Icons.chevron_right),
            ),
            const ListTile(
              title: Text('Privacy'),
              trailing: Icon(Icons.chevron_right),
            ),
          ],
          step: const Duration(milliseconds: 45),
          offset: const Offset(24, 0),
        ),
      ),
    );
  }
}
