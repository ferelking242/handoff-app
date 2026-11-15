/// Agent execution state, mapped from the sandbox `execution_status`.
enum AgentState {
  idle,
  running,
  awaitingUserInput,
  awaitingConfirmation,
  finished,
  error,
  stuck,
  stopped,
  unknown;

  static AgentState fromStatus(String? status) {
    switch (status) {
      case 'idle':
        return AgentState.idle;
      case 'running':
        return AgentState.running;
      case 'awaiting_user_input':
        return AgentState.awaitingUserInput;
      case 'awaiting_user_confirmation':
        return AgentState.awaitingConfirmation;
      case 'finished':
        return AgentState.finished;
      case 'error':
        return AgentState.error;
      case 'stuck':
        return AgentState.stuck;
      case 'stopped':
        return AgentState.stopped;
      default:
        return AgentState.unknown;
    }
  }

  /// States where the user must act, so a notification is warranted.
  bool get needsAttention =>
      this == AgentState.awaitingUserInput ||
      this == AgentState.awaitingConfirmation ||
      this == AgentState.finished ||
      this == AgentState.error;

  String get label {
    switch (this) {
      case AgentState.idle:
        return 'Idle';
      case AgentState.running:
        return 'Working';
      case AgentState.awaitingUserInput:
        return 'Needs your input';
      case AgentState.awaitingConfirmation:
        return 'Needs confirmation';
      case AgentState.finished:
        return 'Finished';
      case AgentState.error:
        return 'Error';
      case AgentState.stuck:
        return 'Stuck';
      case AgentState.stopped:
        return 'Stopped';
      case AgentState.unknown:
        return 'Unknown';
    }
  }
}
