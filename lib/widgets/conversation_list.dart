import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shimmer/shimmer.dart';

import '../core/icon_fonts/app_icons.dart';
import '../core/theme/app_theme.dart';
import '../models/agent_state.dart';
import '../models/conversation.dart';
import '../providers/app_providers.dart';
import 'status_chip.dart';

/// The conversation browser: a drawer on phones, a permanent sidebar on wide
/// screens.
class ConversationList extends ConsumerWidget {
  const ConversationList({
    super.key,
    required this.activeId,
    required this.onOpen,
    required this.onNew,
  });

  final String? activeId;
  final void Function(CloudConversation conversation) onOpen;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(visibleConversationsProvider);
    final query = ref.watch(conversationQueryProvider).toLowerCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SidebarHeader(onNew: onNew),
        _SearchField(
          onChanged: (value) =>
              ref.read(conversationQueryProvider.notifier).set(value),
        ),
        Expanded(
          child: conversations.when(
            loading: () => const _ListSkeleton(),
            error: (error, _) => _ListError(
              message: '$error',
              onRetry: () => ref.read(conversationsProvider.notifier).refresh(),
            ),
            data: (items) {
              final filtered = query.isEmpty
                  ? items
                  : items
                        .where(
                          (c) =>
                              c.title.toLowerCase().contains(query) ||
                              (c.llmModel ?? '').toLowerCase().contains(query),
                        )
                        .toList();
              if (filtered.isEmpty) {
                return _EmptyState(
                  hasQuery: query.isNotEmpty,
                  onNew: onNew,
                  onClear: () =>
                      ref.read(conversationQueryProvider.notifier).set(''),
                );
              }
              return RefreshIndicator(
                onRefresh: () =>
                    ref.read(conversationsProvider.notifier).refresh(),
                child: _GroupedList(
                  conversations: filtered,
                  activeId: activeId,
                  onOpen: onOpen,
                ),
              );
            },
          ),
        ),
        const _SidebarFooter(),
      ],
    );
  }
}

class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader({required this.onNew});

  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              gradient: AppColors.accentGradient,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(AppIcons.flash, size: 17, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Handoff',
              style: theme.textTheme.titleLarge?.copyWith(fontSize: 18),
            ),
          ),
          IconButton(
            tooltip: 'New conversation',
            onPressed: onNew,
            icon: const Icon(AppIcons.add),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatefulWidget {
  const _SearchField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: TextField(
        controller: _controller,
        onChanged: (value) {
          widget.onChanged(value);
          setState(() {});
        },
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search conversations',
          isDense: true,
          prefixIcon: const Icon(AppIcons.search, size: 17),
          prefixIconConstraints: const BoxConstraints(minWidth: 40),
          suffixIcon: _controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(AppIcons.close, size: 15),
                  onPressed: () {
                    _controller.clear();
                    widget.onChanged('');
                    setState(() {});
                  },
                ),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: _border(),
          enabledBorder: _border(),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            borderSide: const BorderSide(color: AppColors.accent, width: 1.2),
          ),
        ),
      ),
    );
  }

  OutlineInputBorder _border() => OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.pill),
    borderSide: BorderSide.none,
  );
}

class _GroupedList extends StatelessWidget {
  const _GroupedList({
    required this.conversations,
    required this.activeId,
    required this.onOpen,
  });

  final List<CloudConversation> conversations;
  final String? activeId;
  final void Function(CloudConversation conversation) onOpen;

  @override
  Widget build(BuildContext context) {
    final groups = _group(conversations);
    final children = <Widget>[];
    var index = 0;
    for (final entry in groups.entries) {
      children.add(_SectionLabel(entry.key));
      for (final conversation in entry.value) {
        children.add(
          _ConversationRow(
            key: ValueKey(conversation.id),
            conversation: conversation,
            selected: conversation.id == activeId,
            onTap: () => onOpen(conversation),
          ).animate().fadeIn(
            duration: 220.ms,
            delay: Duration(milliseconds: (index * 18).clamp(0, 240)),
          ),
        );
        index++;
      }
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
      children: children,
    );
  }

  Map<String, List<CloudConversation>> _group(List<CloudConversation> items) {
    final sorted = [...items]
      ..sort((a, b) {
        final aDate = a.updatedAt ?? a.createdAt ?? DateTime(1970);
        final bDate = b.updatedAt ?? b.createdAt ?? DateTime(1970);
        return bDate.compareTo(aDate);
      });
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final groups = <String, List<CloudConversation>>{};
    for (final item in sorted) {
      final local = (item.updatedAt ?? item.createdAt)?.toLocal();
      String label;
      if (local == null) {
        label = 'Older';
      } else {
        final day = DateTime(local.year, local.month, local.day);
        final diff = today.difference(day).inDays;
        if (diff <= 0) {
          label = 'Today';
        } else if (diff == 1) {
          label = 'Yesterday';
        } else if (diff < 7) {
          label = 'Previous 7 days';
        } else if (diff < 30) {
          label = 'Previous 30 days';
        } else {
          label = DateFormat.yMMMM().format(local);
        }
      }
      groups.putIfAbsent(label, () => []).add(item);
    }
    return groups;
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 6),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

class _ConversationRow extends ConsumerWidget {
  const _ConversationRow({
    super.key,
    required this.conversation,
    required this.selected,
    required this.onTap,
  });

