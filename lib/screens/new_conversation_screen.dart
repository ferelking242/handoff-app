import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/icon_fonts/app_icons.dart';
import '../core/theme/app_theme.dart';
import '../models/conversation.dart';
import '../providers/app_providers.dart';
import '../widgets/composer.dart';
import '../widgets/pane_header.dart';

/// Starts a new conversation from a first prompt.
class NewConversationScreen extends ConsumerStatefulWidget {
  const NewConversationScreen({super.key, this.onOpen});

  /// Called with the created conversation. The wide layout swaps panes in
  /// place; on phones it pushes the conversation route.
  final void Function(CloudConversation conversation)? onOpen;

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
          leading: widget.onOpen == null
              ? IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(AppIcons.arrowLeft),
                  tooltip: 'Back',
                )
              : null,
          title: const Text('New conversation'),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            gradient: AppColors.accentGradient,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            AppIcons.flash,
                            size: 19,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Describe the task',
                            style: theme.textTheme.titleLarge,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    if (_busy)
                      const _StartingCard()
                    else
                      _PromptCard(onSend: _create, enabled: !_busy),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              AppIcons.danger,
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
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PromptCard extends StatefulWidget {
  const _PromptCard({required this.onSend, required this.enabled});

  final void Function(String text) onSend;
  final bool enabled;

  @override
  State<_PromptCard> createState() => _PromptCardState();
}

class _PromptCardState extends State<_PromptCard> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          autofocus: true,
          minLines: 5,
          maxLines: 12,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText:
                'e.g. Fix the failing test in auth_test.dart and open a PR.',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 14),
        Composer(
          onSend: widget.onSend,
          onStop: () {},
          enabled: widget.enabled,
          hintText: 'Start with a message…',
        ),
      ],
    );
  }
}

class _StartingCard extends StatelessWidget {
  const _StartingCard();

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
