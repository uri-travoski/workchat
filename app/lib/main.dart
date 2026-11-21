import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'state/auth_state.dart';
import 'state/chat_state.dart';
import 'state/hidden_chat_manager.dart';
import 'state/local_avatar_manager.dart';
import 'theme/theme_manager.dart';
import 'ui/screens/login_screen.dart';
import 'ui/screens/main_layout.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WorkChatApp());
}

class WorkChatApp extends StatelessWidget {
  const WorkChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeManager()),
        ChangeNotifierProvider(create: (_) => AuthState()),
        ChangeNotifierProvider(create: (_) => HiddenChatManager()),
        ChangeNotifierProvider(create: (_) => LocalAvatarManager()),
        ChangeNotifierProxyProvider<AuthState, ChatState?>(
          create: (_) => null,
          update: (_, auth, previous) {
            if (!auth.isAuthenticated) return null;
            if (previous != null &&
                previous.token == auth.token &&
                previous.serverUrl == auth.serverUrl) {
              return previous;
            }
            return ChatState(
              api: auth.apiService,
              serverUrl: auth.serverUrl,
              token: auth.token!,
              currentUserId: auth.currentUser!.id,
            );
          },
        ),
      ],
      child: Consumer<ThemeManager>(
        builder: (context, themeMgr, _) {
          return MaterialApp(
            title: 'WorkChat',
            debugShowCheckedModeBanner: false,
            theme: themeMgr.lightTheme,
            darkTheme: themeMgr.darkTheme,
            themeMode: themeMgr.themeMode,
            builder: (ctx, child) {
              final theme = Theme.of(ctx);
              return DefaultTextStyle(
                style: TextStyle(
                  fontFamily: themeMgr.fontFamily,
                  fontSize: (14.0 + themeMgr.fontSizeDelta).clamp(9.0, 36.0),
                  fontWeight: themeMgr.effectiveBodyWeight,
                  color: theme.colorScheme.onSurface,
                ),
                child: child!,
              );
            },
            home: const RootGate(),
          );
        },
      ),
    );
  }
}

class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthState>();

    if (authState.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
        ),
      );
    }

    if (authState.isAuthenticated) {
      return const MainLayout();
    }

    return const LoginScreen();
  }
}
