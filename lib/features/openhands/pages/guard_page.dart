import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../icons/broken_icons.dart';
import '../../../theme/app_font_weights.dart';
import '../models/openhands_models.dart';
import '../providers/openhands_provider.dart';

/// Configuration and health check for the self-hosted OpenHands Guard.
class OpenHandsGuardPage extends StatefulWidget {
  const OpenHandsGuardPage({super.key});

  @override
  State<OpenHandsGuardPage> createState() => _OpenHandsGuardPageState();
}

class _OpenHandsGuardPageState extends State<OpenHandsGuardPage> {
  late final TextEditingController _url;
  late final TextEditingController _key;

  @override
  void initState() {
    super.initState();
    final guard = context.read<OpenHandsProvider>().guard;
    _url = TextEditingController(text: guard.url);
    _key = TextEditingController(text: guard.key);
  }

  @override
  void dispose() {
    _url.dispose();
    _key.dispose();
    super.dispose();
  }

  Future<void> _save({bool test = false}) async {
    final provider = context.read<OpenHandsProvider>();
    await provider.saveGuardConfig(
      GuardConfig(url: _url.text, key: _key.text),
    );
    if (!mounted) return;
    if (test) {
      final status = await provider.testGuard();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(status.message)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Guard settings saved')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OpenHandsProvider>();
    final scheme = Theme.of(context).colorScheme;
    final status = provider.guardStatus;

    return Scaffold(
      appBar: AppBar(title: const Text('OpenHands Guard')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Broken.shield_tick, size: 22, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'The Guard runs on your VPS. It watches your OpenHands conversations, nudges an agent that has gone quiet, and sends you a notification when one finishes.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'GUARD ADDRESS',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.2,
              fontWeight: AppFontWeights.semibold,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(
              hintText: 'https://guard.example.com',
              prefixIcon: const Icon(Broken.global, size: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'GUARD KEY',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.2,
              fontWeight: AppFontWeights.semibold,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _key,
            obscureText: true,
            autocorrect: false,
            decoration: InputDecoration(
              hintText: 'Bearer key issued by the Guard',
              prefixIcon: const Icon(Broken.key, size: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: provider.guardTesting ? null : () => _save(test: true),
                  icon: provider.guardTesting
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.onPrimary,
                          ),
                        )
                      : const Icon(Broken.flash, size: 17),
                  label: Text(
                    provider.guardTesting ? 'Testing…' : 'Save and test',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                tooltip: 'Save',
                onPressed: () => _save(),
                icon: const Icon(Broken.tick_circle, size: 19),
              ),
            ],
          ),
          if (status != null) ...[
            const SizedBox(height: 20),
            _GuardStatusCard(status: status),
          ],
          const SizedBox(height: 20),
          if (provider.guard.isConfigured)
            OutlinedButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(provider.guard.url),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Broken.export, size: 17),
              label: const Text('Open the Guard dashboard'),
            ),
        ],
      ),
    );
  }
}

class _GuardStatusCard extends StatelessWidget {
  const _GuardStatusCard({required this.status});

  final GuardStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = status.reachable ? scheme.primary : scheme.error;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                status.reachable ? Broken.tick_circle : Broken.warning_2,
                size: 19,
                color: color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  status.message,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: AppFontWeights.semibold,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              if (status.latency != null)
                Text(
                  '${status.latency!.inMilliseconds} ms',
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          if (status.detail != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: SelectableText(
                status.detail!,
                maxLines: 6,
                style: TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
