import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handoff/core/theme/app_theme.dart';
import 'package:handoff/models/conversation.dart';
import 'package:handoff/providers/app_providers.dart';
import 'package:handoff/screens/conversation_screen.dart';
import 'package:handoff/screens/home_screen.dart';
import 'package:handoff/services/notification_service.dart';
import 'package:handoff/services/session_service.dart';
import 'package:handoff/widgets/conversation_tabs.dart';
import 'package:material_ui/material_ui.dart';

/// A notifier that records nothing: the screens must not need the native
/// notifications plugin to build.
class _SilentNotifier implements AgentNotifier {
  @override
  Future<void> showAgentState({
    required String conversationId,
    required String title,
    required String body,
  }) async {}
}

CloudConversation conversation(String id, String title) => CloudConversation(
  id: id,
  title: title,
  conversationUrl: 'https://sandbox.example/api/conversations/$id',
  sessionApiKey: 'key',
  sandboxStatus: 'RUNNING',
  executionStatus: 'running',
  llmModel: 'claude-sonnet',
  updatedAt: DateTime.now(),
);

Widget app(Widget child, {Size size = const Size(412, 892)}) {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.dark(),
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  // A RenderFlex overflow, an unbounded constraint or a bad colour lookup
  // throws inside the widget build, so pumping the real screens is a genuine
  // layout test: if these pass, the screens lay out on a phone-sized canvas.
  testWidgets('the landing pane lays out on a phone', (tester) async {
    await tester.binding.setSurfaceSize(const Size(412, 892));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app(const HomeScreen()));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Handoff'), findsOneWidget);
    expect(find.text('New Chat'), findsOneWidget);
    expect(find.text('OpenHands Cloud'), findsOneWidget);
    expect(find.text('What are we working on?'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('the conversation screen lays out with a transcript', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 892));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final service = SessionService(notifications: _SilentNotifier());
    addTearDown(service.disposeAll);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionServiceProvider.overrideWithValue(service)],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: ConversationScreen(
              conversation: conversation('c1', 'Fix it'),
            ),
          ),
        ),
      ),
    );
    // No history is reachable in this test; the empty/queued state must still
    // build without throwing.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Fix it'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('the sidebar lays out on a wide window', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      app(const HomeScreen(), size: const Size(1280, 900)),
    );
    await tester.pump(const Duration(milliseconds: 350));

    // Wide layout keeps the sidebar visible beside the landing pane.
    expect(find.text('Handoff'), findsWidgets);
    expect(find.text('Search conversations'), findsOneWidget);
  });

  testWidgets('conversation tabs select, close, and create chats', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(412, 892));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final scrollController = ScrollController();
    var selectedId = '';
    var closedId = '';
    var selectedNew = false;
    var createdNew = false;

    await tester.pumpWidget(
      app(
        ConversationTabs(
          conversations: [conversation('c1', 'Fix login')],
          activeConversationId: 'c1',
          newConversationOpen: true,
          scrollController: scrollController,
          onSelectConversation: (item) => selectedId = item.id,
          onSelectNewConversation: () => selectedNew = true,
          onCloseConversation: (id) => closedId = id,
          onCloseNewConversation: () {},
          onNewConversation: () => createdNew = true,
        ),
      ),
    );

    await tester.tap(find.text('New task'));
    await tester.pump();
    expect(selectedNew, isTrue);

    await tester.tap(find.text('Fix login'));
    await tester.pump();
    expect(selectedId, 'c1');

    await tester.tap(find.byTooltip('Close tab Fix login'));
    await tester.pump();
    expect(closedId, 'c1');

    await tester.tap(find.byTooltip('New chat'));
    await tester.pump();
    expect(createdNew, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    scrollController.dispose();
  });
}
