import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/models/chat_input_data.dart';
import '../../../core/models/chat_message.dart';
import '../../../icons/broken_icons.dart';
import '../../../theme/app_font_weights.dart';
import '../../chat/widgets/chat_message_widget.dart';
import '../../home/widgets/chat_input_bar.dart';
import '../models/openhands_models.dart';
import '../providers/openhands_provider.dart';
import '../widgets/handoff_logo.dart';
import 'settings_page.dart';

/// The chat surface for one OpenHands conversation.
class OpenHandsConversationView extends StatefulWidget {
  const OpenHandsConversationView({super.key});

  @override
  State<OpenHandsConversationView> createState() =>
      _OpenHandsConversationViewState();
}

class _OpenHandsConversationViewState extends State<OpenHandsConversationView> {
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

  Future<ChatInputSubmissionResult> _send(ChatInputData data) async {
    final text = data.text.trim();
    if (text.isEmpty) return ChatInputSubmissionResult.rejected;
    final provider = context.read<OpenHandsProvider>();
    final sent = await provider.sendMessage(text);
    if (sent) _scrollToBottom();
    return sent
        ? ChatInputSubmissionResult.sent
        : ChatInputSubmissionResult.rejected;
  }

  void _openModelSettings() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const OpenHandsSettingsPage()));
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
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  itemCount: timeline.length,
                  itemBuilder: (context, index) {
                    final item = timeline[index];
                    return _TimelineRow(
                      item: item,
                      conversationId: provider.active?.id ?? 'handoff',
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
        ChatInputBar(
          controller: _composer,
          focusNode: _composerFocus,
          loading: provider.agentRunning || provider.sending,
          onSend: _send,
          onStop: () => provider.stopAgent(),
          onSelectModel: _openModelSettings,
          chatModelId: provider.active?.llmModel,
          modelIcon: const HandoffLogo(size: 22, radius: 7),
          showMoreButton: false,
          showToolsButton: false,
          showMiniMapButton: false,
          showWorkspaceButton: false,
          showQuickPhraseButton: false,
          showOcrButton: false,
          sendButtonTooltip: 'Send',
        ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.item, required this.conversationId});

  final HandoffTimelineItem item;
  final String conversationId;

  ChatMessage _message() {
    switch (item.kind) {
      case HandoffItemKind.user:
        return ChatMessage(
          id: item.id,
          role: 'user',
          content: item.text,
          conversationId: conversationId,
          timestamp: item.at,
        );
      case HandoffItemKind.assistant:
        return ChatMessage(
          id: item.id,
          role: 'assistant',
          content: item.text,
          conversationId: conversationId,
          timestamp: item.at,
          isStreaming: item.running,
        );
      case HandoffItemKind.action:
        return ChatMessage(
          id: item.id,
          role: 'tool',
          content: jsonEncode({
            'tool': item.toolName ?? item.title ?? 'tool',
            'arguments': item.arguments,
            'result': item.result.isNotEmpty ? item.result : item.text,
          }),
          conversationId: conversationId,
          timestamp: item.at,
        );
      case HandoffItemKind.error:
      case HandoffItemKind.notice:
        return ChatMessage(
          id: item.id,
          role: 'assistant',
          content: item.text,
          conversationId: conversationId,
          timestamp: item.at,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (item.kind == HandoffItemKind.error) return _ErrorRow(item: item);
    if (item.kind == HandoffItemKind.notice) return _NoticeRow(item: item);
    return ChatMessageWidget(
      key: ValueKey('${item.kind.name}-${item.id}'),
      message: _message(),
      showTokenStats: false,
      showModelIcon: false,
      useAssistantAvatar: true,
      useAssistantName: true,
      assistantName: 'OpenHands',
      assistantAvatar: '🤖',
      hideStreamingIndicator: !item.running,
      enableStreamingTextMotion: true,
      showThinkingCards: false,
      showToolCards: true,
      collapseThinkingSteps: true,
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
            FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
          ],
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
