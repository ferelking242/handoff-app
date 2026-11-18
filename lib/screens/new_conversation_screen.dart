import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../core/theme/app_theme.dart';
import '../models/conversation.dart';
import '../providers/app_providers.dart';
import '../widgets/composer.dart';
import '../widgets/pane_header.dart';

/// Starts a new conversation from a first prompt.
class NewConversationScreen extends ConsumerStatefulWidget {
  const NewConversationScreen({super.key, this.onOpen, this.onMenu});

  /// Called with the created conversation so the home shell can show it.
  final void Function(CloudConversation conversation)? onOpen;
  final VoidCallback? onMenu;

  @override
  ConsumerState<NewConversationScreen> createState() =>
      _NewConversationScreenState();
}

class _NewConversationScreenState extends ConsumerState<NewConversationScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _create(String text) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final conversation = await ref
          .read(cloudApiProvider)
          .createConversation(initialMessage: text);
      if (!mounted) return;
      await ref.read(conversationsProvider.notifier).refresh();
      if (!mounted) return;
      if (widget.onOpen != null) {
        widget.onOpen!(conversation);
      } else {
        Navigator.of(context).pop(conversation);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        PaneHeader(
          onMenu: widget.onMenu,
          leading: widget.onOpen == null && widget.onMenu == null
              ? IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(LucideIcons.arrowLeft),
                  tooltip: 'Back',
                )
              : null,
          title: const Text('New Chat'),
          subtitle: Text(
            'OpenHands Cloud',
            style: theme.textTheme.labelSmall,
          ),
        ),
        Expanded(
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _busy
                  ? const _StartingCard(key: ValueKey('starting'))
                  : const SizedBox.shrink(key: ValueKey('empty-chat')),
            ),
          ),
        ),
        if (_error != null)
          Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                Icon(
                  LucideIcons.circleAlert,
                  size: 16,
                  color: theme.colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: theme.colorScheme.onErrorContainer,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Composer(
          onSend: _create,
          enabled: !_busy,
          hintText: 'Describe a task for the agent…',
        ),
      ],
    );
  }
}

class _StartingCard extends StatelessWidget {
  const _StartingCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(strokeWidth: 2.5),
          const SizedBox(height: 16),
          Text('Starting your conversation…', style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(
            'Handoff is provisioning the sandbox. This usually takes a few '
            'seconds.',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ).animate().fadeIn(duration: 240.ms),
    );
  }
}
