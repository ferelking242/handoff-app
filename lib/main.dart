import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'providers/app_providers.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'widgets/app_logo.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: HandoffApp()));
}

class HandoffApp extends ConsumerStatefulWidget {
  const HandoffApp({super.key});

  @override
  ConsumerState<HandoffApp> createState() => _HandoffAppState();
}

class _HandoffAppState extends ConsumerState<HandoffApp>
    with WidgetsBindingObserver {
  bool _restoring = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restore();
  }

  Future<void> _restore() async {
    await ref.read(notificationInitProvider.future);
    await ref.read(themeModeProvider.notifier).restore();
    await ref.read(hiddenConversationsProvider.notifier).restore();
    await ref.read(authProvider.notifier).restore();
    if (mounted) setState(() => _restoring = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The session service needs to know whether the user is looking at the
    // app: it only suppresses notifications while the app is in front.
    final foreground = state == AppLifecycleState.resumed;
    ref.read(sessionServiceProvider).setForeground(foreground);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(authProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: _restoring
          ? const _Splash()
          : token == null
          ? const LoginScreen()
          : const HomeScreen(),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogoMark(size: 64),
            const SizedBox(height: 22),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
          ],
        ),
      ),
    );
  }
}
