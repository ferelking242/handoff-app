import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/app_config.dart';
import 'providers/app_providers.dart';
import 'screens/conversations_screen.dart';
import 'screens/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: AivosApp()));
}

class AivosApp extends ConsumerStatefulWidget {
  const AivosApp({super.key});

  @override
  ConsumerState<AivosApp> createState() => _AivosAppState();
}

class _AivosAppState extends ConsumerState<AivosApp>
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
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6C4CF1)),
      useMaterial3: true,
    );

    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C4CF1),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: _restoring
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : token == null
          ? const LoginScreen()
          : const ConversationsScreen(),
    );
  }
}
