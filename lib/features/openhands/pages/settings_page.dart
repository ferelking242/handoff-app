import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers/settings_provider.dart';
import '../../../icons/broken_icons.dart';
import '../../../theme/app_font_weights.dart';
import '../providers/openhands_provider.dart';
import '../widgets/handoff_logo.dart';
import '../widgets/handoff_sheets.dart';
import 'guard_page.dart';

class OpenHandsSettingsPage extends StatelessWidget {
  const OpenHandsSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OpenHandsProvider>();
    final settings = context.watch<SettingsProvider>();
    final scheme = Theme.of(context).colorScheme;
    final user = provider.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _AccountCard(provider: provider, onTap: () => showHandoffAccountSheet(context)),
          const SizedBox(height: 18),
          const _SectionLabel('OPENHANDS'),
          _SectionCard(
            children: [
              _Tile(
                icon: Broken.message,
                title: 'Provider',
                subtitle: 'OpenHands is the default for every conversation',
                trailing: Icon(
                  Broken.tick_circle,
                  size: 19,
                  color: scheme.primary,
                ),
              ),
              _divider(context),
              _Tile(
                icon: Broken.cpu,
                title: 'Model',
                subtitle: provider.activeModel ?? user?.llmModel ?? 'Managed by OpenHands',
              ),
              _divider(context),
              _Tile(
                icon: Broken.global,
                title: 'Server',
                subtitle: provider.baseUrl,
                trailing: Icon(
                  Broken.edit,
                  size: 17,
                  color: scheme.onSurfaceVariant,
                ),
                onTap: () => _editServer(context, provider),
              ),
              _divider(context),
              _Tile(
                icon: Broken.user,
                title: 'Account',
                subtitle: user?.email ?? 'Not signed in',
                onTap: () => showHandoffAccountSheet(context),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _SectionLabel('GUARD'),
          _SectionCard(
            children: [
              _Tile(
                icon: Broken.shield_tick,
                title: 'OpenHands Guard',
                subtitle: provider.guard.isConfigured
                    ? provider.guard.url
                    : 'Not configured · tap to set the address',
                trailing: Icon(
                  Broken.arrow_right_2,
                  size: 17,
                  color: scheme.onSurfaceVariant,
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const OpenHandsGuardPage(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _SectionLabel('APPEARANCE'),
          _SectionCard(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Broken.moon,
                          size: 19,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(child: Text('Theme')),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<ThemeMode>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                            value: ThemeMode.system,
                            icon: Icon(Broken.monitor, size: 16),
                            label: Text('System'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.light,
                            icon: Icon(Broken.sun, size: 16),
                            label: Text('Light'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            icon: Icon(Broken.moon, size: 16),
                            label: Text('Dark'),
                          ),
                        ],
                        selected: {settings.themeMode},
                        onSelectionChanged: (value) {
                          context
                              .read<SettingsProvider>()
                              .setThemeMode(value.first);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _SectionLabel('ABOUT'),
          _SectionCard(
            children: [
              _Tile(
                icon: Broken.information,
                title: 'Handoff',
                subtitle: 'A clean OpenHands client',
                trailing: FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    final version = snapshot.data?.version;
                    return Text(
                      version == null ? '' : 'v$version',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    );
                  },
                ),
              ),
              _divider(context),
              _Tile(
                icon: Broken.link,
                title: 'OpenHands',
                subtitle: 'app.all-hands.dev',
                onTap: () => launchUrl(
                  Uri.parse('https://app.all-hands.dev'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
              _divider(context),
              _Tile(
                icon: Broken.code,
                title: 'Source code',
                subtitle: 'github.com/ferelking242/handoff',
                onTap: () => launchUrl(
                  Uri.parse('https://github.com/ferelking242/handoff'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          OutlinedButton.icon(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Sign out of OpenHands?'),
                  content: const Text(
                    'The API token is removed from this device.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await provider.signOut();
                if (context.mounted) Navigator.of(context).pop();
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: scheme.error,
              side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Broken.logout, size: 18),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  Future<void> _editServer(
    BuildContext context,
    OpenHandsProvider provider,
  ) async {
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
              'Use app.all-hands.dev for OpenHands Cloud, or the address of your self-hosted server. Changing the server signs you out.',
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
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.provider, required this.onTap});

  final OpenHandsProvider provider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = provider.user;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const HandoffLogo(size: 46, radius: 14),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.displayName ?? 'OpenHands user',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: AppFontWeights.semibold,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user?.email ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (user?.orgName.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        user!.orgName,
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Broken.arrow_right_2,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          letterSpacing: 1.2,
          fontWeight: AppFontWeights.semibold,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 19, color: scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: AppFontWeights.medium,
                      color: scheme.onSurface,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 10),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

Widget _divider(BuildContext context) {
  return Divider(
    height: 1,
    thickness: 1,
    indent: 45,
    color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
  );
}
