import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/providers.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(firebaseAuthProvider).currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not signed in')));
    }
    final fs = ref.watch(firestoreProvider);
    final query = fs
        .collection('users')
        .doc(user.uid)
        .collection('locations')
        .orderBy('timestamp', descending: true)
        .limit(100);

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No locations yet'));
          }
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final d = docs[i].data();
              final ts = d['timestamp'] as Timestamp?;
              final dt = ts?.toDate();
              return ListTile(
                leading: const Icon(Icons.place_outlined),
                title: Text('${d['latitude']}, ${d['longitude']}'),
                subtitle: Text(dt?.toLocal().toString() ?? 'pending...'),
              );
            },
          );
        },
      ),
    );
  }
}



