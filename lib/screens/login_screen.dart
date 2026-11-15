import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/icon_fonts/app_icons.dart';
import '../core/theme/app_theme.dart';
import '../providers/app_providers.dart';
import '../services/device_flow_service.dart';

/// Device-flow sign-in. No password is typed into the app: the user opens a
/// short URL in any browser, approves, and the app picks up the token.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  DeviceFlowSession? _session;
  String? _error;
  String? _status;
  bool _busy = false;
  Timer? _countdown;
  int _secondsLeft = 0;

  @override
  void dispose() {
    _countdown?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _error = null;
      _status = null;
    });
    try {
      final session = await ref.read(deviceFlowProvider).start();
      if (!mounted) return;
      setState(() {
        _session = session;
        _secondsLeft = session.expiresIn;
      });
      _countdown?.cancel();
      _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() => _secondsLeft--);
        if (_secondsLeft <= 0) timer.cancel();
      });

      final token = await ref
          .read(deviceFlowProvider)
          .awaitToken(
            session,
            timeout: Duration(seconds: session.expiresIn),
            onStatus: (status) {
              if (mounted) setState(() => _status = status);
            },
          );
      await ref.read(authProvider.notifier).signIn(token);
    } on DeviceFlowException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = _session;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 76,
                      height: 76,
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
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Handoff',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'OpenHands Cloud, in your pocket',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 34),
                  if (session == null)
                    _SignInCard(
                      busy: _busy,
                      onStart: _start,
                      error: _error,
                    )
                  else
                    _DeviceCodeCard(
                      session: session,
                      secondsLeft: _secondsLeft,
                      busy: _busy,
                      status: _status,
                      error: _error,
                      onRestart: _start,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SignInCard extends StatelessWidget {
  const _SignInCard({
    required this.busy,
    required this.onStart,
    required this.error,
  });

  final bool busy;
  final VoidCallback onStart;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            children: [
              const Icon(AppIcons.lock, size: 22),
              const SizedBox(height: 12),
              Text(
                'Sign in without a password',
                style: theme.textTheme.titleSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Handoff shows a short code. Approve it in your browser once '
                'and this device stays signed in.',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: busy ? null : onStart,
          icon: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(AppIcons.arrowRight, size: 18),
          label: Text(busy ? 'Connecting…' : 'Sign in with OpenHands Cloud'),
        ),
        if (error != null) _ErrorText(error!),
      ],
    );
  }
}

class _DeviceCodeCard extends StatelessWidget {
  const _DeviceCodeCard({
    required this.session,
    required this.secondsLeft,
    required this.busy,
    required this.status,
    required this.error,
    required this.onRestart,
  });

  final DeviceFlowSession session;
  final int secondsLeft;
  final bool busy;
  final String? status;
  final String? error;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            children: [
              Text(
                'ENTER THIS CODE',
                style: theme.textTheme.labelSmall,
              ),
              const SizedBox(height: 12),
              SelectableText(
                session.userCode,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 6,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    AppIcons.timer,
                    size: 13,
                    color: secondsLeft > 0
                        ? theme.colorScheme.onSurfaceVariant
                        : AppColors.danger,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    secondsLeft > 0
                        ? 'Expires in ${_format(secondsLeft)}'
                        : 'Code expired',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => launchUrl(
            Uri.parse(session.verificationUriComplete),
            mode: LaunchMode.externalApplication,
          ),
          icon: const Icon(AppIcons.arrowRight, size: 18),
          label: const Text('Open the sign-in page'),
        ),
        const SizedBox(height: 8),
        SelectableText(
          session.verificationUri,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 18),
        if (busy)
          _WaitingIndicator(status: status)
        else
          OutlinedButton.icon(
            onPressed: onRestart,
            icon: const Icon(AppIcons.refresh, size: 16),
            label: const Text('Start over'),
          ),
        if (error != null) _ErrorText(error!),
      ],
    );
  }

  static String _format(int seconds) {
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${rest.toString().padLeft(2, '0')}';
  }
}

class _WaitingIndicator extends StatelessWidget {
  const _WaitingIndicator({required this.status});

  final String? status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        const ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.pill)),
          child: LinearProgressIndicator(minHeight: 3),
        ),
        const SizedBox(height: 10),
        Text(
          status ?? 'Waiting for approval…',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Icon(
              AppIcons.danger,
              size: 16,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: theme.colorScheme.onErrorContainer,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
