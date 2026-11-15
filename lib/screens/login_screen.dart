import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

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
                  Icon(
                    Icons.terminal_rounded,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Handoff',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'OpenHands Cloud on your phone',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (session == null) ...[
                    FilledButton.icon(
                      onPressed: _busy ? null : _start,
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: Text(_busy ? 'Connecting…' : 'Sign in with Cloud'),
                    ),
                  ] else ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Text(
                              'Enter this code on the website',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            SelectableText(
                              session.userCode,
                              style: theme.textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 4,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _secondsLeft > 0
                                  ? 'Expires in $_secondsLeft s'
                                  : 'Code expired',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => launchUrl(
                        Uri.parse(session.verificationUriComplete),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.open_in_browser),
                      label: const Text('Open the sign-in page'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      session.verificationUri,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    if (_busy) ...[
                      const LinearProgressIndicator(),
                      const SizedBox(height: 8),
                      Text(
                        _status ?? 'Waiting for approval…',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                    ] else
                      OutlinedButton(
                        onPressed: _start,
                        child: const Text('Try again'),
                      ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 20),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
