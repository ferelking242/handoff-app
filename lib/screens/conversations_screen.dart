import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/conversation.dart';
import '../providers/app_providers.dart';
import '../services/session_service.dart';
import 'conversation_screen.dart';
import 'new_conversation_screen.dart';

/// The account's conversations. Opening one starts a global session and
/// immediately connects its socket, so the agent keeps streaming while the
/// user moves around the app.
class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(conversationsProvider);
    final sessionService = ref.watch(sessionServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Handoff'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () =>
                ref.read(conversationsProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => ref.read(authProvider.notifier).signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const NewConversationScreen(),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New task'),
      ),
      body: conversations.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorView(
          message: '$error',
          onRetry: () => ref.read(conversationsProvider.notifier).refresh(),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const _EmptyView();
          }
          return RefreshIndicator(
            onRefresh: () =>
                ref.read(conversationsProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) => _ConversationTile(
                conversation: items[index],
                sessionService: sessionService,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  const _ConversationTile({
    required this.conversation,
    required this.sessionService,
  });

  final CloudConversation conversation;
  final SessionService sessionService;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(sessionStateProvider(conversation.id));
    final state = live.value ?? sessionService.stateOf(conversation.id);
    final updated = conversation.updatedAt;
    final theme = Theme.of(context);

    return ListTile(
      leading: _StatusDot(connected: state.connected, hasError: state.error != null),
      title: Text(
        conversation.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Row(
        children: [
          Text(state.agentState.label),
          if (updated != null) ...[
            const Text('  ·  '),
            Text(DateFormat.MMMd().add_Hm().format(updated.toLocal())),
          ],
        ],
      ),
      trailing: state.unreadCount > 0
          ? Badge(label: Text('${state.unreadCount}'))
          : const Icon(Icons.chevron_right),
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ConversationScreen(conversation: conversation),
          ),
        );
      },
      titleTextStyle: theme.textTheme.titleMedium,
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.connected, required this.hasError});

  final bool connected;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final color = hasError
        ? Theme.of(context).colorScheme.error
        : connected
        ? Colors.green
        : Colors.grey;
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.forum_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          const Text('No conversations yet'),
          const SizedBox(height: 4),
          const Text('Tap "New task" to start one.'),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
