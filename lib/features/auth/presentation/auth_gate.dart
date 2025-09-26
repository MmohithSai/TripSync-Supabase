import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/providers.dart';
import '../../home/presentation/home_screen.dart';
import 'login_screen.dart';
import '../../location/presentation/permission_gate.dart';

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
              'Web build is not fully configured.\n\nRun on Android/iOS, or add Firebase Web config and Google Maps JS API key to enable web.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    final authAsync = ref.watch(authStateChangesProvider);
    return authAsync.when(
      data: (user) => user == null
          ? const LoginScreen()
          : const PermissionGate(child: HomeScreen()),
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Auth error: $e')),
      ),
    );
  }
}



