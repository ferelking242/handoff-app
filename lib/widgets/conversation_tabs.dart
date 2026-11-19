import 'package:material_ui/material_ui.dart';

import '../core/icon_fonts/app_icons.dart';
import '../core/theme/app_theme.dart';
import '../models/conversation.dart';

/// A compact, horizontally scrollable strip of open chat tabs.
class ConversationTabs extends StatelessWidget {
  const ConversationTabs({
    super.key,
    required this.conversations,
    required this.activeConversationId,
    required this.newConversationOpen,
    required this.scrollController,
    required this.onSelectConversation,
    required this.onSelectNewConversation,
    required this.onCloseConversation,
    required this.onCloseNewConversation,
    required this.onNewConversation,
  });

  final List<CloudConversation> conversations;
  final String? activeConversationId;
  final bool newConversationOpen;
  final ScrollController scrollController;
  final ValueChanged<CloudConversation> onSelectConversation;
  final VoidCallback onSelectNewConversation;
  final ValueChanged<String> onCloseConversation;
  final VoidCallback onCloseNewConversation;
  final VoidCallback onNewConversation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (newConversationOpen)
                    _ConversationTab(
                      title: 'New task',
                      selected: activeConversationId == null,
                      icon: AppIcons.messageAdd,
                      onSelect: onSelectNewConversation,
                      onClose: onCloseNewConversation,
                    ),
                  for (final conversation in conversations)
                    _ConversationTab(
                      key: ValueKey(conversation.id),
                      title: conversation.title,
                      selected: conversation.id == activeConversationId,
                      icon: AppIcons.message,
                      onSelect: () => onSelectConversation(conversation),
                      onClose: () => onCloseConversation(conversation.id),
                    ),
                ],
              ),
            ),
          ),
          Container(
            width: 1,
            height: 24,
            color: theme.colorScheme.outlineVariant,
          ),
          SizedBox(
            width: 46,
            child: IconButton(
              tooltip: 'New chat',
              onPressed: onNewConversation,
              padding: EdgeInsets.zero,
              icon: const Icon(AppIcons.add, size: 19),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationTab extends StatelessWidget {
  const _ConversationTab({
    super.key,
    required this.title,
    required this.selected,
    required this.icon,
    required this.onSelect,
    required this.onClose,
  });

  final String title;
  final bool selected;
  final IconData icon;
  final VoidCallback onSelect;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedColor = theme.colorScheme.primary;
    return SizedBox(
      width: 176,
      height: 46,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Material(
                    color: selected
                        ? theme.colorScheme.surfaceContainerHighest
                        : Colors.transparent,
                    child: InkWell(
                      onTap: onSelect,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 12, right: 4),
                        child: Row(
                          children: [
                            Icon(
                              icon,
                              size: 15,
                              color: selected
                                  ? selectedColor
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: selected
                                      ? theme.colorScheme.onSurface
                                      : theme.colorScheme.onSurfaceVariant,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close tab $title',
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 36,
                    height: 42,
                  ),
                  icon: Icon(
                    AppIcons.close,
                    size: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 2,
            color: selected ? selectedColor : Colors.transparent,
          ),
        ],
      ),
    );
  }
}
