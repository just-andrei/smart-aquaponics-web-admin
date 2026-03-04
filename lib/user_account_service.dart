import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

class CreatedUserResult {
  final String uid;
  final String temporaryPassword;

  const CreatedUserResult({required this.uid, required this.temporaryPassword});
}

class UserProfileRecord {
  final String collection;
  final String uid;
  final Map<String, dynamic> data;

  const UserProfileRecord({
    required this.collection,
    required this.uid,
    required this.data,
  });
}

class UserAccountService {
  UserAccountService._();

  static const List<String> roleCollectionsInPriority = [
    'admin',
    'employee',
    'user',
  ];

  static String normalizeRole(String role) {
    final normalized = role.trim().toLowerCase();
    if (normalized == 'manager') return 'admin';
    if (normalized == 'system support') return 'employee';
    if (normalized == 'user') return 'grower';
    return normalized;
  }

  static bool isAdminRole(String role) => normalizeRole(role) == 'admin';

  static bool isEmployeeRole(String role) => normalizeRole(role) == 'employee';

  static bool isGrowerRole(String role) => normalizeRole(role) == 'grower';

  static String collectionForRole(String role) {
    final normalizedRole = normalizeRole(role);
    if (normalizedRole == 'admin') return 'admin';
    if (normalizedRole == 'employee') return 'employee';
    return 'user';
  }

  static String generateSecurePassword({int length = 18}) {
    const lower = 'abcdefghijklmnopqrstuvwxyz';
    const upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const numbers = '0123456789';
    const symbols = r'!@#$%^&*()-_=+[]{};:,.?';
    const all = '$lower$upper$numbers$symbols';
    final random = Random.secure();

    final chars = <String>[
      lower[random.nextInt(lower.length)],
      upper[random.nextInt(upper.length)],
      numbers[random.nextInt(numbers.length)],
      symbols[random.nextInt(symbols.length)],
    ];

    while (chars.length < length) {
      chars.add(all[random.nextInt(all.length)]);
    }
    chars.shuffle(random);
    return chars.join();
  }

  static Future<CreatedUserResult> createManagedUser({
    required String firstName,
    required String lastName,
    required String email,
    required String role,
    String phoneNumber = '',
    String address = '',
    String status = 'active',
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedRole = normalizeRole(role);
    final normalizedStatus = status.trim().toLowerCase();
    final temporaryPassword = generateSecurePassword();
    final appName = 'secondary-${DateTime.now().microsecondsSinceEpoch}';

    final secondaryApp = await Firebase.initializeApp(
      name: appName,
      options: DefaultFirebaseOptions.currentPlatform,
    );

    try {
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: temporaryPassword,
      );
      final uid = credential.user!.uid;
      final collection = collectionForRole(normalizedRole);

      await FirebaseFirestore.instance.collection(collection).doc(uid).set({
        'user_id': uid,
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'email': normalizedEmail,
        'phone_num': phoneNumber.trim(),
        'address': address.trim(),
        'role': normalizedRole,
        'status': normalizedStatus,
        'updated_at': FieldValue.serverTimestamp(),
        'created_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: normalizedEmail,
      );
      await secondaryAuth.signOut();

      return CreatedUserResult(uid: uid, temporaryPassword: temporaryPassword);
    } finally {
      await secondaryApp.delete();
    }
  }

  static Future<UserProfileRecord?> getProfileByUid(String uid) async {
    for (final collection in roleCollectionsInPriority) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection(collection)
            .doc(uid)
            .get();
        if (doc.exists && doc.data() != null) {
          return UserProfileRecord(
            collection: collection,
            uid: uid,
            data: doc.data()!,
          );
        }
      } on FirebaseException catch (e) {
        // Some rulesets deny cross-collection reads. Skip denied collections.
        if (e.code != 'permission-denied') rethrow;
      }
    }
    return null;
  }

  static Future<UserProfileRecord?> getProfileByUidOrEmail({
    required String uid,
    required String email,
  }) async {
    final byUid = await getProfileByUid(uid);
    if (byUid != null) return byUid;

    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) return null;

    for (final collection in roleCollectionsInPriority) {
      try {
        final byEmail = await FirebaseFirestore.instance
            .collection(collection)
            .where('email', isEqualTo: normalizedEmail)
            .limit(1)
            .get();
        if (byEmail.docs.isNotEmpty) {
          final doc = byEmail.docs.first;
          return UserProfileRecord(
            collection: collection,
            uid: doc.id,
            data: doc.data(),
          );
        }
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied') rethrow;
      }
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getUserProfileByUidOrEmail({
    required String uid,
    required String email,
  }) async {
    final profile = await getProfileByUidOrEmail(uid: uid, email: email);
    return profile?.data;
  }

  static Future<String?> resolveEmailForIdentifier(String identifier) async {
    final normalized = identifier.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    for (final collection in roleCollectionsInPriority) {
      try {
        // 1) Direct UID/doc-id lookup.
        final byUid = await FirebaseFirestore.instance
            .collection(collection)
            .doc(normalized)
            .get();
        if (byUid.exists && byUid.data() != null) {
          final email = (byUid.data()!['email'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
          if (email.isNotEmpty) return email;
        }

        // 2) Username lookup.
        final byUsername = await FirebaseFirestore.instance
            .collection(collection)
            .where('username', isEqualTo: normalized)
            .limit(1)
            .get();
        if (byUsername.docs.isNotEmpty) {
          final email = (byUsername.docs.first.data()['email'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
          if (email.isNotEmpty) return email;
        }

        // 3) Numeric/logical user_id lookup.
        final byUserId = await FirebaseFirestore.instance
            .collection(collection)
            .where('user_id', isEqualTo: normalized)
            .limit(1)
            .get();
        if (byUserId.docs.isNotEmpty) {
          final email = (byUserId.docs.first.data()['email'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
          if (email.isNotEmpty) return email;
        }

        // 4) Email lookup fallback (if input is already an email).
        final byEmail = await FirebaseFirestore.instance
            .collection(collection)
            .where('email', isEqualTo: normalized)
            .limit(1)
            .get();
        if (byEmail.docs.isNotEmpty) {
          final email = (byEmail.docs.first.data()['email'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
          if (email.isNotEmpty) return email;
        }
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied') rethrow;
      }
    }
    return null;
  }

  static Future<String?> resolveEmailForUsername(String username) {
    // Backward-compatible alias.
    return resolveEmailForIdentifier(username);
  }
}
