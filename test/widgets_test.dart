import 'package:flutter_test/flutter_test.dart';
import 'package:handoff/core/icon_fonts/app_icons.dart';
import 'package:handoff/core/theme/app_theme.dart';
import 'package:handoff/models/agent_state.dart';
import 'package:handoff/models/conversation_event.dart';
import 'package:handoff/widgets/composer.dart';
import 'package:handoff/widgets/event_bubble.dart';
import 'package:handoff/widgets/pane_header.dart';
import 'package:handoff/widgets/status_chip.dart';
import 'package:handoff/widgets/typing_dots.dart';
import 'package:material_ui/material_ui.dart';

/// Pumps [child] inside the real app theme, so a layout error (an unbounded
/// constraint, a bad colour lookup) fails the test rather than a device.
Future<void> pumpThemed(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(body: child),
    ),
  );
}

ConversationEvent event(
  String kind,
  String source, {
  String? text,
  Map<String, dynamic>? extra,
}) {
  return ConversationEvent.fromJson({
    'id': 'e-$kind-$source',
    'kind': kind,
    'source': source,
    if (text != null) 'message': text,
    ...?extra,
  });
}

void main() {
  testWidgets('StatusChip shows the agent state and its label', (tester) async {
    await pumpThemed(tester, const StatusChip(state: AgentState.running));
    expect(find.text('Working'), findsOneWidget);

    await pumpThemed(
      tester,
      const StatusChip(state: AgentState.running, connected: false),
    );
    expect(find.text('Reconnecting'), findsOneWidget);
  });

  testWidgets('PaneHeader renders its title and a menu button', (tester) async {
    var tapped = false;
    await pumpThemed(
      tester,
      PaneHeader(
        title: const Text('My conversation'),
        onMenu: () => tapped = true,
      ),
    );
    expect(find.text('My conversation'), findsOneWidget);
    // The header draws a custom circular button, not an IconButton, so target
    // the menu glyph itself.
    await tester.tap(find.byIcon(AppIcons.menu));
    expect(tapped, isTrue);
  });

  testWidgets('TypingDots renders three animated dots', (tester) async {
    await pumpThemed(tester, const TypingDots());
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(Container), findsNWidgets(3));
  });

  testWidgets('Composer sends the typed text and clears itself', (
    tester,
  ) async {
    String? sent;
    await pumpThemed(
      tester,
      Composer(onSend: (text) => sent = text, onStop: () {}),
    );

    await tester.enterText(find.byType(TextField), 'fix the build');
    await tester.pump();
    await tester.tap(find.byIcon(AppIcons.send));
    await tester.pump();

    expect(sent, 'fix the build');
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty);
  });

  testWidgets('Composer shows stop instead of send while busy', (tester) async {
    var stopped = false;
    await pumpThemed(
      tester,
      Composer(onSend: (_) {}, onStop: () => stopped = true, busy: true),
    );
    await tester.tap(find.byIcon(AppIcons.stop));
    expect(stopped, isTrue);
  });

  testWidgets('EventBubble renders a user message and an agent message', (
    tester,
  ) async {
    await pumpThemed(
      tester,
      Column(
        children: [
          EventBubble(
            event: event('MessageEvent', 'user', text: 'hello there'),
            animateIn: false,
          ),
          EventBubble(
            event: event('MessageEvent', 'agent', text: 'working on it'),
            animateIn: false,
          ),
        ],
      ),
    );
    expect(find.text('hello there'), findsOneWidget);
    expect(find.text('working on it'), findsOneWidget);
  });

  testWidgets('EventBubble collapses a tool call and expands it on tap', (
    tester,
  ) async {
    await pumpThemed(
      tester,
      EventBubble(
        event: event(
          'ActionEvent',
          'agent',
          extra: {
            'tool_name': 'bash',
            'action': {'command': 'ls -la'},
          },
        ),
        animateIn: false,
      ),
    );
    expect(find.text('bash'), findsOneWidget);
    // Collapsed: the payload is not on screen yet.
    expect(find.textContaining('ls -la'), findsNothing);

    await tester.tap(find.text('bash'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ls -la'), findsOneWidget);
  });

  testWidgets('EventBubble ignores state-update events', (tester) async {
    await pumpThemed(
      tester,
      EventBubble(
        event: event(
          'ConversationStateUpdateEvent',
          'agent',
          extra: {'key': 'execution_status', 'value': 'running'},
        ),
        animateIn: false,
      ),
    );
    expect(find.byType(SizedBox), findsWidgets);
  });
}
