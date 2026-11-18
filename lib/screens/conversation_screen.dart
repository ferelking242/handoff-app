import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

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
    this.onMenu,
  });

  final CloudConversation conversation;

  /// Opens the conversation drawer on mobile. Wide layouts use the sidebar.
  final VoidCallback? onMenu;

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

    // The header floats over the transcript rather than sitting above it, so
    // messages scroll beneath the transparent header. The list gets top
    // padding equal to the header so its first event starts below the title.
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
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
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _Header(
                  conversation: widget.conversation,
                  state: state,
                  onMenu: widget.onMenu,
                ),
              ),
            ],
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
    required this.onMenu,
  });

  final CloudConversation conversation;
  final SessionState state;
  final VoidCallback? onMenu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PaneHeader(
      onMenu: onMenu,
      avatar: _AgentMark(state: state),
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

/// The round bot mark before the title, tinted by the agent's live state.
class _AgentMark extends StatelessWidget {
  const _AgentMark({required this.state});

  final SessionState state;

  @override
  Widget build(BuildContext context) {
    final color = StatusChip.colorFor(state.agentState);
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(LucideIcons.bot, size: 17, color: color),
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
      return const SizedBox.expand();
    }

    // The list is reversed so the newest turn sits at the bottom and stays
    // pinned while new events stream in, without any manual scrolling.
    final children = <Widget>[
      if (state.isBusy) const _TypingRow(),
      for (final message in state.pending.reversed)
        _PendingBubble(message: message, onRetry: onRetry),
      for (final event in state.events.reversed)
        EventBubble(
          key: ValueKey('event-${event.id}'),
          event: event,
          animateIn:
              state.events.isNotEmpty && event.id == state.events.last.id,
        ),
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
        // The top inset clears the floating header so the oldest message is
        // never trapped underneath it.
        padding: EdgeInsets.fromLTRB(
          12,
          PaneHeader.barHeight + MediaQuery.paddingOf(context).top + 8,
          12,
          8,
        ),
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
              LucideIcons.bot,
              size: 16,
              color: AppColors.accentBright,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Working',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
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
                        : AppColors.surfaceHigher,
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
                        icon: const Icon(LucideIcons.rotateCw, size: 13),
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
            LucideIcons.circleAlert,
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
