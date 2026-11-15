import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/icon_fonts/app_icons.dart';
import '../core/theme/app_theme.dart';
import '../models/conversation.dart';
import '../widgets/conversation_list.dart';
import '../widgets/pane_header.dart';
import 'conversation_screen.dart';
import 'new_conversation_screen.dart';

/// The signed-in shell.
///
/// On a phone the conversation browser lives in a drawer, exactly like the
/// ChatGPT app. On a wide window it becomes a permanent sidebar and the
/// conversation opens beside it, so the agent is visible while browsing.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const _wideBreakpoint = 900.0;

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  CloudConversation? _selected;
  bool _composing = false;

  bool get _isWide =>
      MediaQuery.sizeOf(context).width >= _wideBreakpoint;

  void _open(CloudConversation conversation) {
    if (_isWide) {
      setState(() {
        _selected = conversation;
        _composing = false;
      });
      return;
    }
    _scaffoldKey.currentState?.closeDrawer();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          body: SafeArea(
            child: ConversationScreen(
              conversation: conversation,
              onBack: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ),
    );
  }

  void _newConversation() {
    if (_isWide) {
      setState(() => _composing = true);
      return;
    }
    _scaffoldKey.currentState?.closeDrawer();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(body: SafeArea(child: NewConversationScreen(onOpen: _open))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = _isWide;
    final sidebar = ConversationList(
      activeId: _selected?.id,
      onOpen: _open,
      onNew: _newConversation,
    );

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            SizedBox(
              width: 300,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    right: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                child: sidebar,
              ),
            ),
            Expanded(child: _buildContent(isWide: true)),
          ],
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        width: 320,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(AppRadius.xl),
            bottomRight: Radius.circular(AppRadius.xl),
          ),
        ),
        child: SafeArea(child: sidebar),
      ),
      body: _buildContent(isWide: false),
    );
  }

  Widget _buildContent({required bool isWide}) {
    if (_composing && isWide) {
      return NewConversationScreen(onOpen: _open);
    }
    final selected = _selected;
    if (isWide && selected != null) {
      return ConversationScreen(conversation: selected);
    }
    return _LandingPane(
      showMenu: !isWide,
      onMenu: () => _scaffoldKey.currentState?.openDrawer(),
      onNew: _newConversation,
    );
  }
}

class _LandingPane extends StatelessWidget {
  const _LandingPane({
    required this.showMenu,
    required this.onMenu,
    required this.onNew,
  });

  final bool showMenu;
  final VoidCallback onMenu;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        PaneHeader(
          onMenu: showMenu ? onMenu : null,
          title: const Text('Handoff'),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 74,
                      height: 74,
                      decoration: const BoxDecoration(
                        gradient: AppColors.accentGradient,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        AppIcons.flash,
                        size: 34,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'What should the agent do?',
                      style: theme.textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Describe a task. Handoff keeps the agent running even '
                      'when you leave the screen, and notifies you when it '
                      'needs you.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 26),
                    FilledButton.icon(
                      onPressed: onNew,
                      icon: const Icon(AppIcons.add, size: 18),
                      label: const Text('New conversation'),
                    ),
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
