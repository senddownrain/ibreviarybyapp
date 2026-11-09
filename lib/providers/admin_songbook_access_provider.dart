import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Same emergency administrator UIDs as MyBrev Web. Ordinary priest device
// grants do not give songbook access.
const legacyAdminUids = <String>{
  '64MeSP56IWVotVFG7bu8YKeLis12',
  '7mszX2IiXHgjWxj0ZE5vEqdkmoD2',
};

bool isAdminRecord(String uid, Map<String, dynamic>? data) {
  if (legacyAdminUids.contains(uid)) return true;
  if (data == null) return false;
  final role = data.containsKey('role') ? data['role'] : 'admin';
  return role == 'admin' || role == 'superadmin';
}

/// Never grant from a cached Firestore role. Revocation and sign-out hide
/// songbook navigation immediately, including an already open deep link.
final adminSongbookAccessProvider = StreamProvider<bool>((ref) {
  final controller = StreamController<bool>();
  StreamSubscription<User?>? authSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? roleSubscription;
  var generation = 0;

  void emit(bool allowed) {
    if (!controller.isClosed) controller.add(allowed);
  }

  authSubscription = FirebaseAuth.instance.authStateChanges().listen(
    (user) async {
      final current = ++generation;
      await roleSubscription?.cancel();
      roleSubscription = null;
      if (current != generation) return;
      emit(false);
      if (user == null || user.isAnonymous) return;
      if (legacyAdminUids.contains(user.uid)) {
        emit(true);
        return;
      }
      roleSubscription = FirebaseFirestore.instance
          .collection('admins')
          .doc(user.uid)
          .snapshots(includeMetadataChanges: true)
          .listen(
            (snapshot) {
              if (current != generation) return;
              if (snapshot.metadata.isFromCache) {
                emit(false);
                return;
              }
              emit(isAdminRecord(user.uid, snapshot.data()));
            },
            onError: (Object _) {
              if (current == generation) emit(false);
            },
          );
    },
    onError: (Object _) => emit(false),
  );

  ref.onDispose(() {
    ++generation;
    unawaited(authSubscription?.cancel());
    unawaited(roleSubscription?.cancel());
    unawaited(controller.close());
  });
  return controller.stream;
});
