import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../icons/broken_icons.dart';
import '../../../shared/markdown/markdown_with_code_highlight.dart';
import '../../../theme/app_font_weights.dart';
import '../models/openhands_models.dart';
import '../providers/openhands_provider.dart';
import '../widgets/handoff_logo.dart';

/// The chat surface for one OpenHands conversation.
class OpenHandsConversationView extends StatefulWidget {
  const OpenHandsConversationView({super.key});

  @override
  State<OpenHandsConversationView> createState() =>
      _OpenHandsConversationViewState();
}

class _OpenHandsConversationViewState
    extends State<OpenHandsConversationView> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _composer = TextEditingController();
  final FocusNode _composerFocus = FocusNode();
  int _lastItemCount = 0;
  bool _atBottom = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _composer.dispose();
    _composerFocus.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    _atBottom = position.pixels >= position.maxScrollExtent - 80;
  }

  void _scrollToBottom({bool animate = true}) {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent;
    if (animate) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(target);
    }
  }

  Future<void> _send() async {
    final text = _composer.text;
    if (text.trim().isEmpty) return;
    final provider = context.read<OpenHandsProvider>();
    final sent = await provider.sendMessage(text);
    if (sent) {
      _composer.clear();
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OpenHandsProvider>();
    final timeline = provider.timeline;
    final scheme = Theme.of(context).colorScheme;

    if (timeline.length != _lastItemCount) {
      final grew = timeline.length > _lastItemCount;
      _lastItemCount = timeline.length;
      if (grew && _atBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    }

    if (provider.timelineLoading && timeline.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (timeline.isEmpty && provider.timelineError != null) {
      return _ConversationError(
        message: provider.timelineError!,
        onRetry: provider.refreshTimeline,
      );
    }

    return Column(
      children: [
        Expanded(
          child: timeline.isEmpty
              ? _EmptyConversation(provider: provider)
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  itemCount: timeline.length,
                  itemBuilder: (context, index) {
                    final item = timeline[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _TimelineRow(item: item),
                    );
                  },
                ),
        ),
        if (provider.agentRunning)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Agent is working…',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(),
        if (provider.timelineError != null && timeline.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Text(
              provider.timelineError!,
              style: TextStyle(fontSize: 12, color: scheme.error),
            ),
          ),
        _Composer(
          controller: _composer,
          focusNode: _composerFocus,
          busy: provider.sending,
          running: provider.agentRunning,
          onSend: _send,
          onStop: provider.stopAgent,
        ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.item});

  final HandoffTimelineItem item;

  @override
  Widget build(BuildContext context) {
    switch (item.kind) {
      case HandoffItemKind.user:
        return _UserBubble(item: item);
      case HandoffItemKind.assistant:
        return _AssistantBubble(item: item);
      case HandoffItemKind.action:
        return _ToolCard(item: item);
      case HandoffItemKind.error:
        return _ErrorRow(item: item);
      case HandoffItemKind.notice:
        return _NoticeRow(item: item);
    }
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.item});

  final HandoffTimelineItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(6),
          ),
        ),
        child: SelectableText(
          item.text,
          style: TextStyle(
            fontSize: 15,
            height: 1.4,
            color: scheme.onPrimary,
          ),
        ),
      ),
    ).animate().fadeIn(duration: 180.ms).slideY(begin: 0.04, end: 0);
  }
}

class _AssistantBubble extends StatelessWidget {
  const _AssistantBubble({required this.item});

  final HandoffTimelineItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const HandoffLogo(size: 28, radius: 9),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: MarkdownWithCodeHighlight(
              text: item.text,
              baseStyle: TextStyle(
                fontSize: 15,
                height: 1.45,
                color: scheme.onSurface,
              ),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.03, end: 0);
  }
}

class _ToolCard extends StatefulWidget {
  const _ToolCard({required this.item});

  final HandoffTimelineItem item;

