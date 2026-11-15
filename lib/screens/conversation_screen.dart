import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/icon_fonts/app_icons.dart';
import '../core/theme/app_theme.dart';
import '../models/conversation.dart';
import '../providers/app_providers.dart';
import '../services/session_service.dart';
import '../widgets/composer.dart';
import '../widgets/event_bubble.dart';
import '../widgets/pane_header.dart';
import '../widgets/status_chip.dart';
import '../widgets/typing_dots.dart';

/// A live conversation.
///
/// Opening this screen starts a *global* session: the socket is owned by
/// [SessionService], not by this widget, so leaving the screen never stops the
/// agent, and the transcript is read from cache rather than refetched.
class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({
    super.key,
    required this.conversation,
    this.onBack,
  });

  final CloudConversation conversation;

  /// When embedded in the wide layout there is no route to pop, so the shell
  /// supplies its own back handling.
  final VoidCallback? onBack;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _scrollController = ScrollController();
  bool _loadingOlder = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final service = ref.read(sessionServiceProvider);
      service.open(widget.conversation);
      service.markRead(widget.conversation.id);
    });
  }

  @override
  void dispose() {
    // The session is intentionally NOT closed here: the agent keeps running
    // and the socket keeps streaming while the user is elsewhere in the app.
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder) return;
    setState(() => _loadingOlder = true);
    try {
      await ref
          .read(sessionServiceProvider)
          .loadOlder(widget.conversation.id);
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  void _send(String text) {
    ref.read(sessionServiceProvider).sendMessage(widget.conversation.id, text);
  }

  @override
  Widget build(BuildContext context) {
    final live = ref.watch(sessionStateProvider(widget.conversation.id));
    final state =
        live.value ?? ref.read(sessionServiceProvider).stateOf(widget.conversation.id);

    return Column(
      children: [
        _Header(conversation: widget.conversation, state: state, onBack: widget.onBack),
        Expanded(
          child: _Transcript(
            state: state,
            controller: _scrollController,
            onLoadOlder: _loadOlder,
            loadingOlder: _loadingOlder,
            onRetry: () => ref
                .read(sessionServiceProvider)
                .retryPending(widget.conversation.id),
          ),
        ),
        if (state.error != null)
          _ErrorBanner(
            message: state.error!,
            onRetry: () => ref
                .read(sessionServiceProvider)
                .retryPending(widget.conversation.id),
          ),
        Composer(
          onSend: _send,
          onStop: () =>
              ref.read(sessionServiceProvider).interrupt(widget.conversation.id),
          busy: state.isBusy,
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.conversation,
    required this.state,
    required this.onBack,
  });

  final CloudConversation conversation;
  final SessionState state;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PaneHeader(
      onMenu: onBack,
      title: Text(
        state.title.isEmpty ? conversation.title : state.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Row(
        children: [
          StatusChip(
            state: state.agentState,
            connected: state.connected,
            compact: true,
          ),
          if (conversation.llmModel != null) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                conversation.llmModel!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Transcript extends StatelessWidget {
  const _Transcript({
    required this.state,
    required this.controller,
    required this.onLoadOlder,
    required this.loadingOlder,
    required this.onRetry,
  });

  final SessionState state;
  final ScrollController controller;
  final Future<void> Function() onLoadOlder;
  final bool loadingOlder;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    if (state.loadingHistory && state.events.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }
    if (state.events.isEmpty && state.pending.isEmpty) {
      return const _EmptyConversation();
    }

    // The list is reversed so the newest turn sits at the bottom and stays
    // pinned while new events stream in, without any manual scrolling.
    final children = <Widget>[
      if (state.isBusy) const _TypingRow(),
      for (final message in state.pending.reversed)
        _PendingBubble(message: message, onRetry: onRetry),
      for (final event in state.events.reversed)
        EventBubble(event: event, animateIn: false),
      if (loadingOlder) const _OlderSpinner(),
    ];

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        final metrics = notification.metrics;
        if (metrics.pixels >= metrics.maxScrollExtent - 120) {
          onLoadOlder();
        }
        return false;
      },
      child: ListView.builder(
        controller: controller,
        reverse: true,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        itemCount: children.length,
        itemBuilder: (context, index) => children[index],
      ),
    );
  }
}

class _TypingRow extends StatelessWidget {
  const _TypingRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(9),
            ),
            alignment: Alignment.center,
            child: const Icon(
              AppIcons.flash,
              size: 15,
              color: AppColors.accentBright,
            ),
          ),
          const SizedBox(width: 12),
          const TypingDots(),
        ],
      ),
    );
  }
}

class _OlderSpinner extends StatelessWidget {
  const _OlderSpinner();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _PendingBubble extends StatelessWidget {
  const _PendingBubble({required this.message, required this.onRetry});

  final PendingMessage message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final failed = message.status == PendingStatus.failed;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Opacity(
            opacity: failed ? 1 : 0.65,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: failed
                        ? Theme.of(context).colorScheme.errorContainer
                        : AppColors.accent.withValues(alpha: 0.5),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(AppRadius.lg),
                      topRight: Radius.circular(AppRadius.lg),
                      bottomLeft: Radius.circular(AppRadius.lg),
                      bottomRight: Radius.circular(6),
                    ),
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: failed
                          ? Theme.of(context).colorScheme.onErrorContainer
                          : Colors.white,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      switch (message.status) {
                        PendingStatus.queued => 'Queued',
                        PendingStatus.sending => 'Sending…',
                        PendingStatus.failed => 'Not sent',
                      },
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    if (failed) ...[
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(AppIcons.refresh, size: 13),
                        label: const Text('Retry'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                gradient: AppColors.accentGradient,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(AppIcons.flash, size: 26, color: Colors.white),
            ),
            const SizedBox(height: 18),
            Text('Ready when you are', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Send the first message to kick the agent off.',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: theme.colorScheme.errorContainer,
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
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
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.colorScheme.onErrorContainer,
                fontSize: 13,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.onErrorContainer,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
