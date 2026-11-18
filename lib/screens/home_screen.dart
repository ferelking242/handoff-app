import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../models/conversation.dart';
import '../widgets/conversation_list.dart';
import 'conversation_screen.dart';
import 'new_conversation_screen.dart';

/// The signed-in shell.
///
/// On a phone the conversation browser lives in a drawer. On a wide window it
/// becomes a permanent sidebar, leaving the active agent visible while browsing.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const _wideBreakpoint = 900.0;

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  CloudConversation? _selected;

  bool get _isWide => MediaQuery.sizeOf(context).width >= _wideBreakpoint;

  void _open(CloudConversation conversation) {
    if (!_isWide) _scaffoldKey.currentState?.closeDrawer();
    setState(() => _selected = conversation);
  }

  void _newConversation() {
    _scaffoldKey.currentState?.closeDrawer();
    setState(() => _selected = null);
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
              width: 286,
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
            topRight: Radius.circular(AppRadius.lg),
            bottomRight: Radius.circular(AppRadius.lg),
          ),
        ),
        child: SafeArea(child: sidebar),
      ),
      body: _buildContent(isWide: false),
    );
  }

  Widget _buildContent({required bool isWide}) {
    final selected = _selected;
    if (selected != null) {
      return ConversationScreen(
        conversation: selected,
        onMenu: isWide ? null : () => _scaffoldKey.currentState?.openDrawer(),
      );
    }
    return NewConversationScreen(
      onOpen: _open,
      onMenu: isWide ? null : () => _scaffoldKey.currentState?.openDrawer(),
    );
  }
}
