import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../icons/broken_icons.dart';
import '../../../theme/app_font_weights.dart';
import '../providers/openhands_provider.dart';

Future<void> showHandoffAccountSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => const _AccountSheet(),
  );
}

class _AccountSheet extends StatelessWidget {
  const _AccountSheet();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OpenHandsProvider>();
    final user = provider.user;
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: scheme.primary.withValues(alpha: 0.16),
                  child: Text(
                    user?.initial ?? 'O',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: AppFontWeights.heavy,
                      color: scheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName ?? 'OpenHands user',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: AppFontWeights.semibold,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?.email ?? 'Not signed in',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (user?.role.isNotEmpty == true)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      user!.role,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: AppFontWeights.semibold,
                        color: scheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            _AccountRow(
              icon: Broken.building,
              label: 'Organization',
              value: user?.orgName.isNotEmpty == true
                  ? user!.orgName
                  : 'Personal workspace',
            ),
            _AccountRow(
              icon: Broken.cpu,
              label: 'Model',
              value: provider.activeModel ?? 'Managed by OpenHands',
            ),
            _AccountRow(
              icon: Broken.global,
              label: 'Server',
              value: provider.baseUrl,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final email = user?.email;
                if (email == null || email.isEmpty) return;
                await Clipboard.setData(ClipboardData(text: email));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Email copied')),
                  );
                }
              },
              icon: const Icon(Broken.copy, size: 17),
              label: const Text('Copy email'),
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: () async {
                final uri = Uri.parse('${provider.baseUrl}/settings');
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              icon: const Icon(Broken.export, size: 17),
              label: const Text('Manage on OpenHands'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Sign out of OpenHands?'),
                    content: const Text(
                      'The API token is removed from this device. Your conversations stay on OpenHands.',
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
              icon: Icon(Broken.logout, size: 17, color: scheme.error),
              label: Text(
                'Sign out',
                style: TextStyle(color: scheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: AppFontWeights.medium,
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showNewConversationSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => const _NewConversationSheet(),
  );
}

class _NewConversationSheet extends StatefulWidget {
  const _NewConversationSheet();

  @override
  State<_NewConversationSheet> createState() => _NewConversationSheetState();
}

class _NewConversationSheetState extends State<_NewConversationSheet> {
  final TextEditingController _message = TextEditingController();
  final TextEditingController _repository = TextEditingController();
  bool _showRepository = false;
  bool _starting = false;

  @override
  void dispose() {
    _message.dispose();
    _repository.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final text = _message.text.trim();
    if (text.isEmpty || _starting) return;
    setState(() => _starting = true);
    final provider = context.read<OpenHandsProvider>();
    final conversation = await provider.createConversation(
      text,
      repository: _showRepository ? _repository.text : null,
    );
    if (!mounted) return;
    setState(() => _starting = false);
    if (conversation != null) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OpenHandsProvider>();
    final scheme = Theme.of(context).colorScheme;
    final busy = _starting || provider.creating;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Broken.add_circle, size: 20, color: scheme.primary),
                const SizedBox(width: 10),
                Text(
                  'New conversation',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: AppFontWeights.semibold,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'OpenHands starts a sandbox and the agent picks up your message.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _message,
              autofocus: true,
              minLines: 3,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'What should the agent do?',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (_showRepository)
              TextField(
                controller: _repository,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'Repository (owner/repo)',
                  hintText: 'ferelking242/handoff',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              )
            else
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _showRepository = true),
                  icon: const Icon(Broken.folder_add, size: 16),
                  label: const Text('Attach a repository'),
                ),
              ),
            if (provider.error != null) ...[
              const SizedBox(height: 8),
              Text(
                provider.error!,
                style: TextStyle(fontSize: 12, color: scheme.error),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: busy ? null : _start,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: busy
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.onPrimary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text('Starting sandbox…'),
                      ],
                    )
                  : const Text('Start conversation'),
            ),
          ],
        ),
      ),
    );
  }
}
