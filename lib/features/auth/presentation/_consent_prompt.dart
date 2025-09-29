import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/consent_service.dart';
import '../../home/presentation/home_screen.dart';

class ConsentPrompt extends ConsumerWidget {
  const ConsentPrompt({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data Collection Consent')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'We collect trip details (origin/destination, mode, timing, companions) to help urban transport planning by NATPAC. Your data is stored securely and used only for research and planning purposes. You can revoke consent at any time in Settings.',
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () async {
                    await ref.read(consentServiceProvider).setConsented(true);
                    if (context.mounted) {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                      );
                    }
                  },
                  child: const Text('I Agree'),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () async {
                    await ref.read(consentServiceProvider).setConsented(false);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  child: const Text('Not Now'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
