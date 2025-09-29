import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/providers.dart';
import '../../home/presentation/home_screen.dart';
import 'login_screen.dart';
import '../../location/presentation/permission_gate.dart';
import '../../../common/consent_service.dart';
import '_consent_prompt.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (kIsWeb) {
      return const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Web build is not fully configured.\n\nRun on Android/iOS, or add Supabase Web config and Google Maps JS API key to enable web.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final authState = ref.watch(authStateChangesProvider);

    return authState.when(
      data: (authState) {
        if (authState.session != null) {
          return FutureBuilder<bool>(
            future: ref.read(consentServiceProvider).hasConsented(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              final ok = snap.data ?? false;
              if (!ok) {
                return const PermissionGate(child: ConsentPrompt());
              }
              return const PermissionGate(child: HomeScreen());
            },
          );
        } else {
          return const LoginScreen();
        }
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) =>
          Scaffold(body: Center(child: Text('Auth Error: $error'))),
    );
  }
}
