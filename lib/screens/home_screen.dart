import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../models/conversation.dart';
import '../widgets/conversation_list.dart';
import '../widgets/conversation_tabs.dart';
import 'conversation_screen.dart';
import 'new_conversation_screen.dart';

/// The signed-in shell.
///
/// Open conversations stay available as tabs while the conversation browser
/// remains in a drawer on phones and a sidebar on wide windows.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const _wideBreakpoint = 900.0;

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _tabsScrollController = ScrollController();
  final List<CloudConversation> _openConversations = [];
  String? _activeConversationId;
  bool _newConversationOpen = true;

  bool get _isWide => MediaQuery.sizeOf(context).width >= _wideBreakpoint;

  @override
  void dispose() {
    _tabsScrollController.dispose();
    super.dispose();
  }

  void _open(CloudConversation conversation) {
    if (!_isWide) _scaffoldKey.currentState?.closeDrawer();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      if (!_openConversations.any((item) => item.id == conversation.id)) {
        _openConversations.add(conversation);
      }
      _activeConversationId = conversation.id;
    });
    _scrollTabsToEnd();
  }

  void _newConversation() {
    _scaffoldKey.currentState?.closeDrawer();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _newConversationOpen = true;
      _activeConversationId = null;
    });
    _scrollTabsToEnd();
  }

  void _selectConversation(CloudConversation conversation) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _activeConversationId = conversation.id);
  }

  void _selectNewConversation() {
    if (!_newConversationOpen) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _activeConversationId = null);
  }

  void _closeConversation(String id) {
    final index = _openConversations.indexWhere((item) => item.id == id);
    if (index < 0) return;
    setState(() {
      _openConversations.removeAt(index);
      if (_activeConversationId != id) return;

      if (_openConversations.isEmpty) {
        if (_newConversationOpen) {
          _activeConversationId = null;
        } else {
          _newConversationOpen = true;
          _activeConversationId = null;
        }
      } else {
        final nextIndex = index >= _openConversations.length
            ? _openConversations.length - 1
            : index;
        _activeConversationId = _openConversations[nextIndex].id;
      }
    });
  }

  void _closeNewConversation() {
    if (!_newConversationOpen || _openConversations.isEmpty) return;
    setState(() {
      _newConversationOpen = false;
      _activeConversationId ??= _openConversations.last.id;
    });
  }

  void _scrollTabsToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_tabsScrollController.hasClients) return;
      _tabsScrollController.animateTo(
        _tabsScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWide = _isWide;
    final sidebar = ConversationList(
      activeId: _activeConversationId,
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
            Expanded(child: _buildWorkspace(isWide: true)),
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
      body: _buildWorkspace(isWide: false),
    );
  }

  Widget _buildWorkspace({required bool isWide}) {
    final onMenu = isWide ? null : () => _scaffoldKey.currentState?.openDrawer();
    final children = <Widget>[];
    if (_newConversationOpen) {
      children.add(
        NewConversationScreen(
          key: const ValueKey('new-conversation-tab'),
          onOpen: _open,
          onMenu: onMenu,
        ),
      );
    }
    for (final conversation in _openConversations) {
      children.add(
        ConversationScreen(
          key: ValueKey(conversation.id),
          conversation: conversation,
          onMenu: onMenu,
        ),
      );
    }

    final activeIndex = _activeConversationId == null
        ? 0
        : (_newConversationOpen ? 1 : 0) +
              _openConversations.indexWhere(
                (item) => item.id == _activeConversationId,
              );

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          ConversationTabs(
            conversations: _openConversations,
            activeConversationId: _activeConversationId,
            newConversationOpen: _newConversationOpen,
            scrollController: _tabsScrollController,
            onSelectConversation: _selectConversation,
            onSelectNewConversation: _selectNewConversation,
            onCloseConversation: _closeConversation,
            onCloseNewConversation: _closeNewConversation,
            onNewConversation: _newConversation,
          ),
          Expanded(
            child: IndexedStack(
              index: activeIndex.clamp(0, children.length - 1).toInt(),
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}
