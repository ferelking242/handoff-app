import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../icons/broken_icons.dart';
import '../../../theme/app_font_weights.dart';
import '../models/openhands_models.dart';
import '../providers/openhands_provider.dart';
import '../widgets/handoff_drawer.dart';
import '../widgets/handoff_logo.dart';
import '../widgets/handoff_sheets.dart';
import 'conversation_view.dart';
import 'guard_page.dart';
import 'login_page.dart';
import 'settings_page.dart';

/// Chooses between the sign-in surface and the OpenHands client.
class HandoffRoot extends StatefulWidget {
  const HandoffRoot({super.key});

  @override
  State<HandoffRoot> createState() => _HandoffRootState();
}

class _HandoffRootState extends State<HandoffRoot> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<OpenHandsProvider>();
      provider.initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OpenHandsProvider>();
    switch (provider.authStatus) {
      case OpenHandsAuthStatus.loading:
        return const _Splash();
      case OpenHandsAuthStatus.signedIn:
        return const OpenHandsHomePage();
      case OpenHandsAuthStatus.signedOut:
      case OpenHandsAuthStatus.signingIn:
      case OpenHandsAuthStatus.error:
        return const OpenHandsLoginPage();
    }
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const HandoffLogo(size: 78, radius: 24),
            const SizedBox(height: 20),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: scheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OpenHandsHomePage extends StatefulWidget {
  const OpenHandsHomePage({super.key});

  @override
  State<OpenHandsHomePage> createState() => _OpenHandsHomePageState();
}

class _OpenHandsHomePageState extends State<OpenHandsHomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<OpenHandsProvider>();
      if (provider.conversations.isEmpty) {
        provider.refreshConversations();
      }
    });
  }

  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();
  void _closeDrawer() => _scaffoldKey.currentState?.closeDrawer();

  void _selectConversation(OpenHandsConversation conversation) {
    _closeDrawer();
    context.read<OpenHandsProvider>().openConversation(conversation);
  }

  void _newConversation() {
    _closeDrawer();
    showNewConversationSheet(context);
  }

  void _openSettings() {
    _closeDrawer();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OpenHandsSettingsPage()),
    );
  }

  void _openGuard() {
    _closeDrawer();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OpenHandsGuardPage()),
    );
  }

  void _openAccount() {
    _closeDrawer();
    showHandoffAccountSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OpenHandsProvider>();
    final scheme = Theme.of(context).colorScheme;
    final active = provider.active;

    final status = provider.agentRunning
        ? 'Agent is working'
        : active != null
            ? 'Idle'
            : 'OpenHands Cloud';

    return Scaffold(
      key: _scaffoldKey,
      drawer: HandoffDrawer(
        provider: provider,
        onSelectConversation: _selectConversation,
        onNewConversation: _newConversation,
        onOpenSettings: _openSettings,
        onOpenGuard: _openGuard,
        onOpenAccount: _openAccount,
      ),
      appBar: AppBar(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          tooltip: 'Conversations',
          onPressed: _openDrawer,
          icon: const Icon(Broken.menu, size: 22),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              active?.displayTitle ?? 'Handoff',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: AppFontWeights.semibold,
                color: scheme.onSurface,
              ),
            ),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: provider.agentRunning
                        ? scheme.primary
                        : scheme.onSurfaceVariant.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'New conversation',
            onPressed: provider.creating ? null : _newConversation,
            icon: const Icon(Broken.add, size: 22),
          ),
          if (active != null)
            PopupMenuButton<String>(
              icon: const Icon(Broken.more, size: 21),
              onSelected: (value) async {
                switch (value) {
                  case 'refresh':
                    await provider.refreshTimeline();
                  case 'web':
                    final url = active.uiUrl;
                    if (url != null && url.isNotEmpty) {
                      await launchUrl(
                        Uri.parse(url),
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  case 'close':
                    provider.closeConversation();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'refresh',
                  child: Text('Refresh'),
                ),
                if (active.uiUrl != null)
                  const PopupMenuItem(
                    value: 'web',
                    child: Text('Open in OpenHands'),
                  ),
                const PopupMenuItem(
                  value: 'close',
                  child: Text('Close conversation'),
                ),
              ],
            )
          else
            const SizedBox(width: 6),
        ],
      ),
      body: active == null
          ? _WelcomeView(
              provider: provider,
              onNewConversation: _newConversation,
              onBrowse: _openDrawer,
              onOpenConversation: _selectConversation,
            )
          : OpenHandsConversationView(key: ValueKey(active.id)),
    );
  }
}

class _WelcomeView extends StatelessWidget {
  const _WelcomeView({
    required this.provider,
    required this.onNewConversation,
    required this.onBrowse,
    required this.onOpenConversation,
  });

  final OpenHandsProvider provider;
  final VoidCallback onNewConversation;
  final VoidCallback onBrowse;
  final ValueChanged<OpenHandsConversation> onOpenConversation;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final recent = provider.conversations.take(4).toList(growable: false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
      children: [
        const Center(child: HandoffLogo(size: 76, radius: 24))
            .animate()
            .fadeIn(duration: 360.ms)
            .scale(begin: const Offset(0.92, 0.92)),
        const SizedBox(height: 20),
        Text(
          'Ready when you are',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: AppFontWeights.heavy,
            letterSpacing: -0.6,
            color: scheme.onSurface,
          ),
        ).animate().fadeIn(delay: 80.ms),
        const SizedBox(height: 8),
        Text(
          'Pick up a conversation or start a new one. The agent runs on your OpenHands sandbox.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            height: 1.45,
            color: scheme.onSurfaceVariant,
          ),
        ).animate().fadeIn(delay: 140.ms),
        const SizedBox(height: 26),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: provider.creating ? null : onNewConversation,
                icon: const Icon(Broken.add, size: 18),
                label: const Text('New conversation'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onBrowse,
                icon: const Icon(Broken.message, size: 18),
                label: const Text('Conversations'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ).animate().fadeIn(delay: 200.ms),
        if (recent.isNotEmpty) ...[
          const SizedBox(height: 32),
          Row(
            children: [
              Text(
                'RECENT',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.2,
                  fontWeight: AppFontWeights.semibold,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              if (provider.conversationsLoading)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ...recent.map(
            (conversation) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => onOpenConversation(conversation),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(
                            Broken.message_text,
                            size: 17,
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                conversation.displayTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: AppFontWeights.medium,
                                  color: scheme.onSurface,
                                ),
                              ),
                              if (conversation.subtitle.isNotEmpty)
                                Text(
                                  conversation.subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (conversation.isRunning)
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: scheme.primary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
