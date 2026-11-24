import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../icons/broken_icons.dart';
import '../../../theme/app_font_weights.dart';
import '../providers/openhands_provider.dart';
import '../widgets/handoff_logo.dart';

/// Sign-in surface: OpenHands device flow first, API key as a fallback for
/// self-hosted servers.
class OpenHandsLoginPage extends StatelessWidget {
  const OpenHandsLoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OpenHandsProvider>();
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.65),
            radius: 1.2,
            colors: isDark
                ? [
                    scheme.primary.withValues(alpha: 0.16),
                    scheme.surface,
                    scheme.surface,
                  ]
                : [
                    scheme.primary.withValues(alpha: 0.10),
                    scheme.surface,
                    scheme.surface,
                  ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: HandoffLogo(size: 88, radius: 26))
                        .animate()
                        .fadeIn(duration: 420.ms)
                        .scale(begin: const Offset(0.9, 0.9)),
                    const SizedBox(height: 24),
                    Text(
                      'Handoff',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: AppFontWeights.heavy,
                        letterSpacing: -1.2,
                        color: scheme.onSurface,
                      ),
                    ).animate().fadeIn(delay: 80.ms),
                    const SizedBox(height: 8),
                    Text(
                      'Your OpenHands client',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: scheme.onSurfaceVariant,
                      ),
                    ).animate().fadeIn(delay: 140.ms),
                    const SizedBox(height: 32),
                    if (provider.error != null) ...[
                      _ErrorCard(
                        message: provider.error!,
                        onRetry: provider.authStatus == OpenHandsAuthStatus.error
                            ? provider.retry
                            : null,
                        onSignOut:
                            provider.authStatus == OpenHandsAuthStatus.error
                                ? provider.signOut
                                : null,
                      ),
                      const SizedBox(height: 18),
                    ],
                    if (provider.deviceCode != null)
                      _DeviceCodeCard(provider: provider)
                    else
                      _SignInOptions(provider: provider),
                    const SizedBox(height: 28),
                    _ServerFooter(provider: provider),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SignInOptions extends StatelessWidget {
  const _SignInOptions({required this.provider});

  final OpenHandsProvider provider;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final busy = provider.authStatus == OpenHandsAuthStatus.signingIn;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: busy ? null : provider.startDeviceSignIn,
          icon: busy
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: scheme.onPrimary,
                  ),
                )
              : const Icon(Broken.login, size: 20),
          label: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              busy ? 'Starting sign-in…' : 'Sign in with OpenHands',
              style: TextStyle(
                fontSize: 16,
                fontWeight: AppFontWeights.semibold,
              ),
            ),
          ),
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: busy
              ? null
              : () async {
                  final key = await _askForApiKey(context);
                  if (key != null && key.isNotEmpty) {
                    await provider.signInWithApiKey(key);
                  }
                },
          icon: const Icon(Broken.key, size: 18),
          label: const Text('Use an API key'),
        ),
      ],
    );
  }

  Future<String?> _askForApiKey(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('OpenHands API key'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste a key from OpenHands → Settings → API keys. Use this for a self-hosted server.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'API key',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (value) =>
                    Navigator.of(dialogContext).pop(value),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse(provider.apiKeysUrl);
                    await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    );
                  },
                  icon: const Icon(Broken.export, size: 16),
                  label: const Text('Generate an API key'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 36),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text),
              child: const Text('Sign in'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }
}

class _DeviceCodeCard extends StatelessWidget {
  const _DeviceCodeCard({required this.provider});

  final OpenHandsProvider provider;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final code = provider.deviceCode!;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Broken.shield_tick, size: 20, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Approve this sign-in',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: AppFontWeights.semibold,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Open the OpenHands page and enter this code.',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  code.userCode,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: AppFontWeights.heavy,
                    letterSpacing: 6,
                    fontFamily: 'monospace',
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  tooltip: 'Copy code',
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: code.userCode),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code copied')),
                      );
                    }
                  },
                  icon: const Icon(Broken.copy, size: 20),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code.userCode));
              provider.openVerificationPage();
            },
            icon: const Icon(Broken.export, size: 18),
            label: const Text('Open OpenHands'),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Waiting for you to approve…',
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (provider.deviceNotice != null) ...[
            Text(
              provider.deviceNotice!,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
          ],
          TextButton(
            onPressed: provider.cancelDeviceSignIn,
            child: const Text('Cancel'),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.04, end: 0);
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, this.onRetry, this.onSignOut});

  final String message;
  final Future<void> Function()? onRetry;
  final Future<void> Function()? onSignOut;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Broken.warning_2, size: 18, color: scheme.error),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(fontSize: 13, color: scheme.onErrorContainer),
                ),
              ),
            ],
          ),
          if (onRetry != null || onSignOut != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (onRetry != null)
                  TextButton(
                    onPressed: onRetry,
                    child: const Text('Retry'),
                  ),
                if (onSignOut != null)
                  TextButton(
                    onPressed: onSignOut,
                    child: const Text('Sign out'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ServerFooter extends StatelessWidget {
  const _ServerFooter({required this.provider});

  final OpenHandsProvider provider;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Broken.global, size: 14, color: scheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            provider.baseUrl.replaceFirst('https://', ''),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: 4),
        TextButton(
          onPressed: () => _editServer(context),
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 32),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: const Text('Change', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  Future<void> _editServer(BuildContext context) async {
    final controller = TextEditingController(text: provider.baseUrl);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('OpenHands server'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Use app.all-hands.dev for OpenHands Cloud, or the address of your self-hosted server.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Server URL',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && result.trim().isNotEmpty) {
      await provider.setBaseUrl(result);
    }
  }
}
