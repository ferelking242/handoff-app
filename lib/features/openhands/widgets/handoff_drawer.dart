import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../icons/broken_icons.dart';
import '../../../theme/app_font_weights.dart';
import '../models/openhands_models.dart';
import '../providers/openhands_provider.dart';
import 'handoff_logo.dart';

/// Left navigation: account, conversations, Guard and settings.
class HandoffDrawer extends StatelessWidget {
  const HandoffDrawer({
    super.key,
    required this.provider,
    required this.onSelectConversation,
    required this.onNewConversation,
    required this.onOpenSettings,
    required this.onOpenGuard,
    required this.onOpenAccount,
  });

  final OpenHandsProvider provider;
  final ValueChanged<OpenHandsConversation> onSelectConversation;
  final VoidCallback onNewConversation;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenGuard;
  final VoidCallback onOpenAccount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = provider.user;

    return Drawer(
      width: MediaQuery.sizeOf(context).width * 0.86,
      backgroundColor: scheme.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 14, 8),
              child: Row(
                children: [
                  const HandoffLogo(size: 34, radius: 10),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Handoff',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: AppFontWeights.heavy,
                            letterSpacing: -0.4,
                            color: scheme.onSurface,
                          ),
                        ),
                        Text(
                          'OpenHands client',
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: provider.conversationsLoading
                        ? null
                        : provider.refreshConversations,
                    icon: const Icon(Broken.refresh, size: 19),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
              child: InkWell(
                onTap: onOpenAccount,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.45,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: scheme.primary.withValues(alpha: 0.16),
                        child: Text(
                          user?.initial ?? 'O',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: AppFontWeights.semibold,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.displayName ?? 'OpenHands user',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: AppFontWeights.semibold,
                                color: scheme.onSurface,
                              ),
                            ),
                            Text(
                              user?.email ?? 'Not signed in',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Broken.arrow_right_2,
                        size: 16,
                        color: scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: FilledButton.icon(
                onPressed: provider.creating ? null : onNewConversation,
                icon: provider.creating
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: scheme.onPrimary,
                        ),
                      )
                    : const Icon(Broken.add, size: 18),
                label: Text(provider.creating ? 'Starting…' : 'New conversation'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 6),
              child: Row(
                children: [
                  Text(
                    'CONVERSATIONS',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.2,
                      fontWeight: AppFontWeights.semibold,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  if (provider.conversations.isNotEmpty)
                    Text(
                      '${provider.conversations.length}',
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(child: _ConversationList(provider: provider, onSelect: onSelectConversation)),
            _DrawerFooter(
              provider: provider,
              onOpenAccount: onOpenAccount,
              onOpenGuard: onOpenGuard,
              onOpenSettings: onOpenSettings,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationList extends StatelessWidget {
  const _ConversationList({required this.provider, required this.onSelect});

  final OpenHandsProvider provider;
  final ValueChanged<OpenHandsConversation> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (provider.conversationsLoading && provider.conversations.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.conversationsError != null &&
        provider.conversations.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Broken.warning_2, size: 28, color: scheme.error),
            const SizedBox(height: 8),
            Text(
              provider.conversationsError!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: provider.refreshConversations,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (provider.conversations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Broken.message,
                size: 30,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 10),
              Text(
                'No conversations yet',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: AppFontWeights.medium,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: provider.refreshConversations,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        itemCount: provider.conversations.length + (provider.hasMoreConversations ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= provider.conversations.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: TextButton(
                  onPressed: provider.conversationsLoading
                      ? null
                      : provider.loadMoreConversations,
                  child: Text(
                    provider.conversationsLoading ? 'Loading…' : 'Load more',
                  ),
                ),
              ),
            );
          }
          final conversation = provider.conversations[index];
          return _ConversationTile(
            conversation: conversation,
            selected: provider.active?.id == conversation.id,
            onTap: () => onSelect(conversation),
          );
        },
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.selected,
    required this.onTap,
  });

  final OpenHandsConversation conversation;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtitle = conversation.subtitle;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected
            ? scheme.primary.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: _StatusDot(
                    running: conversation.isRunning,
                    paused: conversation.isPaused,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              conversation.displayTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: selected
                                    ? AppFontWeights.semibold
                                    : AppFontWeights.medium,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _relative(conversation.updatedAt),
                            style: TextStyle(
                              fontSize: 10,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
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

  String _relative(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat.MMMd().format(time);
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.running, required this.paused});

  final bool running;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = running
        ? scheme.primary
        : paused
            ? scheme.tertiary
            : scheme.onSurfaceVariant.withValues(alpha: 0.45);
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _DrawerFooter extends StatelessWidget {
  const _DrawerFooter({
    required this.provider,
    required this.onOpenAccount,
    required this.onOpenGuard,
    required this.onOpenSettings,
  });

  final OpenHandsProvider provider;
  final VoidCallback onOpenAccount;
  final VoidCallback onOpenGuard;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = provider.user;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onOpenAccount,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: scheme.primary.withValues(alpha: 0.16),
                      child: Text(
                        user?.initial ?? 'O',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: AppFontWeights.semibold,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        user?.displayName ?? 'Account',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: AppFontWeights.medium,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'OpenHands Guard',
            onPressed: onOpenGuard,
            icon: Icon(
              Broken.shield_tick,
              size: 21,
              color: provider.guard.isConfigured
                  ? scheme.primary
                  : scheme.onSurfaceVariant,
            ),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: onOpenSettings,
            icon: Icon(
              Broken.setting_2,
              size: 21,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