  final CloudConversation conversation;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final live = ref.watch(sessionStateProvider(conversation.id));
    final state =
        live.value ?? ref.read(sessionServiceProvider).stateOf(conversation.id);
    final unread = state.unreadCount;
    final updated =
        (conversation.updatedAt ?? conversation.createdAt)?.toLocal();

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.55)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                StatusIndicator(
                  state: state.agentState,
                  connected: state.connected,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        conversation.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selected
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _subtitle(state.agentState, updated),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (unread > 0)
                  _UnreadBadge(count: unread)
                else
                  _RowMenu(conversation: conversation),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _subtitle(AgentState state, DateTime? updated) {
    if (updated == null) return state.label;
    return '${state.label} · ${_relative(updated)}';
  }

  static String _relative(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat.MMMd().format(date);
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        gradient: AppColors.accentGradient,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RowMenu extends ConsumerWidget {
  const _RowMenu({required this.conversation});

  final CloudConversation conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: 'More',
      icon: const Icon(AppIcons.more, size: 16),
      padding: EdgeInsets.zero,
      onSelected: (value) {
        if (value == 'delete') {
          _delete(context, ref);
        } else if (value == 'hide') {
          ref.read(hiddenConversationsProvider.notifier).hide(conversation.id);
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'hide',
          child: ListTile(
            dense: true,
            leading: Icon(AppIcons.eyeSlash, size: 18),
            title: Text('Hide from list'),
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: ListTile(
            dense: true,
            leading: Icon(AppIcons.trash, size: 18),
            title: Text('Delete'),
          ),
        ),
      ],
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete conversation?'),
        content: Text(
          '"${conversation.title}" will be removed, along with its local '
          'transcript. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    var deletedOnServer = true;
    try {
      await ref.read(cloudApiProvider).deleteConversation(conversation.id);
    } catch (_) {
      // Deployments without a delete route: drop it locally so the list still
      // reflects the user's intent.
      deletedOnServer = false;
      await ref
          .read(hiddenConversationsProvider.notifier)
          .hide(conversation.id);
    }
    await ref.read(sessionServiceProvider).close(conversation.id, forget: true);
    await ref.read(conversationsProvider.notifier).refresh();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          deletedOnServer
              ? 'Conversation deleted.'
              : 'Server refused the delete; hidden on this device.',
        ),
      ),
    );
  }
}

/// A small status ring: filled when live, ringed while reconnecting.
class StatusIndicator extends StatelessWidget {
  const StatusIndicator({
    super.key,
    required this.state,
    required this.connected,
    this.size = 9,
  });

  final AgentState state;
  final bool connected;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = StatusChip.colorFor(state);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: connected ? color : Colors.transparent,
        border: Border.all(color: color, width: 1.6),
      ),
    );
  }
}

class _SidebarFooter extends ConsumerWidget {
  const _SidebarFooter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 6, 10),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(AppIcons.user, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Signed in', style: theme.textTheme.titleSmall),
                Text(
                  'OpenHands Cloud',
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: isDark ? 'Light theme' : 'Dark theme',
            onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
            icon: Icon(isDark ? AppIcons.sun : AppIcons.moon, size: 18),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => ref.read(authProvider.notifier).signOut(),
            icon: const Icon(AppIcons.logout, size: 18),
          ),
        ],
      ),
    );
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: base.withValues(alpha: 0.4),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        children: List.generate(
          8,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: base,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 11, color: base),
                      const SizedBox(height: 7),
                      FractionallySizedBox(
                        widthFactor: 0.55,
                        child: Container(height: 9, color: base),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ListError extends StatelessWidget {
  const _ListError({required this.message, required this.onRetry});

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
            const Icon(AppIcons.danger, size: 34, color: AppColors.danger),
            const SizedBox(height: 12),
            Text(
              'Could not load conversations',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(AppIcons.refresh, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.hasQuery,
    required this.onNew,
    required this.onClear,
  });

  final bool hasQuery;
  final VoidCallback onNew;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasQuery ? AppIcons.search : AppIcons.message,
              size: 40,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 14),
            Text(
              hasQuery ? 'No matches' : 'No conversations yet',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              hasQuery
                  ? 'Try another search term.'
                  : 'Start a task and it will show up here.',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: hasQuery ? onClear : onNew,
              icon: Icon(hasQuery ? AppIcons.close : AppIcons.add, size: 16),
              label: Text(hasQuery ? 'Clear search' : 'New conversation'),
            ),
          ],
        ),
      ),
    );
  }
}
