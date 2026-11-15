import 'package:flutter_test/flutter_test.dart';
import 'package:aivos/models/agent_state.dart';
import 'package:aivos/models/conversation.dart';
import 'package:aivos/models/conversation_event.dart';

void main() {
  group('AgentState.fromStatus', () {
    test('maps every documented sandbox status', () {
      expect(AgentState.fromStatus('running'), AgentState.running);
      expect(AgentState.fromStatus('idle'), AgentState.idle);
      expect(
        AgentState.fromStatus('awaiting_user_input'),
        AgentState.awaitingUserInput,
      );
      expect(
        AgentState.fromStatus('awaiting_user_confirmation'),
        AgentState.awaitingConfirmation,
      );
      expect(AgentState.fromStatus('finished'), AgentState.finished);
      expect(AgentState.fromStatus('error'), AgentState.error);
      expect(AgentState.fromStatus('stuck'), AgentState.stuck);
      expect(AgentState.fromStatus('stopped'), AgentState.stopped);
      expect(AgentState.fromStatus('something_new'), AgentState.unknown);
      expect(AgentState.fromStatus(null), AgentState.unknown);
    });

    test('only the actionable states ask for the user', () {
      expect(AgentState.running.needsAttention, isFalse);
      expect(AgentState.idle.needsAttention, isFalse);
      expect(AgentState.awaitingUserInput.needsAttention, isTrue);
      expect(AgentState.awaitingConfirmation.needsAttention, isTrue);
      expect(AgentState.finished.needsAttention, isTrue);
      expect(AgentState.error.needsAttention, isTrue);
    });
  });

  group('CloudConversation.agentServerBaseUrl', () {
    test('strips the /api/conversations suffix the Cloud appends', () {
      const conversation = CloudConversation(
        id: 'c1',
        title: 't',
        conversationUrl:
            'https://abc.prod-runtime.all-hands.dev/api/conversations/',
      );
      expect(
        conversation.agentServerBaseUrl,
        'https://abc.prod-runtime.all-hands.dev',
      );
    });

    test('keeps a bare host unchanged', () {
      const conversation = CloudConversation(
        id: 'c1',
        title: 't',
        conversationUrl: 'https://abc.prod-runtime.all-hands.dev',
      );
      expect(
        conversation.agentServerBaseUrl,
        'https://abc.prod-runtime.all-hands.dev',
      );
    });

    test('is null when the Cloud did not provide a url', () {
      const conversation = CloudConversation(id: 'c1', title: 't');
      expect(conversation.agentServerBaseUrl, isNull);
    });
  });

  group('CloudConversation.isReady', () {
    test('requires a running sandbox, a url, and a session key', () {
      const ready = CloudConversation(
        id: 'c1',
        title: 't',
        conversationUrl: 'https://host/api/conversations/',
        sessionApiKey: 'k',
        sandboxStatus: 'RUNNING',
      );
      expect(ready.isReady, isTrue);

      const noKey = CloudConversation(
        id: 'c1',
        title: 't',
        conversationUrl: 'https://host/api/conversations/',
        sandboxStatus: 'RUNNING',
      );
      expect(noKey.isReady, isFalse);

      const notRunning = CloudConversation(
        id: 'c1',
        title: 't',
        conversationUrl: 'https://host/api/conversations/',
        sessionApiKey: 'k',
        sandboxStatus: 'STARTING',
      );
      expect(notRunning.isReady, isFalse);
    });
  });

  group('CloudConversation.fromJson', () {
    test('reads the Cloud record fields', () {
      final conversation = CloudConversation.fromJson({
        'id': 'abc',
        'title': 'Fix the bug',
        'conversation_url': 'https://host/api/conversations/',
        'session_api_key': 'secret',
        'sandbox_id': 'sb1',
        'sandbox_status': 'RUNNING',
        'execution_status': 'running',
        'llm_model': 'gpt',
        'created_at': '2026-01-02T03:04:05Z',
      });
      expect(conversation.id, 'abc');
      expect(conversation.title, 'Fix the bug');
      expect(conversation.sessionApiKey, 'secret');
      expect(conversation.isRunning, isTrue);
      expect(conversation.createdAt, DateTime.utc(2026, 1, 2, 3, 4, 5));
    });

    test('falls back to a readable title when blank', () {
      final conversation = CloudConversation.fromJson({'id': 'x', 'title': '  '});
      expect(conversation.title, 'Untitled conversation');
    });
  });

  group('ConversationEvent', () {
    test('reads message text from a plain string message', () {
      final event = ConversationEvent.fromJson({
        'id': 'e1',
        'kind': 'MessageEvent',
        'source': 'agent',
        'message': 'hello there',
      });
      expect(event.text, 'hello there');
      expect(event.isAssistantMessage, isTrue);
      expect(event.isUserMessage, isFalse);
    });

    test('reads message text from a content parts list', () {
      final event = ConversationEvent.fromJson({
        'id': 'e1',
        'kind': 'MessageEvent',
        'source': 'user',
        'message': {
          'content': [
            {'type': 'text', 'text': 'part one '},
            {'type': 'text', 'text': 'part two'},
          ],
        },
      });
      expect(event.text, 'part one part two');
      expect(event.isUserMessage, isTrue);
    });

    test('exposes the tool name and payloads for action events', () {
      final event = ConversationEvent.fromJson({
        'id': 'e2',
        'kind': 'ActionEvent',
        'source': 'agent',
        'tool_name': 'bash',
        'action': {'command': 'ls'},
      });
      expect(event.isAction, isTrue);
      expect(event.toolName, 'bash');
      expect(event.action['command'], 'ls');
    });

    test('classifies error and state-update events', () {
      final error = ConversationEvent.fromJson({
        'id': 'e3',
        'kind': 'ConversationErrorEvent',
        'source': 'agent',
      });
      expect(error.isError, isTrue);

      final update = ConversationEvent.fromJson({
        'id': 'e4',
        'kind': 'ConversationStateUpdateEvent',
        'source': 'agent',
        'key': 'execution_status',
        'value': 'running',
      });
      expect(update.isStateUpdate, isTrue);
      expect(update.raw['value'], 'running');
    });

    test('keeps the seq cursor when replayed over the socket', () {
      final event = ConversationEvent.fromJson(
        {'id': 'e5', 'kind': 'MessageEvent', 'source': 'agent'},
        seq: 42,
      );
      expect(event.seq, 42);
    });
  });
}