  @override
  State<_ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<_ToolCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final item = widget.item;
    final detail = item.text.trim();
    final isLong = detail.split('\n').length > 6 || detail.length > 420;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.45)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          leading: _toolIcon(item.toolName ?? '', scheme),
          title: Text(
            item.title ?? 'Tool',
            style: TextStyle(
              fontSize: 13,
              fontWeight: AppFontWeights.semibold,
              color: scheme.onSurface,
            ),
          ),
          subtitle: detail.isEmpty
              ? null
              : Text(
                  detail.split('\n').first,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: scheme.onSurfaceVariant,
                  ),
                ),
          trailing: item.running
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: scheme.primary,
                  ),
                )
              : Icon(
                  _expanded ? Broken.arrow_up_2 : Broken.arrow_down_2,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
          onExpansionChanged: (value) => setState(() => _expanded = value),
          children: [
            if (detail.isEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  item.running ? 'Running…' : 'No output',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  detail,
                  maxLines: _expanded || !isLong ? null : 6,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    fontFamily: 'monospace',
                    color: scheme.onSurface,
                  ),
                ),
              ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 160.ms);
  }

  Widget _toolIcon(String tool, ColorScheme scheme) {
    final IconData icon;
    switch (tool.toLowerCase()) {
      case 'terminal':
        icon = Broken.code;
      case 'file_editor':
        icon = Broken.document_text;
      case 'browse':
      case 'browser':
        icon = Broken.global;
      case 'task_tracker':
        icon = Broken.task_square;
      case 'think':
        icon = Broken.magic_star;
      case 'finish':
        icon = Broken.tick_circle;
      default:
        icon = Broken.setting_2;
    }
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 17, color: scheme.primary),
    );
  }
}

class _ErrorRow extends StatelessWidget {
  const _ErrorRow({required this.item});

  final HandoffTimelineItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Broken.warning_2, size: 18, color: scheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: SelectableText(
              item.text,
              style: TextStyle(fontSize: 13, color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeRow extends StatelessWidget {
  const _NoticeRow({required this.item});

  final HandoffTimelineItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          item.text,
          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation({required this.provider});

  final OpenHandsProvider provider;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final suggestions = [
      'What are you working on?',
      'Summarize this conversation',
      'List the files in the workspace',
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const SizedBox(height: 40),
          const HandoffLogo(size: 64, radius: 20),
          const SizedBox(height: 18),
          Text(
            provider.active?.displayTitle ?? 'New conversation',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: AppFontWeights.semibold,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Send the first message to wake the agent.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          ...suggestions.map(
            (text) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ActionChip(
                label: Text(text),
                onPressed: () => provider.sendMessage(text),
                avatar: const Icon(Broken.flash, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationError extends StatelessWidget {
  const _ConversationError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Broken.warning_2, size: 36, color: scheme.error),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.busy,
    required this.running,
    required this.onSend,
    required this.onStop,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool busy;
  final bool running;
  final Future<void> Function() onSend;
  final Future<void> Function() onStop;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  minLines: 1,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(fontSize: 15, color: scheme.onSurface),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Message the agent…',
                    hintStyle: TextStyle(color: scheme.onSurfaceVariant),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onSubmitted: (_) => onSend(),
                ),
              ),
              const SizedBox(width: 6),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: running
                    ? _RoundButton(
                        key: const ValueKey('stop'),
                        icon: Broken.stop,
                        background: scheme.errorContainer,
                        foreground: scheme.onErrorContainer,
                        onTap: onStop,
                      )
                    : _RoundButton(
                        key: const ValueKey('send'),
                        icon: Broken.send,
                        background: scheme.primary,
                        foreground: scheme.onPrimary,
                        onTap: busy ? null : onSend,
                        busy: busy,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    super.key,
    required this.icon,
    required this.background,
    required this.foreground,
    this.onTap,
    this.busy = false,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final Future<void> Function()? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 42,
      child: Material(
        color: background,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap == null ? null : () => onTap!(),
          child: Center(
            child: busy
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: foreground,
                    ),
                  )
                : Icon(icon, size: 20, color: foreground),
          ),
        ),
      ),
    );
  }
}

String formatRelative(DateTime? time) {
  if (time == null) return '';
  final now = DateTime.now();
  final diff = now.difference(time);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return DateFormat.MMMd().format(time);
}
